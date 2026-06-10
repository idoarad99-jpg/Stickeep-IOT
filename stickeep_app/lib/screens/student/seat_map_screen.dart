import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/seat.dart';
import 'package:stickeep_app/screens/student/confirm_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';
import 'package:stickeep_app/utils/seat_id.dart';

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
  Map<int, SeatStatus> _seatStatuses = {};
  Map<int, SeatStatus> _firestoreSeatStatuses = {};
  final Set<int> _specialSeats = {1, 2, 3, 4};
  late final DatabaseReference _seatsRef;
  StreamSubscription<QuerySnapshot>? _fsSubscription;

  @override
  void initState() {
    super.initState();
    final classroom = widget.classroom.replaceAll(' ', '_').toLowerCase();
    _seatsRef = FirebaseDatabase.instance.ref('classrooms/$classroom/seats');
    _initSeats();
    _listenFirestoreSeats();
  }

  void _listenFirestoreSeats() {
    final ids = seatIdsForClassroom(widget.classroom);
    if (ids.isEmpty) return;
    _fsSubscription = FirebaseFirestore.instance
        .collection('seats')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .listen((snap) {
      final updated = <int, SeatStatus>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final seatNumber = int.tryParse(doc.id.split('_').last) ?? 0;
        if (seatNumber == 0) continue;
        if (data['date'] == widget.date &&
            data['startTime'] == widget.timeStart &&
            data['endTime'] == widget.timeEnd) {
          final s = data['status'] as String? ?? 'free';
          updated[seatNumber] = s == 'occupied'
              ? SeatStatus.occupied
              : s == 'reserved'
                  ? SeatStatus.reserved
                  : SeatStatus.free;
        }
        // Date/time doesn't match → seat is free for this slot
      }
      if (mounted) setState(() => _firestoreSeatStatuses = updated);
    });
  }

  @override
  void dispose() {
    _fsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initSeats() async {
    final snapshot = await _seatsRef.get();
    if (!snapshot.exists) {
      final Map<String, dynamic> initial = {};
      for (int i = 1; i <= 20; i++) {
        initial['seat_$i'] = {
          'status': 'free',
          'is_special': _specialSeats.contains(i),
        };
      }
      await _seatsRef.set(initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),
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
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _seatsRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData &&
                    snapshot.data!.snapshot.value != null) {
                  final raw = snapshot.data!.snapshot.value
                      as Map<dynamic, dynamic>;
                  _seatStatuses = {};
                  raw.forEach((key, value) {
                    final id = int.tryParse(
                        key.toString().replaceAll('seat_', ''));
                    if (id != null) {
                      _seatStatuses[id] =
                          Seat.fromJson(id, value as Map<dynamic, dynamic>)
                              .status;
                    }
                  });
                }
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
                    // Sticker seats (1–4): use Firestore with date+time filter.
                    // Regular seats (5–20): use RTDB status.
                    final status = _specialSeats.contains(seatId)
                        ? (_firestoreSeatStatuses[seatId] ?? SeatStatus.free)
                        : (_seatStatuses[seatId] ?? SeatStatus.free);
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
                            seatsRef: _seatsRef,
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
          Text(isSpecial ? '♿' : '🪑',
              style: const TextStyle(fontSize: 18)),
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
