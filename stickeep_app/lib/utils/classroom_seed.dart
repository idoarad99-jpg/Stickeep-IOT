import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time migration: seeds the original hardcoded 'Taub 1'..'Taub 5'
/// classrooms into Firestore so admin can manage them going forward.
/// No-ops if the classrooms collection already has data.
Future<void> ensureDefaultClassroomsSeeded() async {
  final col = FirebaseFirestore.instance.collection('classrooms');
  final existing = await col.limit(1).get();
  if (existing.docs.isNotEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (var i = 1; i <= 5; i++) {
    final ref = col.doc('T$i');
    batch.set(ref, {
      'name': 'Taub $i',
      'code': 'T$i',
      'seatCount': 5,
      'order': i,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
