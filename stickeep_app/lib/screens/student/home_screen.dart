import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stickeep_app/screens/student/report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/admin_home_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/classroom_screen.dart';
import 'package:stickeep_app/screens/student/reservations_screen.dart';
import 'package:stickeep_app/screens/student/scanner_screen.dart';

DateTime _parseDate(String d) {
  final p = d.split('.');
  if (p.length != 3) return DateTime(2000);
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}

String _dateLabel(String dateStr) {
  final date = _parseDate(dateStr);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'Today';
  if (date == today.add(const Duration(days: 1))) return 'Tomorrow';
  return dateStr;
}

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _userName;
  late String _userRole;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userRole = widget.userRole;

    if (_userName.isEmpty || _userRole.isEmpty) {
      _fetchProfileFromFirestore();
    }
  }

  Future<void> _fetchProfileFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('students').doc(uid).get();

    if (!mounted || !doc.exists) return;

    final data = doc.data()!;
    setState(() {
      if (_userName.isEmpty) {
        _userName = data['name'] as String? ?? 'User';
      }
      if (_userRole.isEmpty) {
        _userRole = data['role'] as String? ?? 'student';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isAdmin = widget.userRole.toLowerCase() == 'admin';
    final displayName = _userName.isEmpty ? 'User' : _userName;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        automaticallyImplyLeading: false,
        title: Text(
          'Hi, $displayName 👋',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (r) => false);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NextReservationCard(uid: uid),
            const SizedBox(height: 24),
            const Text('What would you like to do?',
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ClassroomScreen())),
              child: const Text('🪑  New reservation'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ReservationsScreen(showUpcoming: true))),
              child: const Text('📅  My reservations'),
            ),
            const SizedBox(height: 10),
            // ── Reservation history ──────────────────────────────────────────
            OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ReservationsScreen(showUpcoming: false))),
              child: const Text('🕐  Reservation history'),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            if (isAdmin) ...[
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: const BorderSide(color: AppColors.purple),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('🔐  Admin Panel'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportScreen())),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('⚠️  Report an issue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextReservationCard extends StatelessWidget {
  final String uid;
  const _NextReservationCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('reservations/$uid');

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        Map<String, dynamic>? next;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);

          final upcoming = raw.entries
              .where((e) {
                final data = e.value as Map<dynamic, dynamic>;
                final isUpcoming = data['is_upcoming'] as bool? ?? false;
                final date = _parseDate(data['date'] as String? ?? '');
                return isUpcoming && !date.isBefore(todayDate);
              })
              .map((e) => Map<String, dynamic>.from(e.value as Map))
              .toList()
            ..sort((a, b) => _parseDate(a['date'] as String? ?? '')
                .compareTo(_parseDate(b['date'] as String? ?? '')));

          if (upcoming.isNotEmpty) next = upcoming.first;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Next reservation', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              next == null
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_today_outlined,
                              size: 20, color: AppColors.blue),
                        ),
                        const SizedBox(width: 12),
                        const Text('No upcoming reservations',
                            style: AppTextStyles.cardSubtitle),
                      ],
                    )
                  : Builder(builder: (ctx) {
                      final qrToken =
                          (next!['qr_token'] as String? ?? '').trim();
                      final classroom =
                          next['classroom'] as String? ?? '';
                      final studentName =
                          FirebaseAuth.instance.currentUser?.email ?? '';
                      return _ReservationSummary(
                        data: next,
                        onScanArrival: qrToken.isNotEmpty
                            ? () {
                                debugPrint(
                                    '[HomeScreen] Scan on arrival tapped, classroom: $classroom');
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => ScannerScreen(
                                      classroom: classroom,
                                      studentName: studentName,
                                      reservationId: qrToken,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    }),
            ],
          ),
        );
      },
    );
  }
}

class _ReservationSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onScanArrival;
  const _ReservationSummary({required this.data, this.onScanArrival});

  @override
  Widget build(BuildContext context) {
    final lesson = (data['lesson_name'] as String? ?? '').isEmpty
        ? 'Lesson'
        : data['lesson_name'] as String;
    final classroom = data['classroom'] as String? ?? '';
    final seat = data['seat_number']?.toString() ?? '—';
    final start = data['time_start'] as String? ?? '';
    final end = data['time_end'] as String? ?? '';
    final time = end.isEmpty ? start : '$start–$end';
    final dateStr = data['date'] as String? ?? '';
    final label = _dateLabel(dateStr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 20, color: AppColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    '$classroom  •  Seat $seat  •  $time',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
        if (onScanArrival != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onScanArrival,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('📷  Scan on arrival',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }
}
