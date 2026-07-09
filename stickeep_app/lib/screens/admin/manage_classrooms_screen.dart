import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/classroom.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/screens/admin/manage_seats_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/cancel_reservation.dart';
import 'package:stickeep_app/utils/page_route.dart';
import 'package:stickeep_app/widgets/loading_skeleton.dart';

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

  /// Upcoming (today or later) 'reserved' docs anywhere in [classroomId].
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _futureReservations(
      String classroomId) async {
    final query = await _firestore
        .collection('reservations')
        .where('classroomId', isEqualTo: classroomId)
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
    final buildingController = TextEditingController();
    final roomController = TextEditingController();
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
                controller: buildingController,
                decoration: const InputDecoration(
                  labelText: 'Building',
                  hintText: 'e.g. Ulman, Taub',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomController,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  hintText: 'e.g. Room 1, 214',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll add individual seats (with their sticker codes) after creating the room.',
                style: AppTextStyles.cardSubtitle,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: AppColors.red, fontSize: 12)),
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
                final building = buildingController.text.trim();
                final room = roomController.text.trim();

                if (building.isEmpty || room.isEmpty) {
                  setDialogState(() => error = 'Building and room are required');
                  return;
                }

                final duplicate = await _firestore
                    .collection('classrooms')
                    .where('building', isEqualTo: building)
                    .where('roomName', isEqualTo: room)
                    .limit(1)
                    .get();
                if (duplicate.docs.isNotEmpty) {
                  setDialogState(
                      () => error = '$building — $room already exists');
                  return;
                }

                await _firestore.collection('classrooms').add({
                  'building': building,
                  'roomName': room,
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
    final buildingController = TextEditingController(text: c.building);
    final roomController = TextEditingController(text: c.roomName);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit ${c.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: buildingController,
                decoration: const InputDecoration(labelText: 'Building'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomController,
                decoration: const InputDecoration(labelText: 'Room'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: AppColors.red, fontSize: 12)),
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
                final building = buildingController.text.trim();
                final room = roomController.text.trim();

                if (building.isEmpty || room.isEmpty) {
                  setDialogState(() => error = 'Building and room are required');
                  return;
                }

                await _firestore.collection('classrooms').doc(c.id).update({
                  'building': building,
                  'roomName': room,
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

    final futureDocs = await _futureReservations(c.id);

    if (!mounted) return;

    if (futureDocs.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Delete ${c.displayName}?'),
          content: const Text(
              'This classroom has no upcoming reservations. This cannot be undone — all its seats will be deleted too.'),
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
      await _deleteClassroomAndSeats(c);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${c.displayName} deleted')));
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            '${c.displayName} has ${futureDocs.length} upcoming reservation${futureDocs.length == 1 ? '' : 's'}'),
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
      await _firestore.collection('classrooms').doc(c.id).update({'active': false});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${c.displayName} hidden from new bookings')));
      }
    } else if (choice == 'cancel_delete') {
      for (final doc in futureDocs) {
        await _cancelFirestoreReservation(doc, adminUid);
      }
      await _deleteClassroomAndSeats(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${c.displayName} deleted, ${futureDocs.length} booking${futureDocs.length == 1 ? '' : 's'} cancelled')));
      }
    }
  }

  Future<void> _deleteClassroomAndSeats(Classroom c) async {
    final classroomRef = _firestore.collection('classrooms').doc(c.id);
    final seats = await classroomRef.collection('seats').get();
    for (final seatDoc in seats.docs) {
      await _firestore.collection('seats').doc(seatDoc.id).delete();
      await seatDoc.reference.delete();
    }
    await classroomRef.delete();
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
    await _firestore.collection('classrooms').doc(c.id).update({'active': active});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Manage classrooms', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('classrooms').orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminListSkeleton();
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
                    ? const EmptyState(
                        icon: Icons.meeting_room_outlined,
                        title: 'No classrooms yet',
                        subtitle: 'Tap "Add classroom" above to create the first one.',
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
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(c.displayName,
                                                style: AppTextStyles.cardTitle,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!c.active)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.gray,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('Hidden',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textSecondary)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!c.active)
                                      IconButton(
                                        tooltip: 'Restore',
                                        icon: Icon(Icons.visibility_outlined,
                                            color: AppColors.blue),
                                        onPressed: () => _toggleActive(c, true),
                                      ),
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: Icon(Icons.edit_outlined, color: AppColors.blue),
                                      onPressed: () => _showEditDialog(c),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: Icon(Icons.delete_outline, color: AppColors.red),
                                      onPressed: () => _handleDelete(c),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: _firestore
                                      .collection('classrooms')
                                      .doc(c.id)
                                      .collection('seats')
                                      .snapshots(),
                                  builder: (context, seatsSnap) {
                                    final seatCount = seatsSnap.data?.docs.length;
                                    return SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          AppPageRoute(
                                            builder: (_) => ManageSeatsScreen(classroom: c),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 36),
                                          foregroundColor: AppColors.purple,
                                          side: BorderSide(color: AppColors.purple),
                                        ),
                                        child: Text(seatCount == null
                                            ? '🪑  Manage seats'
                                            : '🪑  Manage seats ($seatCount)'),
                                      ),
                                    );
                                  },
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
