import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:stickeep_app/utils/seat_id.dart';

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

/// Creates a single reservation across RTDB + Firestore + the seats
/// collection, mirroring the writes the booking flow has always made.
/// Does NOT check availability first — call [isSeatTaken] beforehand.
Future<BookingResult> createReservation({
  required String uid,
  required String classroom,
  required String classroomCode,
  required String lessonName,
  required String date,
  required String timeStart,
  required String timeEnd,
  required int seatNumber,
  required String studentNumber,
  required DatabaseReference seatsRef,
  String? recurringGroupId,
  String? nfcSerialNumber,
}) async {
  final seatId = seatIdFromClassroom(classroomCode, seatNumber);
  final firestoreRef = FirebaseFirestore.instance.collection('reservations').doc();

  await seatsRef.child('seat_' + seatNumber.toString()).update({'status': 'reserved'});

  final reservationRef = FirebaseDatabase.instance.ref('reservations/' + uid).push();

  await reservationRef.set({
    'classroom': classroom,
    'lesson_name': lessonName,
    'date': date,
    'time_start': timeStart,
    'time_end': timeEnd,
    'seat_number': seatNumber,
    'student_number': studentNumber,
    'seat_id': seatId ?? '',
    'qr_token': firestoreRef.id,
    'is_upcoming': true,
    'created_at': DateTime.now().toIso8601String(),
    // Numeric sort key: YYYYMMDDHHMM — used by Flutter + ESP32 to sort reservations
    'sort_key': int.parse(
      date.split('.').reversed.join() + timeStart.replaceAll(':', ''),
    ),
    if (recurringGroupId != null) 'recurring_group_id': recurringGroupId,
  });

  await firestoreRef.set({
    'classroomId': classroomCode,
    'lessonName': lessonName,
    'date': date,
    'startTime': timeStart,
    'endTime': timeEnd,
    'seatNumber': seatNumber,
    'status': 'reserved',
    'userId': uid,
    'studentNumber': studentNumber,
    'seatId': seatId ?? '',
    'createdAt': FieldValue.serverTimestamp(),
    'qrToken': firestoreRef.id,
    if (recurringGroupId != null) 'recurringGroupId': recurringGroupId,
  });

  if (seatId != null) {
    final seatDocRef = FirebaseFirestore.instance.collection('seats').doc(seatId);
    await seatDocRef.set({
      'status': 'reserved',
      'studentNumber': studentNumber,
      if (nfcSerialNumber != null) 'nfcSerialNumber': nfcSerialNumber,
      'startTime': timeStart,
      'endTime': timeEnd,
      'date': date,
      'classroomId': classroomCode,
      'reservationId': firestoreRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await seatDocRef.collection('reservations').doc(firestoreRef.id).set({
      'studentNumber': studentNumber,
      'userId': uid,
      'date': date,
      'startTime': timeStart,
      'endTime': timeEnd,
      'classroomId': classroomCode,
      'status': 'reserved',
      'createdAt': FieldValue.serverTimestamp(),
      'qrToken': firestoreRef.id,
    });
  }

  return BookingResult(
    rtdbKey: reservationRef.key!,
    firestoreId: firestoreRef.id,
    seatId: seatId,
  );
}

/// Tags an already-created reservation (identified by [rtdbKey] / [firestoreId])
/// as belonging to recurring group [recurringGroupId], across RTDB + Firestore.
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
