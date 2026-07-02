import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/utils/seat_id.dart';

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
  final seatId = seatIdFromClassroom(r.classroom, r.seatNumber);
  if (seatId != null) {
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
