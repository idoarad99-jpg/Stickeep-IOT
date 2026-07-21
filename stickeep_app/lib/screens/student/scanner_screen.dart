import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:zxing2/qrcode.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';
import 'package:stickeep_app/utils/page_route.dart';

/// Decodes a QR code from a still photo. Used instead of a live camera
/// feed because Flutter Web has no way to drive manual/continuous
/// autofocus on the browser's camera stream — letting the student take a
/// photo hands focus control back to the phone's native camera app.
String? decodeQrFromPhotoBytes(Uint8List bytes) {
  final decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) return null;

  // RGBLuminanceSource reads red from bits 16-23, green from 8-15, blue
  // from 0-7 of each packed int (alpha ignored) — so the in-memory byte
  // order needs to be [B, G, R, A] for a little-endian Int32 read to line
  // up correctly. Using the wrong order here silently compresses the
  // black/white contrast range instead of failing outright, which matters
  // exactly in the marginal lighting conditions this feature targets.
  final source = RGBLuminanceSource(
    decodedImage.width,
    decodedImage.height,
    decodedImage
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.bgra)
        .buffer
        .asInt32List(),
  );

  try {
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

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
  late final Animation<double> _bounceY;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _manualCodeController = TextEditingController();

  bool _scanned = false;
  bool _isLoading = false;
  bool _showManualEntry = false;
  String? _captureError;
  String? _manualError;

  static const _bounceDuration = Duration(milliseconds: 600);

  static const _steps = [
    (1, 'Find the sticker on your reserved seat'),
    (2, 'Tap "Take photo of QR code" below'),
    (3, 'Point your camera at the QR and take the photo'),
    (4, 'Wait for confirmation — a dog will appear! 🐶'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _bounceDuration)
      ..repeat(reverse: true);
    _bounceY = Tween<double>(begin: 0, end: -14)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_scanned || _isLoading) return;

    setState(() => _captureError = null);

    XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _captureError =
          'Could not open the camera. Please allow camera access and try again.');
      return;
    }

    if (photo == null) return; // Student cancelled the camera.

    setState(() => _isLoading = true);

    final bytes = await photo.readAsBytes();
    final decoded = decodeQrFromPhotoBytes(bytes);

    if (!mounted) return;

    if (decoded == null) {
      setState(() {
        _isLoading = false;
        _captureError =
            'No QR code found in that photo. Get closer, hold steady, and try again.';
      });
      return;
    }

    if (decoded == widget.reservationId) {
      await _confirmArrival();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _captureError = "QR code doesn't match this reservation. Please try again.";
      });
    }
  }

  Future<void> _submitManualCode() async {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty || _isLoading) return;

    if (code == widget.reservationId) {
      setState(() => _manualError = null);
      await _confirmArrival();
    } else {
      setState(() => _manualError = "That code doesn't match this reservation.");
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

    HapticFeedback.mediumImpact();

    setState(() {
      _scanned = true;
      _isLoading = false;
    });
  }

  void _toggleManualEntry() {
    setState(() {
      _showManualEntry = !_showManualEntry;
      _manualError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Home',
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
                  : _CaptureBox(
                      key: const ValueKey('capture'),
                      isLoading: _isLoading,
                      errorMessage: _captureError,
                      onTakePhoto: _takePhoto,
                    ),
            ),
            if (!_scanned) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _toggleManualEntry,
                  child: Text(
                    _showManualEntry ? 'Hide manual entry' : 'Enter code manually',
                    style: TextStyle(fontSize: 12, color: AppColors.blue),
                  ),
                ),
              ),
              if (_showManualEntry)
                _ManualEntryBox(
                  controller: _manualCodeController,
                  errorMessage: _manualError,
                  isLoading: _isLoading,
                  onSubmit: _submitManualCode,
                ),
            ],
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

class _CaptureBox extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTakePhoto;

  const _CaptureBox({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 220,
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: isLoading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.blue),
                    const SizedBox(height: 12),
                    Text('Checking photo…',
                        style: TextStyle(
                            color: AppColors.whiteMuted, fontSize: 12)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        color: AppColors.whiteFaint, size: 40),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onTakePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('📷 Take photo of QR code'),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _ManualEntryBox extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _ManualEntryBox({
    required this.controller,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'Reservation code',
                hintText: 'Type the code from your reservation',
                errorText: errorMessage,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
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
          Text(
              studentName.isEmpty
                  ? 'Welcome to $classroom!'
                  : 'Welcome to $classroom, $studentName!',
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
