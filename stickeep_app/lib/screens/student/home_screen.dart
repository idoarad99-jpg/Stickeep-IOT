import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stickeep_app/screens/student/report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/admin_home_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/settings/accessibility_settings_screen.dart';
import 'package:stickeep_app/screens/student/classroom_screen.dart';
import 'package:stickeep_app/screens/student/reservations_screen.dart';
import 'package:stickeep_app/screens/student/scanner_screen.dart';
import 'package:stickeep_app/utils/page_route.dart';

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

  Future<void> _scanSticker(BuildContext context, String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('reservations/' + uid).get();
    if (!snapshot.exists || snapshot.value == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active reservation found')));
      return;
    }
    final raw = snapshot.value as Map<dynamic, dynamic>;
    final upcoming = raw.entries.where((e) => (e.value as Map<dynamic, dynamic>)['is_upcoming'] == true).toList();
    if (upcoming.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active reservation found')));
      return;
    }
    final first = upcoming.first;
    final data = first.value as Map<dynamic, dynamic>;
    if (context.mounted) {
      Navigator.push(context, AppPageRoute(builder: (_) => ScannerScreen(classroom: data['classroom'] as String? ?? '', studentName: _userName, reservationId: (data['qr_token'] as String? ?? '').trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isAdmin = _userRole.toLowerCase() == 'admin';
    final displayName = _userName.isEmpty ? 'User' : _userName;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient greeting header ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.blue, AppColors.blue.withOpacity(0.75)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $displayName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back to Stickeep',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Accessibility settings',
                    icon: const Icon(Icons.accessibility_new, color: Colors.white),
                    onPressed: () => Navigator.push(context,
                        AppPageRoute(builder: (_) => const AccessibilitySettingsScreen())),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
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
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: _NextReservationCard(uid: uid, userName: _userName),
                ),
                const SizedBox(height: 8),
                Text('What would you like to do?',
                    style: AppTextStyles.sectionTitle),
                const SizedBox(height: 12),

                // ── Quick action grid ─────────────────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _QuickActionTile(
                      icon: Icons.event_seat_outlined,
                      label: 'New reservation',
                      color: AppColors.blue,
                      onTap: () => Navigator.push(context,
                          AppPageRoute(builder: (_) => const ClassroomScreen())),
                    ),
                    _QuickActionTile(
                      icon: Icons.qr_code_scanner_outlined,
                      label: 'Scan on arrival',
                      color: AppColors.green,
                      onTap: () => _scanSticker(context, uid),
                    ),
                    _QuickActionTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'My reservations',
                      color: AppColors.amber,
                      onTap: () => Navigator.push(
                          context,
                          AppPageRoute(
                              builder: (_) =>
                                  const ReservationsScreen(showUpcoming: true))),
                    ),
                    _QuickActionTile(
                      icon: Icons.history_outlined,
                      label: 'History',
                      color: AppColors.purple,
                      onTap: () => Navigator.push(
                          context,
                          AppPageRoute(
                              builder: (_) =>
                                  const ReservationsScreen(showUpcoming: false))),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (isAdmin) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        AppPageRoute(builder: (_) => const AdminHomeScreen()),
                      ),
                      icon: Icon(Icons.admin_panel_settings_outlined, color: AppColors.purple),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.purple,
                        side: BorderSide(color: AppColors.purple),
                        minimumSize: const Size(double.infinity, 46),
                      ),
                      label: const Text('Admin Panel'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        AppPageRoute(builder: (_) => const ReportScreen())),
                    icon: Icon(Icons.warning_amber_rounded, color: AppColors.red),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red),
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    label: const Text('Report an issue'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextReservationCard extends StatelessWidget {
  final String uid;
  final String userName;
  const _NextReservationCard({required this.uid, required this.userName});

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
                final qrStatus = data['qr_status'] as String? ?? '';
                final nfcStatus = data['nfc_status'] as String? ?? '';
                final alreadyConfirmed = qrStatus == 'arrived' || nfcStatus == 'approved';
                return isUpcoming && !date.isBefore(todayDate) && !alreadyConfirmed;
              })
              .map((e) => Map<String, dynamic>.from(e.value as Map))
              .toList()
            ..sort((a, b) {
                // Sort ascending by date+time: nearest first
                final aDate = a['date'] as String? ?? '';
                final aTime = a['time_start'] as String? ?? '';
                final bDate = b['date'] as String? ?? '';
                final bTime = b['time_start'] as String? ?? '';
                final aKey = aDate.split('.').reversed.join() + aTime.replaceAll(':', '');
                final bKey = bDate.split('.').reversed.join() + bTime.replaceAll(':', '');
                return aKey.compareTo(bKey);
              });

          if (upcoming.isNotEmpty) next = upcoming.first;
        }

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next reservation', style: AppTextStyles.sectionTitle),
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
                          child: Icon(Icons.calendar_today_outlined,
                              size: 20, color: AppColors.blue),
                        ),
                        const SizedBox(width: 12),
                        Text('No upcoming reservations',
                            style: AppTextStyles.cardSubtitle),
                      ],
                    )
                  : Builder(builder: (ctx) {
                      final qrToken =
                          (next!['qr_token'] as String? ?? '').trim();
                      final classroom =
                          next['classroom'] as String? ?? '';
                      return _ReservationSummary(
                        data: next,
                        onScanArrival: qrToken.isNotEmpty
                            ? () {
                                Navigator.push(
                                  ctx,
                                  AppPageRoute(
                                    builder: (_) => ScannerScreen(
                                      classroom: classroom,
                                      studentName: userName,
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
    final studentNum = data['student_number'] as String? ?? '';

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
              child: Icon(Icons.calendar_today_outlined,
                  size: 20, color: AppColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    '$classroom  •  Seat $seat  •  $time',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (studentNum.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Student ID: $studentNum',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
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
                style: TextStyle(
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
          Divider(height: 1, color: AppColors.border),
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
