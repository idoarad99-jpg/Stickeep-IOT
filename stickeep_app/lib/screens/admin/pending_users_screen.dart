import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/widgets/loading_skeleton.dart';

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({super.key});

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  final _firestore = FirebaseFirestore.instance;

  // ── Approve ───────────────────────────────────────────────────────────────

  Future<void> _approveUser(String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('students').doc(docId).set({
        'studentNumber': data['studentNumber'],
        'name': data['name'],
        'email': data['email'],
        'nfcSerialNumber': data['nfcSerialNumber'] ?? '',
        'isAuthorized': true,
        'role': 'student',
        'approvedAt': DateTime.now(),
      });

      await _firestore
          .collection('registrationRequests')
          .doc(docId)
          .update({'status': 'approved'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ User approved!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<void> _rejectUser(String docId) async {
    try {
      await _firestore
          .collection('registrationRequests')
          .doc(docId)
          .update({'status': 'rejected'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Pending users'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('registrationRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminListSkeleton();
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── "X users waiting" subtitle ────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '${docs.length} user${docs.length == 1 ? '' : 's'} waiting for approval',
                  style: AppTextStyles.cardSubtitle,
                ),
              ),

              // ── List / empty state ────────────────────────────────────────
              Expanded(
                child: docs.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'No pending requests',
                        subtitle: 'You\'re all caught up! 🎉',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _PendingCard(
                            docId: doc.id,
                            data: data,
                            onApprove: _approveUser,
                            onReject: _rejectUser,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, Map<String, dynamic>) onApprove;
  final Future<void> Function(String) onReject;

  const _PendingCard({
    required this.docId,
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final studentNumber = data['studentNumber'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ── Top row: avatar · name/number · Pending tag ───────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purpleLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(studentNumber, style: AppTextStyles.cardSubtitle),
                    ],
                  ),
                ),

                StatusTag(
                  label: 'Pending',
                  backgroundColor: AppColors.amberLight,
                  textColor: AppColors.amber,
                  icon: Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Bottom row: Approve + Reject buttons ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onApprove(docId, data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '✓ Approve',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onReject(docId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.redLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '✕ Reject',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
