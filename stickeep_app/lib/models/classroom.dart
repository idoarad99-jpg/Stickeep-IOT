import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  final String code;
  final String name;
  final int seatCount;
  final int order;
  final bool active;

  Classroom({
    required this.code,
    required this.name,
    required this.seatCount,
    required this.order,
    required this.active,
  });

  factory Classroom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Classroom(
      code: doc.id,
      name: data['name'] as String? ?? doc.id,
      seatCount: (data['seatCount'] as num?)?.toInt() ?? 5,
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }
}
