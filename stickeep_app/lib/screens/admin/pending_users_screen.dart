import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        const SnackBar(
          content: Text('✓ User approved!'),
          backgroundColor: Color(0xFF3B6D11),
        ),
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
        const SnackBar(
          content: Text('User rejected'),
          backgroundColor: Color(0xFFA32D2D),
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
          'Pending users',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('registrationRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── "X users waiting" subtitle ────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${docs.length} user${docs.length == 1 ? '' : 's'} waiting for approval',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),

              // ── List / empty state ────────────────────────────────────────
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending requests 🎉',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // ── Top row: avatar · name/number · Pending tag ───────────────────
          Row(
            children: [
              // Purple avatar circle
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

              // Name + student number
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
                    Text(
                      studentNumber,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              // Amber "Pending" tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 7,
                    color: Color(0xFF854F0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Bottom row: Approve + Reject buttons ──────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onApprove(docId, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3DE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        '✓ Approve',
                        style: TextStyle(
                          fontSize: 8,
                          color: Color(0xFF3B6D11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => onReject(docId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        '✕ Reject',
                        style: TextStyle(
                          fontSize: 8,
                          color: Color(0xFFA32D2D),
                          fontWeight: FontWeight.w500,
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
    );
  }
}
