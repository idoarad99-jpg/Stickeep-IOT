import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class BookingResult {
  final String rtdbKey;
  final String firestoreId;
  final String? seatId;

  BookingResult({
    required this.rtdbKey,
    required this.firestoreId,
    required this.seatId,
  });
}

/// True if [seatId] already has a 'reserved' reservation overlapping the
/// exact [date]/[timeStart]/[timeEnd] slot.
Future<bool> isSeatTaken({
  required String seatId,
  required String date,
  required String timeStart,
  required String timeEnd,
}) async {
  final existing = await FirebaseFirestore.instance
      .collection('seats')
      .doc(seatId)
      .collection('reservations')
      .where('date', isEqualTo: date)
      .where('startTime', isEqualTo: timeStart)
      .where('endTime', isEqualTo: timeEnd)
      .where('status', isEqualTo: 'reserved')
      .limit(1)
      .get();
  return existing.docs.isNotEmpty;
}

/// Creates a single reservation across RTDB + Firestore + the seats collection.
Future<BookingResult> createReservation({
  required String uid,
  required String classroom,
  required String classroomId,
  required String lessonName,
  required String date,
  required String timeStart,
  required String timeEnd,
  required String seatId,
  required int seatNumber,
  required String studentNumber,
  String? recurringGroupId,
  String? nfcSerialNumber,
}) async {
  final firestoreRef =
      FirebaseFirestore.instance.collection('reservations').doc();

  // Hardware-facing: write reserved status to RTDB at seats/{seatId}
  await FirebaseDatabase.instance
      .ref('seats/$seatId')
      .update({'status': 'reserved'});

  final reservationRef =
      FirebaseDatabase.instance.ref('reservations/$uid').push();

  await reservationRef.set({
    'classroom': classroom,
    'lesson_name': lessonName,
    'date': date,
    'time_start': timeStart,
    'time_end': timeEnd,
    'seat_number': seatNumber,
    'student_number': studentNumber,
    'seat_id': seatId,
    'qr_token': firestoreRef.id,
    'qr_status': '',
    'nfc_status': '',
    'is_upcoming': true,
    'created_at': DateTime.now().toIso8601String(),
    'sort_key': int.parse(
      date.split('.').reversed.join() + timeStart.replaceAll(':', ''),
    ),
    if (recurringGroupId != null) 'recurring_group_id': recurringGroupId,
  });

  await firestoreRef.set({
    'classroomId': classroomId,
    'lessonName': lessonName,
    'date': date,
    'startTime': timeStart,
    'endTime': timeEnd,
    'seatNumber': seatNumber,
    'status': 'reserved',
    'userId': uid,
    'studentNumber': studentNumber,
    'seatId': seatId,
    'createdAt': FieldValue.serverTimestamp(),
    'qrToken': firestoreRef.id,
    if (nfcSerialNumber != null) 'nfcSerialNumber': nfcSerialNumber,
    if (recurringGroupId != null) 'recurringGroupId': recurringGroupId,
  });

  final seatDocRef =
      FirebaseFirestore.instance.collection('seats').doc(seatId);
  await seatDocRef.set({
    'status': 'reserved',
    'studentNumber': studentNumber,
    if (nfcSerialNumber != null) 'nfcSerialNumber': nfcSerialNumber,
    'startTime': timeStart,
    'endTime': timeEnd,
    'date': date,
    'classroomId': classroomId,
    'reservationId': firestoreRef.id,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  await seatDocRef.collection('reservations').doc(firestoreRef.id).set({
    'studentNumber': studentNumber,
    'userId': uid,
    'date': date,
    'startTime': timeStart,
    'endTime': timeEnd,
    'classroomId': classroomId,
    'status': 'reserved',
    'createdAt': FieldValue.serverTimestamp(),
    'qrToken': firestoreRef.id,
    if (nfcSerialNumber != null) 'nfcSerialNumber': nfcSerialNumber,
  });

  return BookingResult(
    rtdbKey: reservationRef.key!,
    firestoreId: firestoreRef.id,
    seatId: seatId,
  );
}

/// Tags an already-created reservation as belonging to recurring group.
Future<void> tagReservationAsRecurring({
  required String uid,
  required String rtdbKey,
  required String firestoreId,
  required String recurringGroupId,
}) async {
  await FirebaseDatabase.instance
      .ref('reservations/$uid/$rtdbKey')
      .update({'recurring_group_id': recurringGroupId});
  await FirebaseFirestore.instance
      .collection('reservations')
      .doc(firestoreId)
      .update({'recurringGroupId': recurringGroupId});
}
