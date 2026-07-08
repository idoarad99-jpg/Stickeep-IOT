import 'package:cloud_firestore/cloud_firestore.dart';

/// A single physical seat inside a classroom — doc ID is the seat's
/// actual sticker code (e.g. matches an ESP32 unit's identifier).
/// Lives at classrooms/{classroomId}/seats/{seatId}.
class ClassroomSeat {
  final String seatId;
  final String label;
  final int order;
  final bool active;

  ClassroomSeat({
    required this.seatId,
    required this.label,
    required this.order,
    required this.active,
  });

  factory ClassroomSeat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ClassroomSeat(
      seatId: doc.id,
      label: data['label'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }
}
