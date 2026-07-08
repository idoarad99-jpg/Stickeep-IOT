import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';

/// Cancels [r], a reservation belonging to [uid].
///
/// Archives the reservation to the Firestore `graveyard` collection,
/// marks it as no-longer-upcoming in RTDB, and frees the matching
/// Firestore seat document (deleting the live reservation copies).
///
/// If [cancelledByAdminUid] is provided, the cancellation is recorded
/// in the graveyard as an admin-initiated cancellation (audit trail).
/// If omitted, it's treated as a self-cancellation by the student.
Future<void> cancelReservation({
  required String uid,
  required Reservation r,
  String? cancelledByAdminUid,
}) async {
  // Archive to graveyard before wiping the live record.
  await FirebaseFirestore.instance.collection('graveyard').add({
    'student_id': uid,
    'classroom': r.classroom,
    'lesson_name': r.lessonName,
    'date': r.date,
    'time_start': r.timeStart,
    'time_end': r.timeEnd,
    'seat_number': r.seatNumber,
    'seat_id': r.seatId,
    'original_reservation_id': r.id,
    'cancelled_at': FieldValue.serverTimestamp(),
    if (r.nfcStatus.isNotEmpty) 'nfc_status': r.nfcStatus,
    'cancelled_by': cancelledByAdminUid != null ? 'admin' : 'self',
    if (cancelledByAdminUid != null) 'cancelled_by_uid': cancelledByAdminUid,
  });

  await FirebaseDatabase.instance
      .ref('reservations/$uid/${r.id}')
      .update({'is_upcoming': false});

  // Clear the Firestore seats document for this reservation.
  final seatId = r.seatId;
  if (seatId != null && seatId.isNotEmpty) {
    final seatDocRef = FirebaseFirestore.instance.collection('seats').doc(seatId);
    final seatDoc = await seatDocRef.get();
    if (seatDoc.exists) {
      final data = seatDoc.data()!;
      if (data['date'] == r.date &&
          data['startTime'] == r.timeStart &&
          data['endTime'] == r.timeEnd) {
        final fsReservationId = data['reservationId'] as String?;
        await seatDocRef.update({
          'status': 'free',
          'studentNumber': '',
          'startTime': '',
          'endTime': '',
          'date': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Hardware-facing: clear the seat's own RTDB status too, so its
        // ESP32 unit stops showing 'reserved' after a cancellation.
        await FirebaseDatabase.instance.ref('seats/$seatId').update({'status': 'free'});
        if (fsReservationId != null) {
          // Data is already archived in graveyard — delete the live
          // copies instead of just flagging them as cancelled.
          await seatDocRef
              .collection('reservations')
              .doc(fsReservationId)
              .delete();
          await FirebaseFirestore.instance
              .collection('reservations')
              .doc(fsReservationId)
              .delete();
        }
      }
    }
  }
}

/// Cancels every still-upcoming reservation in [uid]'s RTDB list that shares
/// [recurringGroupId]. Returns how many were cancelled.
Future<int> cancelRecurringGroup({
  required String uid,
  required String recurringGroupId,
  String? cancelledByAdminUid,
}) async {
  final snapshot = await FirebaseDatabase.instance.ref('reservations/$uid').get();
  if (!snapshot.exists || snapshot.value == null) return 0;

  final raw = snapshot.value as Map<dynamic, dynamic>;
  final toCancel = raw.entries
      .map((e) =>
          Reservation.fromJson(e.key.toString(), e.value as Map<dynamic, dynamic>))
      .where((r) => r.isUpcoming && r.recurringGroupId == recurringGroupId)
      .toList();

  for (final r in toCancel) {
    await cancelReservation(uid: uid, r: r, cancelledByAdminUid: cancelledByAdminUid);
  }
  return toCancel.length;
}

enum _CancelChoice { keep, one, group }

/// Shows the appropriate cancel confirmation dialog for [r] — a plain
/// keep/cancel dialog for one-off reservations, or a three-way keep/cancel
/// this one/cancel all future dialog when [r] belongs to a recurring group —
/// then performs the chosen action.
///
/// Returns how many reservations were cancelled (0 if the user backed out).
Future<int> handleCancelChoice({
  required BuildContext context,
  required String uid,
  required Reservation r,
  String? cancelledByAdminUid,
}) async {
  final isRecurring =
      r.recurringGroupId != null && r.recurringGroupId!.isNotEmpty;

  if (!isRecurring) {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return 0;
    await cancelReservation(uid: uid, r: r, cancelledByAdminUid: cancelledByAdminUid);
    return 1;
  }

  final choice = await showDialog<_CancelChoice>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cancel reservation?'),
      content: const Text(
          'This reservation repeats. What would you like to cancel?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _CancelChoice.keep),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _CancelChoice.one),
          child: const Text('Cancel only this'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          onPressed: () => Navigator.pop(context, _CancelChoice.group),
          child: const Text('Cancel all future'),
        ),
      ],
    ),
  );

  switch (choice) {
    case _CancelChoice.one:
      await cancelReservation(uid: uid, r: r, cancelledByAdminUid: cancelledByAdminUid);
      return 1;
    case _CancelChoice.group:
      return cancelRecurringGroup(
        uid: uid,
        recurringGroupId: r.recurringGroupId!,
        cancelledByAdminUid: cancelledByAdminUid,
      );
    case _CancelChoice.keep:
    case null:
      return 0;
  }
}
