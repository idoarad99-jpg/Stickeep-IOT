enum SeatStatus { free, occupied, reserved, regular }

class Seat {
  final int id;
  final bool isSpecial; // מושב נגיש
  SeatStatus status;

  Seat({
    required this.id,
    required this.isSpecial,
    this.status = SeatStatus.regular,
  });

  factory Seat.fromJson(int id, Map<dynamic, dynamic> json) {
    return Seat(
      id: id,
      isSpecial: json['is_special'] ?? false,
      status: _parseStatus(json['status'] ?? 'regular'),
    );
  }

  Map<String, dynamic> toJson() => {
        'is_special': isSpecial,
        'status': status.name,
      };

  static SeatStatus _parseStatus(String s) {
    switch (s) {
      case 'free':
        return SeatStatus.free;
      case 'occupied':
        return SeatStatus.occupied;
      case 'reserved':
        return SeatStatus.reserved;
      default:
        return SeatStatus.regular;
    }
  }
}
