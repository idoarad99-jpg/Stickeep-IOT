import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                Text(reservation.classroom, style: AppTextStyles.cardTitle),
                reservation.isUpcoming
                    ? StatusTag.reserved()
                    : const StatusTag(
                        label: 'Past',
                        backgroundColor: AppColors.gray,
                        textColor: AppColors.textSecondary,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            if (reservation.lessonName.isNotEmpty) ...[
              Text(reservation.lessonName, style: AppTextStyles.cardSubtitle),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(reservation.date, style: AppTextStyles.label),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${reservation.timeStart}–${reservation.timeEnd}',
                    style: AppTextStyles.label),
                const SizedBox(width: 12),
                const Icon(Icons.chair_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Seat ${reservation.seatNumber}',
                    style: AppTextStyles.label),
              ],
            ),
            if (reservation.isUpcoming && onCancel != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onCancel,
                child: const Text(
                  'Cancel reservation',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
