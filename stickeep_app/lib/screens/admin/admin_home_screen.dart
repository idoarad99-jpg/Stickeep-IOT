import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/all_users_screen.dart';
import 'package:stickeep_app/screens/admin/pending_users_screen.dart';
import 'package:stickeep_app/screens/admin/reports_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/admin/user_search_screen.dart';
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
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // students/ is the source of truth for approved users
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
              const reportsCount = 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Metric cards ─────────────────────────────────────────────
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

                // ── Quick actions ─────────────────────────────────────────────
                const Text(
                  'Quick actions',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Purple filled — Review pending users
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PendingUsersScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C3489),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text('👤  Review pending users ($pendingCount)'),
                  ),
                ),
                const SizedBox(height: 8),

                // Outlined — Manage all users
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllUsersScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('👥  Manage all users'),
                  ),
                ),
                const SizedBox(height: 8),

                // Outlined — Search users
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserSearchScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('🔍  Search users'),
                  ),
                ),
                const SizedBox(height: 8),

                // Outlined — View reports
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReportsScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('⚠️  View reports ($reportsCount)'),
                  ),
                ),
              ],
            ),
          );
        },
          );
        },
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────

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
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 7,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
