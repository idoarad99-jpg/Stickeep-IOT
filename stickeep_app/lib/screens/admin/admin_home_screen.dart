import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/all_users_screen.dart';
import 'package:stickeep_app/screens/admin/pending_users_screen.dart';
import 'package:stickeep_app/screens/admin/reports_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/admin/user_search_screen.dart';
import 'package:stickeep_app/screens/admin/manage_classrooms_screen.dart';
import 'package:stickeep_app/utils/page_route.dart';

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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Admin Panel'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Admin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Users',
                                value: totalUsers.toString(),
                                valueColor: AppColors.blue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                label: 'Pending',
                                value: pendingCount.toString(),
                                valueColor: AppColors.amber,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                label: 'Reports',
                                value: reportsCount.toString(),
                                valueColor: AppColors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Quick actions', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context,
                                AppPageRoute(
                                    builder: (_) =>
                                        const PendingUsersScreen())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                            ),
                            child: Text(
                                '👤  Review pending users ($pendingCount)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                AppPageRoute(
                                    builder: (_) => const AllUsersScreen())),
                            child: const Text('👥  Manage all users'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                AppPageRoute(
                                    builder: (_) =>
                                        const UserSearchScreen())),
                            child: const Text('🔍  Search users'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                AppPageRoute(
                                    builder: (_) => const ReportsScreen())),
                            child:
                                Text('⚠️  View reports ($reportsCount)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context,
                                AppPageRoute(
                                    builder: (_) =>
                                        const ManageClassroomsScreen())),
                            child: const Text('🏫  Manage classrooms'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Sticker monitor', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 10),
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
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.cardSubtitle),
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
          return AppCard(
            child: Center(
              child: Text('No sticker data yet', style: AppTextStyles.cardSubtitle),
            ),
          );
        }

        final raw =
            snap.data!.snapshot.value as Map<dynamic, dynamic>;
        final entries = raw.entries.toList()
          ..sort(
              (a, b) => a.key.toString().compareTo(b.key.toString()));

        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
                batteryColor = AppColors.textSecondary;
                batteryText = 'N/A';
              } else if (battery > 50) {
                batteryColor = AppColors.green;
                batteryText = '$battery%';
              } else if (battery >= 20) {
                batteryColor = AppColors.amber;
                batteryText = '$battery%';
              } else {
                batteryColor = AppColors.red;
                batteryText = '$battery%';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? AppColors.green : AppColors.border,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(seatId,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text('🔋 $batteryText',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: batteryColor)),
                    const SizedBox(width: 10),
                    Text('🕐 $lastSeenText', style: AppTextStyles.label),
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
