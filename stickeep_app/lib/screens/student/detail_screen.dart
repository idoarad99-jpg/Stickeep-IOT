import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class DetailScreen extends StatelessWidget {
  final Reservation reservation;
  final String reservationId;
  final String uid;

  const DetailScreen({
    super.key,
    required this.reservation,
    required this.reservationId,
    required this.uid,
  });

  Future<void> _cancel(BuildContext context) async {
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

    await FirebaseFirestore.instance.collection('graveyard').add({
      'student_id': uid,
      'classroom': reservation.classroom,
      'lesson_name': reservation.lessonName,
      'date': reservation.date,
      'time_start': reservation.timeStart,
      'time_end': reservation.timeEnd,
      'seat_number': reservation.seatNumber,
      'seat_id': reservation.seatId,
      'original_reservation_id': reservationId,
      'cancelled_at': FieldValue.serverTimestamp(),
    });

    // 1. RTDB — mark as not upcoming
    await FirebaseDatabase.instance
        .ref('reservations/$uid/$reservationId')
        .update({'is_upcoming': false});

    // 2. Firestore seat — clear if exists
    final seatId = reservation.seatId;
    if (seatId != null && seatId.isNotEmpty) {
      final seatRef =
          FirebaseFirestore.instance.collection('seats').doc(seatId);
      final seatSnap = await seatRef.get();
      if (seatSnap.exists) {
        final data = seatSnap.data();
        if (data != null && data['reservationId'] == reservationId) {
          await seatRef.update({'status': 'free'});
          // Data is already archived in graveyard — delete the live
          // copy instead of just flagging it as cancelled.
          await seatRef
              .collection('reservations')
              .doc(reservationId)
              .delete();
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = '${reservation.timeStart}–${reservation.timeEnd}';

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary card ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(reservation.classroom,
                          style: AppTextStyles.cardTitle),
                      reservation.isUpcoming
                          ? StatusTag.reserved()
                          : const StatusTag(
                              label: 'Past',
                              backgroundColor: AppColors.gray,
                              textColor: AppColors.textSecondary,
                            ),
                    ],
                  ),
                  if (reservation.lessonName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(reservation.lessonName,
                        style: AppTextStyles.cardSubtitle),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: reservation.date),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: time),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.chair_outlined,
                      label: 'Seat',
                      value: 'Seat ${reservation.seatNumber}',
                      valueColor: AppColors.blue),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Timeline ─────────────────────────────────────────────────────
            const Text('Status timeline', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _TimelineStep(
              icon: Icons.check_circle_outline,
              color: AppColors.green,
              label: 'Booked',
              sublabel: reservation.date,
              isLast: false,
            ),
            _TimelineStep(
              icon: Icons.event_available_outlined,
              color: AppColors.blue,
              label: 'Seat Reserved',
              sublabel:
                  '${reservation.classroom} · Seat ${reservation.seatNumber}',
              isLast: false,
            ),
            _TimelineStep(
              icon: reservation.isUpcoming
                  ? Icons.schedule_outlined
                  : Icons.login_outlined,
              color:
                  reservation.isUpcoming ? AppColors.border : AppColors.green,
              label: 'Arrived',
              sublabel: reservation.isUpcoming ? 'Pending' : 'Confirmed',
              isLast: true,
            ),
            const SizedBox(height: 24),

            // ── Cancel button ────────────────────────────────────────────────
            if (reservation.isUpcoming)
              OutlinedButton(
                onPressed: () => _cancel(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                ),
                child: const Text('Cancel reservation'),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.label),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            )),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final bool isLast;

  const _TimelineStep({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              Text(sublabel, style: AppTextStyles.label),
            ],
          ),
        ),
      ],
    );
  }
}
