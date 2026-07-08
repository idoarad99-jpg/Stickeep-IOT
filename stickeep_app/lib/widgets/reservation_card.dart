import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';

enum ReservationDisplayStatus { reserved, past, cancelled }

class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onShowQr;
  final VoidCallback? onScanArrival;
  final ReservationDisplayStatus displayStatus;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
    this.onCancel,
    this.onShowQr,
    this.onScanArrival,
    this.displayStatus = ReservationDisplayStatus.reserved,
  });

  Widget _statusTag() {
    switch (displayStatus) {
      case ReservationDisplayStatus.reserved:
        return StatusTag.reserved();
      case ReservationDisplayStatus.past:
        return const StatusTag(
          label: 'Past',
          backgroundColor: AppColors.gray,
          textColor: AppColors.textSecondary,
        );
      case ReservationDisplayStatus.cancelled:
        return const StatusTag(
          label: 'Cancelled',
          backgroundColor: AppColors.redLight,
          textColor: AppColors.red,
        );
    }
  }

  Widget _nfcBadge() {
    switch (reservation.nfcStatus) {
      case 'approved':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('✓ Checked in',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
        );
      case 'declined':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('✗ Access denied',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.red)),
        );
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('⏳ Awaiting scan',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _nfcBadgeLive() {
    final ref = FirebaseDatabase.instance
        .ref('reservations/${reservation.studentId}/${reservation.id}/nfc_status');
    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        final status = snapshot.hasData
            ? snapshot.data!.snapshot.value as String?
            : null;
        switch (status) {
          case 'approved':
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('NFC ✓',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green)),
            );
          case 'declined':
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('NFC ✗',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.red)),
            );
          default:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('NFC pending',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280))),
            );
        }
      },
    );
  }

  Widget _qrBadge() {
    if (reservation.qrStatus == 'arrived') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('✓ Arrived',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
      );
    }
    return const SizedBox.shrink();
  }

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
                _statusTag(),
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
            if (reservation.studentNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.badge_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('ID ${reservation.studentNumber}',
                      style: AppTextStyles.label),
                ],
              ),
            ],
            const SizedBox(height: 6),
            _nfcBadgeLive(),
            if (reservation.qrStatus.isNotEmpty) ...[const SizedBox(height: 4), _qrBadge()],
            if (displayStatus == ReservationDisplayStatus.reserved &&
                (onCancel != null || onShowQr != null)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onScanArrival != null)
                    GestureDetector(
                      onTap: onScanArrival,
                      child: const Text(
                        '📷 Scan on arrival',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (onShowQr != null)
                    GestureDetector(
                      onTap: onShowQr,
                      child: const Text(
                        '📱 Show QR code',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (onCancel != null)
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
