import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete User',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete $name? This action cannot be undone.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFA32D2D)),
            ),
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
        const SnackBar(
          content: Text('User deleted'),
          backgroundColor: Color(0xFFA32D2D),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Make Admin',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Give admin access to $name?',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Color(0xFF3C3489)),
            ),
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
        SnackBar(
          content: Text('✓ $name is now an admin'),
          backgroundColor: const Color(0xFF3C3489),
        ),
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C3489),
        title: const Text(
          'All users',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 9),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search users...',
                  hintStyle:
                      TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('🔍', style: TextStyle(fontSize: 12)),
                  ),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 0, vertical: 9),
                  filled: false,
                ),
              ),
            ),
          ),

          // ── User list from students/ ──────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
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
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ───────────────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEEEDFE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFF3C3489),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Name + student number · reservations ──────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$studentNumber · 0 reservations',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF6B7280),
                  ),
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
              _Tag(
                label: isAuthorized ? 'Active' : 'Suspended',
                background: isAuthorized
                    ? const Color(0xFFEAF3DE)
                    : const Color(0xFFFCEBEB),
                textColor: isAuthorized
                    ? const Color(0xFF3B6D11)
                    : const Color(0xFFA32D2D),
              ),
              const SizedBox(height: 4),

              // Role: purple Admin tag OR outlined Make Admin button
              if (isAdmin)
                const _Tag(
                  label: 'Admin',
                  background: Color(0xFFEEEDFE),
                  textColor: Color(0xFF3C3489),
                )
              else
                _OutlinedActionButton(
                  label: 'Make Admin',
                  borderColor: const Color(0xFF3C3489),
                  textColor: const Color(0xFF3C3489),
                  onTap: () => onMakeAdmin(docId, name),
                ),
              const SizedBox(height: 4),

              // Delete User button (always shown)
              _FilledActionButton(
                label: 'Delete User',
                background: const Color(0xFFFCEBEB),
                textColor: const Color(0xFFA32D2D),
                onTap: () => onDelete(docId, name),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _Tag({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 7, color: textColor),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _OutlinedActionButton({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 8, color: textColor),
        ),
      ),
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final VoidCallback onTap;

  const _FilledActionButton({
    required this.label,
    required this.background,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 8, color: textColor),
        ),
      ),
    );
  }
}
