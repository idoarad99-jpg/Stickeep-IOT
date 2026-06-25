import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/seat_id.dart';
import 'package:stickeep_app/widgets/reservation_card.dart';
import 'package:stickeep_app/widgets/qr_code_dialog.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';

class ReservationsScreen extends StatefulWidget {
  final bool showUpcoming;

  const ReservationsScreen({super.key, this.showUpcoming = true});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  // History-tab filters. Both on by default (show everything).
  bool _showPast = true;
  bool _showCancelled = true;

  DateTime? _parseDate(String d) {
    final parts = d.split('.');
    if (parts.length != 3) return null;
    return DateTime(
      int.tryParse(parts[2]) ?? 2000,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[0]) ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final ref = FirebaseDatabase.instance.ref('reservations/$uid');
    final showUpcoming = widget.showUpcoming;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),
        title: Text(showUpcoming ? 'My Reservations' : 'Reservation History'),
      ),
      body: Column(
        children: [
          if (!showUpcoming) _buildFilterChips(),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _emptyState(showUpcoming);
                }

                final raw =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);

                final all = raw.entries
                    .map((e) => Reservation.fromJson(
                        e.key.toString(), e.value as Map<dynamic, dynamic>))
                    .toList();

                List<Reservation> reservations;

                if (showUpcoming) {
                  // Upcoming tab: never cancelled, never past.
                  reservations = all.where((r) {
                    final d = _parseDate(r.date);
                    final isPast = d != null && d.isBefore(todayDate);
                    return r.isUpcoming && !isPast;
                  }).toList();
                } else {
                  // History tab: cancelled OR past, filtered by the chips.
                  reservations = all.where((r) {
                    final d = _parseDate(r.date);
                    final isPast = d != null && d.isBefore(todayDate);
                    final isCancelled = !r.isUpcoming && !isPast;

                    if (isCancelled && !_showCancelled) return false;
                    if (isPast && !_showPast) return false;
                    return isCancelled || isPast;
                  }).toList();
                }

                reservations.sort((a, b) => b.date.compareTo(a.date));

                if (reservations.isEmpty) return _emptyState(showUpcoming);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final r = reservations[index];
                    final d = _parseDate(r.date);
                    final isPast = d != null && d.isBefore(todayDate);
                    final displayStatus = !r.isUpcoming && !isPast
                        ? ReservationDisplayStatus.cancelled
                        : isPast
                            ? ReservationDisplayStatus.past
                            : ReservationDisplayStatus.reserved;

                    return ReservationCard(
                      reservation: r,
                      displayStatus: displayStatus,
                      onCancel: showUpcoming
                          ? () => _cancelReservation(context, uid, r)
                          : null,
                      onShowQr: (r.isUpcoming &&
                              r.qrToken != null &&
                              r.qrToken!.isNotEmpty)
                          ? () => showQrDialog(
                                context,
                                reservationId: r.qrToken!,
                                classroom: r.classroom,
                                seat: r.seatNumber.toString(),
                                date: r.date,
                                time: '${r.timeStart}–${r.timeEnd}',
                              )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Past'),
            selected: _showPast,
            onSelected: (val) => setState(() => _showPast = val),
            selectedColor: AppColors.blueLight,
            checkmarkColor: AppColors.blue,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Cancelled'),
            selected: _showCancelled,
            onSelected: (val) => setState(() => _showCancelled = val),
            selectedColor: AppColors.redLight,
            checkmarkColor: AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool showUpcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            showUpcoming ? 'No upcoming reservations' : 'No reservations to show',
            style: AppTextStyles.cardSubtitle,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(
      BuildContext context, String uid, Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Move to the graveyard collection (Firestore archive) before
    // wiping the live record, so admins can still see it later.
    await FirebaseFirestore.instance.collection('graveyard').add({
      'student_id': uid,
      'classroom': r.classroom,
      'lesson_name': r.lessonName,
      'date': r.date,
      'time_start': r.timeStart,
      'time_end': r.timeEnd,
      'seat_number': r.seatNumber,
      'seat_id': r.seatId,
      'original_reservation_id': r.id,
      'cancelled_at': FieldValue.serverTimestamp(),
    });

    await FirebaseDatabase.instance
        .ref('reservations/$uid/${r.id}')
        .update({'is_upcoming': false});

    // Clear the Firestore seats document for this reservation
    final seatId = seatIdFromClassroom(r.classroom, r.seatNumber);
    if (seatId != null) {
      final seatDocRef =
          FirebaseFirestore.instance.collection('seats').doc(seatId);
      final seatDoc = await seatDocRef.get();
      if (seatDoc.exists) {
        final data = seatDoc.data()!;
        if (data['date'] == r.date &&
            data['startTime'] == r.timeStart &&
            data['endTime'] == r.timeEnd) {
          final fsReservationId = data['reservationId'] as String?;
          await seatDocRef.update({
            'status': 'free',
            'studentNumber': '',
            'startTime': '',
            'endTime': '',
            'date': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (fsReservationId != null) {
            // Data is already archived in graveyard — delete the live
            // copies instead of just flagging them as cancelled.
            await seatDocRef
                .collection('reservations')
                .doc(fsReservationId)
                .delete();
            await FirebaseFirestore.instance
                .collection('reservations')
                .doc(fsReservationId)
                .delete();
          }
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled')),
      );
    }
  }
}
