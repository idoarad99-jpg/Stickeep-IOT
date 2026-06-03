import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/auth/signup_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth logic ────────────────────────────────────────────────────────────

  Future<void> _onLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Sign in with Firebase Auth
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      print('[LoginScreen] Signed in — uid: ${credential.user!.uid}');

      // 2. Check registration status in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('registrationRequests')
          .doc(credential.user!.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _errorMessage =
              'No registration request found. Please sign up first.';
          _isLoading = false;
        });
        return;
      }

      final status = doc.data()?['status'] as String?;

      switch (status) {
        case 'approved':
          // 3. Approved → pop back to FirebaseTestScreen (root of the stack)
          Navigator.of(context).popUntil((route) => route.isFirst);

        case 'pending':
          setState(() {
            _errorMessage =
                'Your account is pending approval. Please wait.';
            _isLoading = false;
          });

        case 'rejected':
          setState(() {
            _errorMessage =
                'Your request was rejected. Please contact the accessibility office.';
            _isLoading = false;
          });

        default:
          setState(() {
            _errorMessage = 'Unknown account status. Please contact support.';
            _isLoading = false;
          });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e.code);
        _isLoading = false;
      });
    } catch (e) {
      print('[LoginScreen] Unexpected error: $e');
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      // Firebase v10+ merges user-not-found + wrong-password into this code
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      default:
        return 'Incorrect email or password. Please try again.';
    }
  }

  void _onBiometricPressed() {
    print('[LoginScreen] Fingerprint / Face ID pressed');
    // TODO: local_auth integration
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stickeep'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              const Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 44,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Username ─────────────────────────────────────────────────
              const Text('Username', style: AppTextStyles.label),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => _errorMessage = null),
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                ),
              ),
              const SizedBox(height: 16),

              // ── Password ─────────────────────────────────────────────────
              const Text('Password', style: AppTextStyles.label),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() => _errorMessage = null),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Login ────────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _onLoginPressed,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Login'),
              ),

              // ── Error message ────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // ── Fingerprint / Face ID ────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _onBiometricPressed,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Fingerprint / Face ID'),
              ),
              const SizedBox(height: 32),

              // ── Sign up ──────────────────────────────────────────────────
              const Center(
                child: Text(
                  "Don't have an account?",
                  style: AppTextStyles.cardSubtitle,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen()),
                        ),
                child: const Text('Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
