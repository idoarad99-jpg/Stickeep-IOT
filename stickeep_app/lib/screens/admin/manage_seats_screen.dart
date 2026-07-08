import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/classroom.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/models/seat.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/cancel_reservation.dart';

class ManageSeatsScreen extends StatefulWidget {
  final Classroom classroom;

  const ManageSeatsScreen({super.key, required this.classroom});

  @override
  State<ManageSeatsScreen> createState() => _ManageSeatsScreenState();
}

class _ManageSeatsScreenState extends State<ManageSeatsScreen> {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _seatsRef => _firestore
      .collection('classrooms')
      .doc(widget.classroom.id)
      .collection('seats');

  DateTime? _parseDate(String d) {
    final parts = d.split('.');
    if (parts.length != 3) return null;
    return DateTime(
      int.tryParse(parts[2]) ?? 2000,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[0]) ?? 1,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _futureReservations(
      String seatId) async {
    final query = await _firestore
        .collection('reservations')
        .where('seatId', isEqualTo: seatId)
        .where('status', isEqualTo: 'reserved')
        .get();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return query.docs.where((d) {
      final date = _parseDate(d.data()['date'] as String? ?? '');
      return date != null && !date.isBefore(todayDate);
    }).toList();
  }

  // ── Add ──────────────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int nextOrder) async {
    final codeController = TextEditingController();
    final labelController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add seat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Sticker code',
                  hintText: 'Exactly as printed on the physical sticker',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'e.g. Window seat',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final label = labelController.text.trim();

                if (code.isEmpty) {
                  setDialogState(() => error = 'Sticker code is required');
                  return;
                }
                if (code.contains('/')) {
                  setDialogState(() => error = 'Sticker code can\'t contain "/"');
                  return;
                }

                final existing = await _firestore.collection('seats').doc(code).get();
                if (existing.exists) {
                  setDialogState(
                      () => error = 'Sticker "$code" is already registered to a seat');
                  return;
                }

                await _seatsRef.doc(code).set({
                  'label': label,
                  'order': nextOrder,
                  'active': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                await _firestore.collection('seats').doc(code).set({
                  'status': 'free',
                  'classroomId': widget.classroom.id,
                });

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(ClassroomSeat seat, bool active) async {
    await _seatsRef.doc(seat.seatId).update({'active': active});
  }

  // ── Delete / hide ────────────────────────────────────────────────────────

  Future<void> _handleDelete(ClassroomSeat seat) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    final futureDocs = await _futureReservations(seat.seatId);

    if (!mounted) return;

    if (futureDocs.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Delete seat ${seat.seatId}?'),
          content: const Text(
              'This seat has no upcoming reservations. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _deleteSeat(seat);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Seat ${seat.seatId} deleted')));
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            'Seat ${seat.seatId} has ${futureDocs.length} upcoming reservation${futureDocs.length == 1 ? '' : 's'}'),
        content: const Text('How would you like to remove this seat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Keep seat'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'hide'),
            child: const Text('Hide from new bookings'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, 'cancel_delete'),
            child: const Text('Cancel bookings & delete'),
          ),
        ],
      ),
    );

    if (choice == 'hide') {
      await _toggleActive(seat, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Seat ${seat.seatId} hidden from new bookings')));
      }
    } else if (choice == 'cancel_delete') {
      for (final doc in futureDocs) {
        await _cancelFirestoreReservation(doc, adminUid);
      }
      await _deleteSeat(seat);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Seat ${seat.seatId} deleted, ${futureDocs.length} booking${futureDocs.length == 1 ? '' : 's'} cancelled')));
      }
    }
  }

  Future<void> _deleteSeat(ClassroomSeat seat) async {
    await _firestore.collection('seats').doc(seat.seatId).delete();
    await _seatsRef.doc(seat.seatId).delete();
  }

  /// Cancels the RTDB-side reservation matching a Firestore reservations/
  /// doc — the two are linked by qrToken (Firestore doc id) == qr_token.
  Future<void> _cancelFirestoreReservation(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String? adminUid) async {
    final data = doc.data();
    final userId = data['userId'] as String?;
    if (userId == null) return;

    final rtdbSnap = await FirebaseDatabase.instance.ref('reservations/$userId').get();
    if (!rtdbSnap.exists || rtdbSnap.value == null) return;

    final raw = rtdbSnap.value as Map<dynamic, dynamic>;
    for (final entry in raw.entries) {
      final value = entry.value as Map<dynamic, dynamic>;
      if (value['qr_token'] == doc.id) {
        final reservation = Reservation.fromJson(entry.key.toString(), value);
        if (reservation.isUpcoming) {
          await cancelReservation(
            uid: userId,
            r: reservation,
            cancelledByAdminUid: adminUid,
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: Text(widget.classroom.displayName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _seatsRef.orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final seats =
              (snapshot.data?.docs ?? []).map(ClassroomSeat.fromDoc).toList();
          final nextOrder = seats.isEmpty
              ? 1
              : seats.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _showAddDialog(nextOrder),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
                    child: const Text('+  Add seat'),
                  ),
                ),
              ),
              Expanded(
                child: seats.isEmpty
                    ? const Center(
                        child: Text('No seats yet — add one above',
                            style: AppTextStyles.cardSubtitle),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: seats.length,
                        itemBuilder: (context, index) {
                          final seat = seats[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(seat.seatId,
                                              style: AppTextStyles.cardTitle
                                                  .copyWith(fontFamily: 'monospace')),
                                          const SizedBox(width: 8),
                                          if (!seat.active)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.gray,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Hidden',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textSecondary)),
                                            ),
                                        ],
                                      ),
                                      if (seat.label.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(seat.label, style: AppTextStyles.cardSubtitle),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!seat.active)
                                  IconButton(
                                    tooltip: 'Restore',
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: AppColors.blue),
                                    onPressed: () => _toggleActive(seat, true),
                                  ),
                                IconButton(
                                  tooltip: 'Edit label',
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                                  onPressed: () => _showEditSeatDialog(seat),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                  onPressed: () => _handleDelete(seat),
                                ),
                              ],
                            ),
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
