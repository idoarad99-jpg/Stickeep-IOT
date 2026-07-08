import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time migration: makes sure the `classrooms` collection is on the
/// current building/roomName + per-seat-sticker schema.
///
/// - If the collection is empty, seeds the original 'Taub 1'..'Taub 5'
///   rooms (5 seats each), using the same SEAT_T{n}_{1..5} sticker IDs
///   the app originally shipped with, so already-flashed hardware keeps
///   matching.
/// - If a classroom doc is still on the old {name, code, seatCount}
///   schema, migrates it in place to {building, roomName} and backfills
///   its seats subcollection from the old code/seatCount fields.
Future<void> ensureDefaultClassroomsSeeded() async {
  // This seed/migration runs at startup before auth — wrap in try/catch
  // so a permission-denied error never crashes the app. It will simply
  // retry next time an admin (or anyone with access) opens the app.
  try {
    final col = FirebaseFirestore.instance.collection('classrooms');
    final snapshot = await col.get();

    if (snapshot.docs.isEmpty) {
      await _seedDefaults(col);
      return;
    }

    for (final doc in snapshot.docs) {
      await _migrateIfNeeded(doc);
    }
  } catch (_) {
    // Not yet authenticated, or rules deny it — app continues normally.
  }
}

Future<void> _seedDefaults(CollectionReference<Map<String, dynamic>> col) async {
  for (var i = 1; i <= 5; i++) {
    final ref = col.doc('T$i');
    await ref.set({
      'building': 'Taub',
      'roomName': '$i',
      'order': i,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _seedSeats(ref, stickerPrefix: 'T$i', count: 5);
  }
}

Future<void> _migrateIfNeeded(
    QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
  final data = doc.data();
  final ref = doc.reference;

  if (data['building'] == null) {
    final oldName = (data['name'] as String? ?? doc.id).trim();
    final match = RegExp(r'^(.*?)\s+(\S+)$').firstMatch(oldName);
    await ref.update({
      'building': match?.group(1) ?? oldName,
      'roomName': match?.group(2) ?? oldName,
      'name': FieldValue.delete(),
    });
  }

  // Backfill the seats subcollection from the old code/seatCount fields,
  // if it hasn't been populated yet.
  final oldCode = data['code'] as String?;
  final oldSeatCount = (data['seatCount'] as num?)?.toInt();
  if (oldCode != null && oldSeatCount != null) {
    final existingSeats = await ref.collection('seats').limit(1).get();
    if (existingSeats.docs.isEmpty) {
      await _seedSeats(ref, stickerPrefix: oldCode, count: oldSeatCount);
    }
    await ref.update({
      'code': FieldValue.delete(),
      'seatCount': FieldValue.delete(),
    });
  }
}

Future<void> _seedSeats(
  DocumentReference<Map<String, dynamic>> classroomRef, {
  required String stickerPrefix,
  required int count,
}) async {
  final topLevelSeats = FirebaseFirestore.instance.collection('seats');
  for (var n = 1; n <= count; n++) {
    final seatId = 'SEAT_${stickerPrefix}_$n';
    await classroomRef.collection('seats').doc(seatId).set({
      'label': 'Seat $n',
      'order': n,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Placeholder so the global sticker-uniqueness check when admin adds
    // a new seat elsewhere sees this code as already taken.
    final seatDoc = await topLevelSeats.doc(seatId).get();
    if (!seatDoc.exists) {
      await topLevelSeats.doc(seatId).set({
        'status': 'free',
        'classroomId': classroomRef.id,
      });
    }
  }
}
