import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:stickeep_app/screens/auth/login_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCjbSPVQlYr1h6z1NpsXRMQppizFI392og',
      appId: '1:533886545260:web:05d58c3e975ee7ee439749',
      messagingSenderId: '533886545260',
      projectId: 'stickeep',
      storageBucket: 'stickeep.firebasestorage.app',
      databaseURL: 'https://stickeep-default-rtdb.firebaseio.com',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickeep',
      theme: AppTheme.theme,
      home: const FirebaseTestScreen(),
    );
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen>
    with TickerProviderStateMixin {
  // ── Firebase (unchanged) ──────────────────────────────────────────────────
  final DatabaseReference _statusRef =
      FirebaseDatabase.instance.ref('chair_status');
  String _currentStatus = 'Loading...';

  // ── Pulse animation ───────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _activateStatusListener();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _activateStatusListener() {
    _statusRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      print('--- [Firebase Update] chair_status current value is: $data ---');
      setState(() {
        _currentStatus = data?.toString() ?? 'No data';
      });
    }, onError: (error) {
      print('Error listening to database: $error');
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isFree = _currentStatus.toLowerCase() == 'free';
    final statusColor = isFree ? AppColors.green : AppColors.red;
    final statusBg = isFree ? AppColors.greenLight : AppColors.redLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stickeep'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chair Status', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _currentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── New Reservation ─────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('New Reservation'),
            ),
            const SizedBox(height: 10),

            // ── My Reservations ─────────────────────────────────────────────
            OutlinedButton(
              onPressed: () {},
              child: const Text('My Reservations'),
            ),
            const SizedBox(height: 10),

            // ── Go to Login Screen ──────────────────────────────────────────
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.blue),
              ),
              child: const Text('Go to Login Screen'),
            ),
          ],
        ),
      ),
    );
  }
}
