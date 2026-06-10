import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/student/success_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ConfirmScreen extends StatefulWidget {
  final String classroom;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final int seatNumber;
  final DatabaseReference seatsRef;

  const ConfirmScreen({
    super.key,
    required this.classroom,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatNumber,
    required this.seatsRef,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  bool _isLoading = false;

  Future<void> _confirm() async {
    setState(() => _isLoading = true);
    await widget.seatsRef
        .child('seat_${widget.seatNumber}')
        .update({'status': 'reserved'});
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SuccessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = '${widget.timeStart}–${widget.timeEnd}';
    final lesson =
        widget.lessonName.isEmpty ? '—' : widget.lessonName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        title: const Text('Confirm reservation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Checkmark icon ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 24,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Heading ──────────────────────────────────────────────────────
            const Text(
              'Almost done!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please review your reservation',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Summary card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Classroom', value: widget.classroom),
                  _InfoRow(label: 'Lesson', value: lesson),
                  _InfoRow(label: 'Date', value: widget.date),
                  _InfoRow(label: 'Time', value: time),
                  _InfoRow(
                    label: 'Seat',
                    value: '${widget.seatNumber}',
                    valueColor: AppColors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Confirm button ───────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isLoading ? null : _confirm,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm reservation'),
            ),
            const SizedBox(height: 12),

            // ── Edit button ──────────────────────────────────────────────────
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('✏️  Edit — back to step 4'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
