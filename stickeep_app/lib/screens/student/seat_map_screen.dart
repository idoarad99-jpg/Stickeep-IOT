import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/seat.dart';
import 'package:stickeep_app/screens/student/confirm_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class SeatMapScreen extends StatefulWidget {
  final String classroom;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;

  const SeatMapScreen({
    super.key,
    required this.classroom,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
  });

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  int? _selectedSeatId;

  final Set<int> _specialSeats = {1, 2, 3, 4};

  // Query reservations for this classroom + date that are active.
  // Time-slot match is done in Dart because Firestore doesn't allow
  // multiple inequality filters on different fields.
  Stream<QuerySnapshot<Map<String, dynamic>>> get _reservationsStream =>
      FirebaseFirestore.instance
          .collection('reservations')
          .where('classroomId', isEqualTo: widget.classroom)
          .where('date', isEqualTo: widget.date)
          .where('status', whereIn: ['reserved', 'occupied'])
          .snapshots();

  Map<int, SeatStatus> _buildSeatStatuses(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final statuses = <int, SeatStatus>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // Only count reservations that overlap this exact time slot.
      if (data['startTime'] != widget.timeStart ||
          data['endTime'] != widget.timeEnd) continue;
      final raw = data['seatNumber'];
      if (raw == null) continue;
      final id = raw is int ? raw : int.tryParse('$raw');
      if (id == null) continue;
      statuses[id] = data['status'] == 'occupied'
          ? SeatStatus.occupied
          : SeatStatus.reserved;
    }
    return statuses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${widget.date}  •  ${widget.timeStart}–${widget.timeEnd}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Legend ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(AppColors.greenLight, AppColors.green, 'Free'),
                const SizedBox(width: 12),
                _legendItem(AppColors.amberLight, AppColors.amber, 'Reserved'),
                const SizedBox(width: 12),
                _legendItem(AppColors.redLight, AppColors.red, 'Occupied'),
                const SizedBox(width: 12),
                _legendItem(AppColors.blueLight, AppColors.blue, 'Selected'),
              ],
            ),
          ),

          // ── Seat grid (real-time via Firestore) ──────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _reservationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final seatStatuses = snapshot.hasData
                    ? _buildSeatStatuses(snapshot.data!)
                    : <int, SeatStatus>{};

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: 20,
                  itemBuilder: (context, index) {
                    final seatId = index + 1;
                    final status =
                        seatStatuses[seatId] ?? SeatStatus.free;
                    final isSpecial = _specialSeats.contains(seatId);
                    final isSelected = _selectedSeatId == seatId;
                    final isAvailable = status == SeatStatus.free;

                    return GestureDetector(
                      onTap: isAvailable
                          ? () => setState(() {
                                _selectedSeatId =
                                    isSelected ? null : seatId;
                              })
                          : null,
                      child: _SeatWidget(
                        seatId: seatId,
                        status: status,
                        isSpecial: isSpecial,
                        isSelected: isSelected,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedSeatId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConfirmScreen(
                            classroom: widget.classroom,
                            lessonName: widget.lessonName,
                            date: widget.date,
                            timeStart: widget.timeStart,
                            timeEnd: widget.timeEnd,
                            seatNumber: _selectedSeatId!,
                          ),
                        ),
                      ),
              child: Text(
                _selectedSeatId == null
                    ? 'Select a seat'
                    : 'Confirm seat $_selectedSeatId',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color bg, Color fg, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: fg),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Seat Widget ──────────────────────────────────────────────────────────────
class _SeatWidget extends StatelessWidget {
  final int seatId;
  final SeatStatus status;
  final bool isSpecial;
  final bool isSelected;

  const _SeatWidget({
    required this.seatId,
    required this.status,
    required this.isSpecial,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;

    if (isSelected) {
      bg = AppColors.blueLight;
      border = AppColors.blue;
      textColor = AppColors.blue;
    } else {
      switch (status) {
        case SeatStatus.free:
          bg = AppColors.greenLight;
          border = AppColors.green;
          textColor = AppColors.green;
        case SeatStatus.reserved:
          bg = AppColors.amberLight;
          border = AppColors.amber;
          textColor = AppColors.amber;
        case SeatStatus.occupied:
          bg = AppColors.redLight;
          border = AppColors.red;
          textColor = AppColors.red;
        case SeatStatus.regular:
          bg = AppColors.gray;
          border = AppColors.border;
          textColor = AppColors.textSecondary;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: isSelected ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSpecial ? '♿' : '🪑',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            '$seatId',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
