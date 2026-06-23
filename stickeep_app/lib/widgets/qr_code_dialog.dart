import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stickeep_app/theme/app_theme.dart';

void showQrDialog(
  BuildContext context, {
  required String reservationId,
  required String classroom,
  required String seat,
  required String date,
  required String time,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text(
        'Scan to confirm arrival',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: reservationId,
            size: 200,
          ),
          const SizedBox(height: 12),
          Text(
            '$classroom  •  Seat $seat',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '$date  •  $time',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
