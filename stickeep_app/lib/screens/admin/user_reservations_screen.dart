import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/cancel_reservation.dart';
import 'package:stickeep_app/widgets/reservation_card.dart';

class UserReservationsScreen extends StatefulWidget {
  final String uid;
  final String userName;

  const UserReservationsScreen({
    super.key,
    required this.uid,
    required this.userName,
  });

  @override
  State<UserReservationsScreen> createState() => _UserReservationsScreenState();
}

class _UserReservationsScreenState extends State<UserReservationsScreen> {
  bool _showUpcoming = true;
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

  Future<void> _confirmAndCancel(Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this reservation?'),
        content: Text(
          'This will cancel ${widget.userName}\'s reservation for '
          '${r.classroom} on ${r.date} (${r.timeStart}–${r.timeEnd}).',
        ),
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

    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    await cancelReservation(
      uid: widget.uid,
      r: r,
      cancelledByAdminUid: adminUid,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled ${widget.userName}\'s reservation'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('reservations/${widget.uid}');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: Text("${widget.userName}'s reservations"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Upcoming'),
                  selected: _showUpcoming,
                  onSelected: (val) => setState(() => _showUpcoming = val),
                  selectedColor: AppColors.greenLight,
                  checkmarkColor: AppColors.green,
                ),
                FilterChip(
                  label: const Text('Past'),
                  selected: _showPast,
                  onSelected: (val) => setState(() => _showPast = val),
                  selectedColor: AppColors.blueLight,
                  checkmarkColor: AppColors.blue,
                ),
                FilterChip(
                  label: const Text('Cancelled'),
                  selected: _showCancelled,
                  onSelected: (val) => setState(() => _showCancelled = val),
                  selectedColor: AppColors.redLight,
                  checkmarkColor: AppColors.red,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text('No reservations',
                        style: AppTextStyles.cardSubtitle),
                  );
                }

                final raw =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);

                final all = raw.entries
                    .map((e) => Reservation.fromJson(
                        e.key.toString(), e.value as Map<dynamic, dynamic>))
                    .toList();

                final filtered = all.where((r) {
                  final d = _parseDate(r.date);
                  final isPast = d != null && d.isBefore(todayDate);
                  final isCancelled = !r.isUpcoming && !isPast;
                  final isUpcomingNow = r.isUpcoming && !isPast;

                  if (isUpcomingNow) return _showUpcoming;
                  if (isCancelled) return _showCancelled;
                  if (isPast) return _showPast;
                  return false;
                }).toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No reservations match the filters',
                        style: AppTextStyles.cardSubtitle),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final d = _parseDate(r.date);
                    final isPast = d != null && d.isBefore(todayDate);
                    final isUpcomingNow = r.isUpcoming && !isPast;
                    final displayStatus = !r.isUpcoming && !isPast
                        ? ReservationDisplayStatus.cancelled
                        : isPast
                            ? ReservationDisplayStatus.past
                            : ReservationDisplayStatus.reserved;

                    return ReservationCard(
                      reservation: r,
                      displayStatus: displayStatus,
                      onCancel:
                          isUpcomingNow ? () => _confirmAndCancel(r) : null,
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
}
