import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/student/reservations_screen.dart';
import 'package:stickeep_app/screens/student/scanner_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/page_route.dart';

class SuccessScreen extends StatefulWidget {
  final String email;
  final String classroom;
  final String seat;
  final String date;
  final String lesson;
  final String time;
  final String reservationId;
  final String studentName;
  final String studentNumber;
  final String? recurrenceSummary;

  const SuccessScreen({
    super.key,
    required this.email,
    required this.classroom,
    required this.seat,
    required this.date,
    required this.lesson,
    required this.time,
    required this.reservationId,
    required this.studentName,
    this.studentNumber = '',
    this.recurrenceSummary,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonDisplay = widget.lesson.isEmpty ? '—' : widget.lesson;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        automaticallyImplyLeading: false,
        title: const Text('Confirmed! 🎉'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Green checkmark ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 26,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Bouncing dog ─────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: child,
              ),
              child: const Text(
                '🐶',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 16),

            // ── Heading ──────────────────────────────────────────────────────
            Text(
              "You're all set!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Info card ────────────────────────────────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email row
                  Row(
                    children: [
                      Icon(Icons.email,
                          size: 14, color: AppColors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Email sent to',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),

                  // Classroom + seat / Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.classroom}  •  Seat ${widget.seat}',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                      Text(
                        widget.date,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Lesson / Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lessonDisplay,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                      Text(
                        widget.time,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (widget.studentNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 13, color: AppColors.blue),
                        const SizedBox(width: 5),
                        Text(
                          'Student ID: ${widget.studentNumber}',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.recurrenceSummary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.repeat, size: 16, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.recurrenceSummary!,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Scan on arrival ──────────────────────────────────────────────
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                AppPageRoute(
                  builder: (_) => ScannerScreen(
                    classroom: widget.classroom,
                    studentName: widget.studentName,
                    reservationId: widget.reservationId,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('📲  Scan on arrival'),
            ),
            const SizedBox(height: 12),

            // ── View my reservations ─────────────────────────────────────────
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                AppPageRoute(builder: (_) => const ReservationsScreen()),
              ),
              child: const Text('View my reservations'),
            ),
            const SizedBox(height: 12),

            // ── Back to home ─────────────────────────────────────────────────
            OutlinedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
