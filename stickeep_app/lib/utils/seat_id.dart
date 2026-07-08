// Maps classroom code + seat number → Firestore seatId (e.g. SEAT_T1_2).
// The code is the admin-assigned identifier matching the physical ESP32
// sticker labels for that classroom (see manage_classrooms_screen.dart).

String? seatIdFromClassroom(String classroomCode, int seatNumber) {
  final code = classroomCode.trim();
  if (code.isEmpty) return null;
  return 'SEAT_${code}_$seatNumber';
}

// Returns all seatIds for a classroom, one per seat.
List<String> seatIdsForClassroom(String classroomCode, int seatCount) =>
    List.generate(seatCount, (i) => seatIdFromClassroom(classroomCode, i + 1))
        .whereType<String>()
        .toList();
