class Reservation {
  final String id;
  final String studentId;
  final String studentNumber;
  final String classroom;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final int seatNumber;
  final bool isUpcoming;
  final String? seatId;
  final String? qrToken;
  final String nfcStatus; // '', 'pending', 'approved', 'declined'
  final String qrStatus;  // '', 'arrived'
  final String? recurringGroupId;

  Reservation({
    required this.id,
    required this.studentId,
    required this.studentNumber,
    required this.classroom,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatNumber,
    this.seatId,
    this.qrToken,
    required this.isUpcoming,
    this.nfcStatus = '',
    this.qrStatus = '',
    this.recurringGroupId,
  });

  factory Reservation.fromJson(String id, Map<dynamic, dynamic> json) {
    return Reservation(
      id: id,
      studentId: json['student_id'] as String? ?? '',
      studentNumber: json['student_number'] as String? ?? '',
      classroom: json['classroom'] as String? ?? '',
      lessonName: json['lesson_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      timeStart: json['time_start'] as String? ?? '',
      timeEnd: json['time_end'] as String? ?? '',
      seatNumber: (json['seat_number'] as num?)?.toInt() ?? 0,
      isUpcoming: json['is_upcoming'] as bool? ?? true,
      seatId: json['seat_id'] as String?,
      qrToken: json['qr_token'] as String?,
      nfcStatus: json['nfc_status'] as String? ?? '',
      qrStatus: json['qr_status'] as String? ?? '',
      recurringGroupId: json['recurring_group_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'student_number': studentNumber,
        'classroom': classroom,
        'lesson_name': lessonName,
        'date': date,
        'time_start': timeStart,
        'time_end': timeEnd,
        'seat_number': seatNumber,
        'is_upcoming': isUpcoming,
        'seat_id': seatId,
        'nfc_status': nfcStatus,
        'qr_status': qrStatus,
        if (recurringGroupId != null) 'recurring_group_id': recurringGroupId,
      };
}
