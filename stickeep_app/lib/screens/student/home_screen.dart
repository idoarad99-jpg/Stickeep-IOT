import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/admin_home_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/classroom_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _userName;
  late String _userRole;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userRole = widget.userRole;

    if (_userName.isEmpty || _userRole.isEmpty) {
      _fetchProfileFromFirestore();
    }
  }

  Future<void> _fetchProfileFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('students').doc(uid).get();

    if (!mounted || !doc.exists) return;

    final data = doc.data()!;
    setState(() {
      if (_userName.isEmpty) {
        _userName = data['name'] as String? ?? 'User';
      }
      if (_userRole.isEmpty) {
        _userRole = data['role'] as String? ?? 'student';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole.toLowerCase() == 'admin';
    final displayName = _userName.isEmpty ? 'User' : _userName;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        automaticallyImplyLeading: false,
        title: Text(
          'Hi, $displayName 👋',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Next reservation card ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Next reservation',
                      style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'No upcoming reservations',
                        style: AppTextStyles.cardSubtitle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section title ────────────────────────────────────────────────
            const Text(
              'What would you like to do?',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 12),

            // ── New reservation ──────────────────────────────────────────────
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassroomScreen()),
              ),
              child: const Text('🪑  New reservation'),
            ),
            const SizedBox(height: 10),

            // ── My reservations ──────────────────────────────────────────────
            OutlinedButton(
              onPressed: () {},
              child: const Text('📅  My reservations'),
            ),
            const SizedBox(height: 10),

            // ── Reservation history ──────────────────────────────────────────
            OutlinedButton(
              onPressed: () {},
              child: const Text('🕐  Reservation history'),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),

            // ── Admin Panel (only for admins) ────────────────────────────────
            if (isAdmin) ...[
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3C3489),
                  side: const BorderSide(color: Color(0xFF3C3489)),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('🔐  Admin Panel'),
              ),
              const SizedBox(height: 10),
            ],

            // ── Report an issue ──────────────────────────────────────────────
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                minimumSize: const Size(double.infinity, 44),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('⚠️  Report an issue'),
            ),

            // ── TEMP: Admin Panel shortcut (remove before release) ───────────
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            const Text(
              'DEV ONLY',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('🔧  Admin Panel (temp)'),
            ),
          ],
        ),
      ),
    );
  }
}
