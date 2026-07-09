import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';
import 'package:stickeep_app/utils/page_route.dart';

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
  late Animation<double> _scanLineY;
  late Animation<double> _bounceY;
  late final MobileScannerController _cameraController;

  bool _scanned = false;
  bool _isLoading = false;
  bool _cameraReady = false;
  bool _cameraError = false;
  Timer? _cameraTimeout;

  static const _scanDuration = Duration(milliseconds: 1400);
  static const _bounceDuration = Duration(milliseconds: 600);
  static const _cameraErrorMessage =
      'Camera failed to start. Please check camera permissions and refresh.';

  static const _steps = [
    (1, 'Find the sticker on your reserved seat'),
    (2, 'Hold your phone 15–20cm from the barcode'),
    (3, 'Keep steady until camera locks on'),
    (4, 'Wait for confirmation — a dog will appear! 🐶'),
  ];

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController();
    _controller = AnimationController(vsync: this, duration: _scanDuration)
      ..repeat(reverse: true);
    _buildAnimations();
    _startCamera();
  }

  Future<void> _startCamera() async {
    _cameraTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted && !_cameraReady) setState(() => _cameraError = true);
    });
    try {
      await _cameraController.start();
      _cameraTimeout?.cancel();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      _cameraTimeout?.cancel();
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _buildAnimations() {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scanLineY = Tween<double>(begin: 12, end: 180).animate(curve);
    _bounceY = Tween<double>(begin: 0, end: -14).animate(curve);
  }

  @override
  void dispose() {
    _cameraTimeout?.cancel();
    _cameraController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_scanned || _isLoading) return;
    final value = capture.barcodes.first.rawValue ?? '';
    if (value.isEmpty) return;
    if (value == widget.reservationId) {
      _confirmArrival();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("QR code doesn't match. Please try again."),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _confirmArrival() async {
    setState(() => _isLoading = true);

    try {
      // Update Firestore
      final docRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId);
      await docRef.update({'status': 'arrived'});

      // Update RTDB qr_status — scoped to the signed-in user's own
      // reservations, since arrival is always confirmed by the reservation
      // owner scanning their own sticker.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userRef = FirebaseDatabase.instance.ref('reservations/$uid');
        final snapshot = await userRef.get();
        if (snapshot.exists) {
          final userReservations = snapshot.value as Map<dynamic, dynamic>;
          for (final resEntry in userReservations.entries) {
            final resData = resEntry.value as Map<dynamic, dynamic>;
            if ((resData['qr_token'] as String? ?? '') == widget.reservationId) {
              await userRef
                  .child(resEntry.key as String)
                  .update({'qr_status': 'arrived'});
              break;
            }
          }
        }
      }

      // Update seat status
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        final seatId = data['seatId'] as String?;
        if (seatId != null && seatId.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref('seats/$seatId')
              .update({'status': 'occupied'});
          final seatDocRef =
              FirebaseFirestore.instance.collection('seats').doc(seatId);
          await seatDocRef.update({
            'status': 'occupied',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await seatDocRef
              .collection('reservations')
              .doc(widget.reservationId)
              .update({'status': 'occupied'});
        }
      }
    } catch (e) {
    }

    if (!mounted) return;

    _cameraController.stop();
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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            AppPageRoute(
                builder: (_) =>
                    const HomeScreen(userName: '', userRole: '')),
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
                      onDetect: _onQrDetect,
                      controller: _cameraController,
                      cameraReady: _cameraReady,
                      cameraError: _cameraError,
                    ),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to scan:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._steps.map((s) => _StepRow(number: s.$1, text: s.$2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerBox extends StatelessWidget {
  final Animation<double> scanLineY;
  final void Function(BarcodeCapture) onDetect;
  final MobileScannerController controller;
  final bool cameraReady;
  final bool cameraError;

  const _ScannerBox({
    super.key,
    required this.scanLineY,
    required this.onDetect,
    required this.controller,
    required this.cameraReady,
    required this.cameraError,
  });

  @override
  Widget build(BuildContext context) {
    if (cameraError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              _ScannerScreenState._cameraErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: scanLineY,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 200,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: onDetect,
                  errorBuilder: (context, error, child) {
                    return ColoredBox(
                      color: const Color(0xFF1A1A1A),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.no_photography_outlined,
                                  color: Colors.white54, size: 36),
                              const SizedBox(height: 10),
                              Text(
                                'Camera error: ${error.errorCode.name}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Allow camera access in browser\nthen refresh the page.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (!cameraReady)
                  Container(
                    color: const Color(0xFF1A1A1A),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.blue),
                          const SizedBox(height: 12),
                          const Text('Starting camera…',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                _Corner(top: 8, left: 8, showTop: true, showLeft: true),
                _Corner(top: 8, right: 8, showTop: true, showRight: true),
                _Corner(bottom: 8, left: 8, showBottom: true, showLeft: true),
                _Corner(bottom: 8, right: 8, showBottom: true, showRight: true),
                if (cameraReady)
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Corner extends StatelessWidget {
  final double? top, left, right, bottom;
  final bool showTop, showBottom, showLeft, showRight;

  const _Corner({
    this.top, this.left, this.right, this.bottom,
    this.showTop = false, this.showBottom = false,
    this.showLeft = false, this.showRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: AppColors.blue, width: 2);
    const none = BorderSide.none;
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
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
            child: const Text('🐶',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 8),
          Text('Arrival confirmed!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
          const SizedBox(height: 4),
          Text('Welcome to $classroom, $studentName!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF639922))),
        ],
      ),
    );
  }
}

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
            width: 20, height: 20,
            decoration: BoxDecoration(
                color: AppColors.blue, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
