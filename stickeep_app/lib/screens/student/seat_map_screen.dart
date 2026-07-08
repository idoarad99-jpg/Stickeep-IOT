import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/seat.dart';
import 'package:stickeep_app/screens/student/confirm_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class SeatMapScreen extends StatefulWidget {
  final String classroomId;
  final String classroomDisplayName;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;

  const SeatMapScreen({
    super.key,
    required this.classroomId,
    required this.classroomDisplayName,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
  });

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  String? _selectedSeatId;

  // Returns stream of status for a single seat — reads directly from the
  // seat document (seats/{seatId}). Detects TIME OVERLAP, not exact match.
  Stream<String> _seatStatusStream(String seatId) {
    return FirebaseFirestore.instance
        .collection('seats')
        .doc(seatId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 'free';
      final data = doc.data();
      if (data == null) return 'free';

      final docDate = data['date'] as String? ?? '';
      final docStart = data['startTime'] as String? ?? '';
      final docEnd = data['endTime'] as String? ?? '';
      final docStatus = data['status'] as String? ?? 'free';

      // Must be the same day.
      if (docDate != widget.date) return 'free';
      if (docStatus != 'reserved' && docStatus != 'occupied') return 'free';

      // Overlap check: two ranges [aStart,aEnd) and [bStart,bEnd) overlap
      // if aStart < bEnd AND bStart < aEnd.
      final overlaps =
          _timeToMinutes(docStart) < _timeToMinutes(widget.timeEnd) &&
              _timeToMinutes(widget.timeStart) < _timeToMinutes(docEnd);

      if (!overlaps) return 'free';
      return docStatus;
    });
  }

  Widget _buildTelemetryRow(String seatId) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('seats/$seatId').onValue,
      builder: (context, snap) {
        int? battery;
        int? lastSeenMs;
        if (snap.hasData && snap.data!.snapshot.exists) {
          final val = snap.data!.snapshot.value;
          if (val is Map) {
            battery = (val['batteryPercentage'] as num?)?.toInt();
            lastSeenMs = (val['lastSeen'] as num?)?.toInt();
          }
        }

        Color batteryColor;
        String batteryText;
        if (battery == null) {
          batteryColor = AppColors.textSecondary;
          batteryText = 'N/A';
        } else if (battery > 50) {
          batteryColor = AppColors.green;
          batteryText = '$battery%';
        } else if (battery >= 20) {
          batteryColor = const Color(0xFFF59E0B);
          batteryText = '$battery%';
        } else {
          batteryColor = AppColors.red;
          batteryText = '$battery%';
        }

        String lastSeenText;
        if (lastSeenMs == null) {
          lastSeenText = 'Never';
        } else {
          final diff = DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastSeenMs));
          if (diff.inMinutes < 1) {
            lastSeenText = 'Just now';
          } else if (diff.inHours < 1) {
            lastSeenText = '${diff.inMinutes} minutes ago';
          } else if (diff.inHours < 24) {
            lastSeenText = '${diff.inHours} hours ago';
          } else {
            lastSeenText = '${diff.inDays} days ago';
          }
        }

        return Row(
          children: [
            const Text('🔋', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(batteryText,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: batteryColor)),
            const SizedBox(width: 12),
            const Text('🕐', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(lastSeenText,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        );
      },
    );
  }

  // Converts "HH:MM" to total minutes for easy comparison.
  int _timeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classroomDisplayName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${widget.date}  •  ${widget.timeStart}–${widget.timeEnd}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Filtering 'active' client-side (rather than chaining
        // .where('active', ...).orderBy('order') server-side) avoids
        // needing a composite Firestore index for this tiny subcollection.
        stream: FirebaseFirestore.instance
            .collection('classrooms')
            .doc(widget.classroomId)
            .collection('seats')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Couldn\'t load seats: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.red, fontSize: 12),
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final seats = snapshot.data!.docs
              .map(ClassroomSeat.fromDoc)
              .where((s) => s.active)
              .toList();
          final selectedSeat = _selectedSeatId == null
              ? null
              : seats.cast<ClassroomSeat?>().firstWhere(
                  (s) => s!.seatId == _selectedSeatId,
                  orElse: () => null);

          return Column(
            children: [
              // ── Legend ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendItem(AppColors.greenLight, AppColors.green, 'Available'),
                    const SizedBox(width: 16),
                    _legendItem(AppColors.redLight, AppColors.red, 'Taken'),
                    const SizedBox(width: 16),
                    _legendItem(AppColors.blueLight, AppColors.blue, 'Selected'),
                  ],
                ),
              ),

              // ── Seat list ────────────────────────────────────────────────
              Expanded(
                child: seats.isEmpty
                    ? const Center(
                        child: Text(
                          'No seats set up in this room yet. Ask an admin to add one.',
                          style: AppTextStyles.cardSubtitle,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: seats.length,
                        itemBuilder: (context, index) {
                          final seat = seats[index];
                          final isSelected = _selectedSeatId == seat.seatId;

                          return StreamBuilder<String>(
                            stream: _seatStatusStream(seat.seatId),
                            builder: (context, statusSnap) {
                              final status = statusSnap.data ?? 'free';
                              final isTaken =
                                  status == 'reserved' || status == 'occupied';

                              Color bg;
                              Color border;
                              Color textColor;

                              if (isSelected) {
                                bg = AppColors.blueLight;
                                border = AppColors.blue;
                                textColor = AppColors.blue;
                              } else if (isTaken) {
                                bg = AppColors.redLight;
                                border = AppColors.red;
                                textColor = AppColors.red;
                              } else {
                                bg = AppColors.greenLight;
                                border = AppColors.green;
                                textColor = AppColors.green;
                              }

                              return GestureDetector(
                                onTap: isTaken
                                    ? null
                                    : () => setState(() {
                                          _selectedSeatId =
                                              isSelected ? null : seat.seatId;
                                        }),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: border, width: isSelected ? 2 : 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('♿', style: TextStyle(fontSize: 24)),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              seat.label.isEmpty
                                                  ? 'Seat ${seat.order}'
                                                  : seat.label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(
                                              seat.seatId,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildTelemetryRow(seat.seatId),
                                          ],
                                        ),
                                      ),
                                      if (isTaken)
                                        StatusTag.occupied()
                                      else if (isSelected)
                                        const StatusTag(
                                          label: 'Selected',
                                          backgroundColor: AppColors.blueLight,
                                          textColor: AppColors.blue,
                                        )
                                      else
                                        StatusTag.free(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),

              // ── Confirm button ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: selectedSeat == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConfirmScreen(
                                classroom: widget.classroomDisplayName,
                                classroomId: widget.classroomId,
                                lessonName: widget.lessonName,
                                date: widget.date,
                                timeStart: widget.timeStart,
                                timeEnd: widget.timeEnd,
                                seatId: selectedSeat.seatId,
                                seatNumber: selectedSeat.order,
                                seatLabel: selectedSeat.label,
                              ),
                            ),
                          );
                        },
                  child: Text(
                    selectedSeat == null
                        ? 'Select a seat'
                        : 'Confirm ${selectedSeat.label.isEmpty ? 'seat ${selectedSeat.order}' : selectedSeat.label}',
                  ),
                ),
              ),
            ],
          );
        },
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
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
