import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';

class ScannerScreen extends StatefulWidget {
  final String classroom;
  final String studentName;
  final String reservationId;

  const ScannerScreen({
    super.key,
    required this.classroom,
    required this.studentName,
    required this.reservationId,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Scan line moves top→bottom inside the dark box.
  // Bounce drives the dog emoji after success.
  // Both share the same controller — scan line runs before scan,
  // bounce runs after (controller is reset with a shorter duration).
  late Animation<double> _scanLineY;
  late Animation<double> _bounceY;

  bool _scanned = false;
  bool _isLoading = false;

  static const _scanDuration = Duration(milliseconds: 1400);
  static const _bounceDuration = Duration(milliseconds: 600);

  static const _steps = [
    (1, 'Find the sticker on your reserved seat'),
    (2, 'Hold your phone 15–20cm from the barcode'),
    (3, 'Keep steady until camera locks on'),
    (4, 'Wait for confirmation — a dog will appear! 🐶'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _scanDuration)
      ..repeat(reverse: true);
    _buildAnimations();
  }

  void _buildAnimations() {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    // Scan line travels between y=12 and y=132 inside the 160-height box.
    _scanLineY = Tween<double>(begin: 12, end: 132).animate(curve);
    _bounceY = Tween<double>(begin: 0, end: -14).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _simulateScan() async {
    setState(() => _isLoading = true);

    try {
      // Mark the Firestore reservation as arrived.
      final docRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId);
      await docRef.update({'status': 'arrived'});

      // Fetch seatNumber from the reservation to update RTDB seat status.
      final doc = await docRef.get();
      if (doc.exists) {
        final seatNumber = doc.data()?['seatNumber'];
        if (seatNumber != null) {
          final classroomKey =
              widget.classroom.replaceAll(' ', '_').toLowerCase();
          await FirebaseDatabase.instance
              .ref('classrooms/$classroomKey/seats/seat_$seatNumber')
              .update({'status': 'occupied'});
        }
      }
    } catch (_) {
      // Show success UI regardless — scan simulation should not block UX.
    }

    if (!mounted) return;

    // Switch controller to bounce speed before showing success box.
    _controller.stop();
    _controller.duration = _bounceDuration;
    _buildAnimations();
    _controller.repeat(reverse: true);

    setState(() {
      _scanned = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),
        backgroundColor: AppColors.blue,
        title: const Text('Scan sticker'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Scanner box / Success box ─────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _scanned
                  ? _SuccessBox(
                      key: const ValueKey('success'),
                      bounceY: _bounceY,
                      classroom: widget.classroom,
                      studentName: widget.studentName,
                    )
                  : _ScannerBox(
                      key: const ValueKey('scanner'),
                      scanLineY: _scanLineY,
                    ),
            ),

            const SizedBox(height: 24),

            // ── How to scan ──────────────────────────────────────────────────
            const Text(
              'How to scan:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._steps.map((s) => _StepRow(number: s.$1, text: s.$2)),

            const SizedBox(height: 24),

            // ── Simulate button (hidden after scan) ──────────────────────────
            if (!_scanned)
              ElevatedButton(
                onPressed: _isLoading ? null : _simulateScan,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simulate successful scan'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Scanner box ──────────────────────────────────────────────────────────────
class _ScannerBox extends StatelessWidget {
  final Animation<double> scanLineY;

  const _ScannerBox({super.key, required this.scanLineY});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scanLineY,
      builder: (context, _) {
        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Corner brackets
              _Corner(top: 8, left: 8, showTop: true, showLeft: true),
              _Corner(top: 8, right: 8, showTop: true, showRight: true),
              _Corner(bottom: 8, left: 8, showBottom: true, showLeft: true),
              _Corner(bottom: 8, right: 8, showBottom: true, showRight: true),

              // Animated scan line (80% width, centered)
              Positioned(
                top: scanLineY.value,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.8,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Barcode icon centered
              const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Corner bracket ───────────────────────────────────────────────────────────
class _Corner extends StatelessWidget {
  final double? top, left, right, bottom;
  final bool showTop, showBottom, showLeft, showRight;

  const _Corner({
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.showTop = false,
    this.showBottom = false,
    this.showLeft = false,
    this.showRight = false,
  });

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.blue, width: 2);
    const none = BorderSide.none;
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          border: Border(
            top: showTop ? side : none,
            bottom: showBottom ? side : none,
            left: showLeft ? side : none,
            right: showRight ? side : none,
          ),
        ),
      ),
    );
  }
}

// ── Success box ──────────────────────────────────────────────────────────────
class _SuccessBox extends StatelessWidget {
  final Animation<double> bounceY;
  final String classroom;
  final String studentName;

  const _SuccessBox({
    super.key,
    required this.bounceY,
    required this.classroom,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: bounceY,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, bounceY.value),
              child: child,
            ),
            child: const Text(
              '🐶',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Arrival confirmed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to $classroom, $studentName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF639922),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step row ─────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final int number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
