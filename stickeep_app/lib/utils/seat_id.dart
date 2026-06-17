// Maps classroom name + seat number → Firestore seatId (e.g. SEAT_T1_2).
// 5 accessible seats per classroom.

String? seatIdFromClassroom(String classroomId, int seatNumber) {
  final match = RegExp(r'taub\s*(\d+)', caseSensitive: false)
      .firstMatch(classroomId.trim());
  if (match == null) return null;
  return 'SEAT_T${match.group(1)}_$seatNumber';
}

// Returns all 5 seatIds for a classroom.
List<String> seatIdsForClassroom(String classroomId) =>
    List.generate(5, (i) => seatIdFromClassroom(classroomId, i + 1))
        .whereType<String>()
        .toList();

// Returns classroom name from seatId (e.g. SEAT_T1_2 → Taub 1)
String classroomFromSeatId(String seatId) {
  final match = RegExp(r'SEAT_T(\d+)_').firstMatch(seatId);
  if (match == null) return '';
  return 'Taub ${match.group(1)}';
}

// Returns seat number from seatId (e.g. SEAT_T1_2 → 2)
int seatNumberFromSeatId(String seatId) {
  final match = RegExp(r'SEAT_T\d+_(\d+)').firstMatch(seatId);
  if (match == null) return 0;
  return int.tryParse(match.group(1) ?? '0') ?? 0;
}