class Reservation {
  final String id;
  final String studentId;
  final String classroom;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final int seatNumber;
  final bool isUpcoming;
  final String? seatId;
  final String? qrToken;

  Reservation({
    required this.id,
    required this.studentId,
    required this.classroom,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatNumber,
    this.seatId,
    this.qrToken,
    required this.isUpcoming,
  });

  factory Reservation.fromJson(String id, Map<dynamic, dynamic> json) {
    return Reservation(
      id: id,
      studentId: json['student_id'] ?? '',
      classroom: json['classroom'] ?? '',
      lessonName: json['lesson_name'] ?? '',
      date: json['date'] ?? '',
      timeStart: json['time_start'] ?? '',
      timeEnd: json['time_end'] ?? '',
      seatNumber: json['seat_number'] ?? 0,
      isUpcoming: json['is_upcoming'] ?? true,
      seatId: json['seat_id'] as String?,
      qrToken: json['qr_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'classroom': classroom,
        'lesson_name': lessonName,
        'date': date,
        'time_start': timeStart,
        'time_end': timeEnd,
        'seat_number': seatNumber,
        'is_upcoming': isUpcoming,
        'seat_id': seatId,
      };
}
