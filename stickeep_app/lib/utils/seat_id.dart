// Maps classroom name + seat number → Firestore seatId (e.g. SEAT_T1_2).
// Only seats 1–4 per classroom have physical IoT stickers.
String? seatIdFromClassroom(String classroomId, int seatNumber) {
  final match =
      RegExp(r'taub\s*(\d+)', caseSensitive: false).firstMatch(classroomId.trim());
  if (match == null) return null;
  return 'SEAT_T${match.group(1)}_$seatNumber';
}

// Returns the 4 seatIds for a classroom (empty list if classroom not mapped).
List<String> seatIdsForClassroom(String classroomId) =>
    List.generate(4, (i) => seatIdFromClassroom(classroomId, i + 1))
        .whereType<String>()
        .toList();
