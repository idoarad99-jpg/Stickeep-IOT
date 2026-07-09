import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Delete User ───────────────────────────────────────────────────────────

  Future<void> _onDeleteTap(String docId, String name) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == docId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own account')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete $name? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('students').doc(docId).delete();
      await _firestore
          .collection('registrationRequests')
          .doc(docId)
          .update({'status': 'rejected'}).catchError((_) {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Make Admin ────────────────────────────────────────────────────────────

  Future<void> _onMakeAdminTap(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make Admin'),
        content: Text('Give admin access to $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('students')
          .doc(docId)
          .update({'role': 'admin'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ $name is now an admin')),
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
        title: const Text('All users'),
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // ── User list from students/ ──────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name =
                        (data['name'] as String? ?? '').toLowerCase();
                    final num = (data['studentNumber'] as String? ?? '')
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        num.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No users found',
                    subtitle: 'Try a different search.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _UserCard(
                      docId: doc.id,
                      data: data,
                      onDelete: _onDeleteTap,
                      onMakeAdmin: _onMakeAdminTap,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onDelete;
  final Future<void> Function(String, String) onMakeAdmin;

  const _UserCard({
    required this.docId,
    required this.data,
    required this.onDelete,
    required this.onMakeAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final studentNumber = data['studentNumber'] as String? ?? '';
    final role = data['role'] as String? ?? 'student';
    final isAuthorized = data['isAuthorized'] as bool? ?? true;
    final isAdmin = role == 'admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ───────────────────────────────────────────────────────
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

            // ── Name + student number ──────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    studentNumber,
                    style: AppTextStyles.cardSubtitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Right column: tags + action buttons ───────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status tag — Active (green) or Suspended (red)
                StatusTag(
                  label: isAuthorized ? 'Active' : 'Suspended',
                  backgroundColor:
                      isAuthorized ? AppColors.greenLight : AppColors.redLight,
                  textColor: isAuthorized ? AppColors.green : AppColors.red,
                ),
                const SizedBox(height: 6),

                // Role: purple Admin tag OR outlined Make Admin button
                if (isAdmin)
                  StatusTag(
                    label: 'Admin',
                    backgroundColor: AppColors.purpleLight,
                    textColor: AppColors.purple,
                  )
                else
                  _ActionButton(
                    label: 'Make Admin',
                    color: AppColors.purple,
                    filled: false,
                    onTap: () => onMakeAdmin(docId, name),
                  ),
                const SizedBox(height: 6),

                // Delete User button (always shown)
                _ActionButton(
                  label: 'Delete',
                  color: AppColors.red,
                  filled: true,
                  onTap: () => onDelete(docId, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.12) : null,
          border: filled ? null : Border.all(color: color),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
