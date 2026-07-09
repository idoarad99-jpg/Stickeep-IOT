import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/all_users_screen.dart';
import 'package:stickeep_app/screens/admin/pending_users_screen.dart';
import 'package:stickeep_app/screens/admin/reports_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/admin/user_search_screen.dart';
import 'package:stickeep_app/screens/admin/manage_classrooms_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  static const _isAdmin = true;

  @override
  void initState() {
    super.initState();
    if (!_isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C3489),
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Admin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('students').snapshots(),
        builder: (context, studentsSnap) {
          final totalUsers = studentsSnap.data?.docs.length ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('registrationRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, pendingSnap) {
              final pendingCount = pendingSnap.data?.docs.length ?? 0;

              return StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('reports').onValue,
                builder: (context, reportsSnap) {
                  int reportsCount = 0;
                  if (reportsSnap.hasData &&
                      reportsSnap.data!.snapshot.value != null) {
                    final raw = reportsSnap.data!.snapshot.value
                        as Map<dynamic, dynamic>;
                    reportsCount = raw.values.where((v) {
                      final map = v as Map<dynamic, dynamic>;
                      return (map['status'] as String?) == 'open';
                    }).length;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Users',
                                value: totalUsers.toString(),
                                valueColor: const Color(0xFF185FA5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'Pending',
                                value: pendingCount.toString(),
                                valueColor: const Color(0xFF854F0B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'Reports',
                                value: reportsCount.toString(),
                                valueColor: const Color(0xFFA32D2D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Quick actions',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PendingUsersScreen())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3C3489),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: Text(
                                '👤  Review pending users ($pendingCount)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const AllUsersScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: const Text('👥  Manage all users'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const UserSearchScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: const Text('🔍  Search users'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const ReportsScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child:
                                Text('⚠️  View reports ($reportsCount)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ManageClassroomsScreen())),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                  color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            child: const Text('🏫  Manage classrooms'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Sticker monitor',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        const _StickerMonitor(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  height: 1.1)),
          Text(label,
              style: const TextStyle(
                  fontSize: 7, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _StickerMonitor extends StatelessWidget {
  const _StickerMonitor();

  String _formatLastSeen(int ms) {
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('seats').onValue,
      builder: (context, snap) {
        if (!snap.hasData ||
            !snap.data!.snapshot.exists ||
            snap.data!.snapshot.value == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No sticker data yet',
                  style:
                      TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            ),
          );
        }

        final raw =
            snap.data!.snapshot.value as Map<dynamic, dynamic>;
        final entries = raw.entries.toList()
          ..sort(
              (a, b) => a.key.toString().compareTo(b.key.toString()));

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: entries.map((entry) {
              final seatId = entry.key.toString();
              final data = entry.value is Map
                  ? entry.value as Map<dynamic, dynamic>
                  : {};

              final battery =
                  (data['batteryPercentage'] as num?)?.toInt();
              final lastSeenMs = (data['lastSeen'] as num?)?.toInt();

              final bool isOnline = lastSeenMs != null &&
                  DateTime.now()
                      .difference(DateTime.fromMillisecondsSinceEpoch(lastSeenMs))
                      .inMinutes < 5;

              final lastSeenText = lastSeenMs != null
                  ? _formatLastSeen(lastSeenMs)
                  : 'Never';

              Color batteryColor;
              String batteryText;
              if (battery == null) {
                batteryColor = const Color(0xFF6B7280);
                batteryText = 'N/A';
              } else if (battery > 50) {
                batteryColor = const Color(0xFF3B6D11);
                batteryText = '$battery%';
              } else if (battery >= 20) {
                batteryColor = const Color(0xFFF59E0B);
                batteryText = '$battery%';
              } else {
                batteryColor = const Color(0xFFA32D2D);
                batteryText = '$battery%';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? const Color(0xFF3B6D11)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(seatId,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A))),
                    ),
                    Text('🔋 $batteryText',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: batteryColor)),
                    const SizedBox(width: 8),
                    Text('🕐 $lastSeenText',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF6B7280))),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
