import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  final String id;
  final String building;
  final String roomName;
  final int order;
  final bool active;

  Classroom({
    required this.id,
    required this.building,
    required this.roomName,
    required this.order,
    required this.active,
  });

  String get displayName => '$building $roomName';

  factory Classroom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Classroom(
      id: doc.id,
      building: data['building'] as String? ?? '',
      roomName: data['roomName'] as String? ?? (data['name'] as String? ?? doc.id),
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }
}
