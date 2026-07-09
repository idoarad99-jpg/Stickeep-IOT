import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/cancel_reservation.dart';

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
    final count =
        await handleCancelChoice(context: context, uid: uid, r: reservation);
    if (count == 0) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(count == 1
                ? 'Reservation cancelled'
                : '$count reservations cancelled')),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
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
                          : StatusTag(
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
                  Divider(color: AppColors.border),
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
                  if (reservation.studentNumber.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Student ID',
                        value: reservation.studentNumber,
                        valueColor: AppColors.blue),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Status timeline', style: AppTextStyles.sectionTitle),
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
              icon: reservation.qrStatus == 'arrived' ||
                      reservation.nfcStatus == 'approved'
                  ? Icons.login_outlined
                  : Icons.schedule_outlined,
              color: reservation.qrStatus == 'arrived' ||
                      reservation.nfcStatus == 'approved'
                  ? AppColors.green
                  : AppColors.border,
              label: 'Arrived',
              sublabel: reservation.qrStatus == 'arrived' ||
                      reservation.nfcStatus == 'approved'
                  ? 'Confirmed'
                  : reservation.isUpcoming
                      ? 'Pending'
                      : 'Not confirmed',
              isLast: true,
            ),
            const SizedBox(height: 24),

            if (reservation.isUpcoming)
              OutlinedButton(
                onPressed: () => _cancel(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(color: AppColors.red),
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
                  style: TextStyle(
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
