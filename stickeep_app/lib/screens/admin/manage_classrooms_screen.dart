import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/classroom.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/cancel_reservation.dart';

class ManageClassroomsScreen extends StatefulWidget {
  const ManageClassroomsScreen({super.key});

  @override
  State<ManageClassroomsScreen> createState() => _ManageClassroomsScreenState();
}

class _ManageClassroomsScreenState extends State<ManageClassroomsScreen> {
  final _firestore = FirebaseFirestore.instance;

  DateTime? _parseDate(String d) {
    final parts = d.split('.');
    if (parts.length != 3) return null;
    return DateTime(
      int.tryParse(parts[2]) ?? 2000,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[0]) ?? 1,
    );
  }

  /// Upcoming (today or later) 'reserved' docs for [classroomCode], optionally
  /// restricted to seat numbers above [seatNumberAbove].
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _futureReservations(
    String classroomCode, {
    int? seatNumberAbove,
  }) async {
    final query = await _firestore
        .collection('reservations')
        .where('classroomId', isEqualTo: classroomCode)
        .where('status', isEqualTo: 'reserved')
        .get();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return query.docs.where((d) {
      final data = d.data();
      final date = _parseDate(data['date'] as String? ?? '');
      if (date == null || date.isBefore(todayDate)) return false;
      if (seatNumberAbove != null) {
        final seatNumber = (data['seatNumber'] as num?)?.toInt() ?? 0;
        if (seatNumber <= seatNumberAbove) return false;
      }
      return true;
    }).toList();
  }

  // ── Add ──────────────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int nextOrder) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final seatCountController = TextEditingController(text: '5');
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add classroom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Taub 6',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Sticker code',
                  hintText: 'e.g. T6 — must match the ESP32 sticker labels',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seatCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of seats'),
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
                final name = nameController.text.trim();
                final code = codeController.text.trim().toUpperCase().replaceAll(' ', '');
                final seatCount = int.tryParse(seatCountController.text.trim());

                if (name.isEmpty || code.isEmpty) {
                  setDialogState(() => error = 'Name and code are required');
                  return;
                }
                if (seatCount == null || seatCount < 1) {
                  setDialogState(() => error = 'Seat count must be a positive number');
                  return;
                }

                final existing = await _firestore.collection('classrooms').doc(code).get();
                if (existing.exists) {
                  setDialogState(() => error = 'Code "$code" is already in use');
                  return;
                }

                await _firestore.collection('classrooms').doc(code).set({
                  'name': name,
                  'code': code,
                  'seatCount': seatCount,
                  'order': nextOrder,
                  'active': true,
                  'createdAt': FieldValue.serverTimestamp(),
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

  // ── Edit ─────────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(Classroom c) async {
    final nameController = TextEditingController(text: c.name);
    final seatCountController =
        TextEditingController(text: c.seatCount.toString());
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit ${c.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: false,
                controller: TextEditingController(text: c.code),
                decoration: const InputDecoration(
                  labelText: 'Sticker code',
                  helperText: 'Fixed — matches physical ESP32 stickers',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seatCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Number of seats',
                  helperText:
                      'Increasing this adds seats — make sure new stickers use SEAT_${c.code}_<n>',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 12)),
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
                final name = nameController.text.trim();
                final seatCount = int.tryParse(seatCountController.text.trim());

                if (name.isEmpty) {
                  setDialogState(() => error = 'Name is required');
                  return;
                }
                if (seatCount == null || seatCount < 1) {
                  setDialogState(
                      () => error = 'Seat count must be a positive number');
                  return;
                }

                if (seatCount < c.seatCount) {
                  final affected = await _futureReservations(c.code,
                      seatNumberAbove: seatCount);
                  if (affected.isNotEmpty) {
                    if (!dialogContext.mounted) return;
                    final proceed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (_) => AlertDialog(
                        title: const Text('Seats have upcoming reservations'),
                        content: Text(
                            '${affected.length} upcoming reservation${affected.length == 1 ? '' : 's'} '
                            'use a seat number above $seatCount. They will remain valid, but '
                            '${c.name} will no longer offer that seat for new bookings. Continue?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            style:
                                TextButton.styleFrom(foregroundColor: AppColors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reduce anyway'),
                          ),
                        ],
                      ),
                    );
                    if (proceed != true) return;
                  }
                }

                if (!dialogContext.mounted) return;
                await _firestore.collection('classrooms').doc(c.code).update({
                  'name': name,
                  'seatCount': seatCount,
                });

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete / hide ────────────────────────────────────────────────────────

  Future<void> _handleDelete(Classroom c) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    final futureDocs = await _futureReservations(c.code);

    if (!mounted) return;

    if (futureDocs.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Delete ${c.name}?'),
          content: const Text(
              'This classroom has no upcoming reservations. This cannot be undone.'),
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
      await _firestore.collection('classrooms').doc(c.code).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${c.name} deleted')));
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            '${c.name} has ${futureDocs.length} upcoming reservation${futureDocs.length == 1 ? '' : 's'}'),
        content: const Text('How would you like to remove this classroom?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Keep classroom'),
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
      await _firestore.collection('classrooms').doc(c.code).update({'active': false});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${c.name} hidden from new bookings')));
      }
    } else if (choice == 'cancel_delete') {
      for (final doc in futureDocs) {
        await _cancelFirestoreReservation(doc, adminUid);
      }
      await _firestore.collection('classrooms').doc(c.code).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${c.name} deleted, ${futureDocs.length} booking${futureDocs.length == 1 ? '' : 's'} cancelled')));
      }
    }
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
        final reservation =
            Reservation.fromJson(entry.key.toString(), value);
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

  Future<void> _toggleActive(Classroom c, bool active) async {
    await _firestore.collection('classrooms').doc(c.code).update({'active': active});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Manage classrooms', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('classrooms').orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final classrooms =
              (snapshot.data?.docs ?? []).map(Classroom.fromDoc).toList();
          final nextOrder = classrooms.isEmpty
              ? 1
              : classrooms.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _showAddDialog(nextOrder),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
                    child: const Text('+  Add classroom'),
                  ),
                ),
              ),
              Expanded(
                child: classrooms.isEmpty
                    ? const Center(
                        child: Text('No classrooms yet',
                            style: AppTextStyles.cardSubtitle),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: classrooms.length,
                        itemBuilder: (context, index) {
                          final c = classrooms[index];
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
                                          Text(c.name, style: AppTextStyles.cardTitle),
                                          const SizedBox(width: 8),
                                          if (!c.active)
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
                                      const SizedBox(height: 2),
                                      Text('Code ${c.code} · ${c.seatCount} seats',
                                          style: AppTextStyles.cardSubtitle),
                                    ],
                                  ),
                                ),
                                if (!c.active)
                                  IconButton(
                                    tooltip: 'Restore',
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: AppColors.blue),
                                    onPressed: () => _toggleActive(c, true),
                                  ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                                  onPressed: () => _showEditDialog(c),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                                  onPressed: () => _handleDelete(c),
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
