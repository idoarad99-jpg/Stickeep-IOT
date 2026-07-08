import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/screens/auth/signup_screen.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String initialEmail;

  const LoginScreen({super.key, this.initialEmail = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail.isNotEmpty) {
      _emailController.text = widget.initialEmail;
      _rememberMe = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth logic ────────────────────────────────────────────────────────────

  Future<void> _saveOrClearRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
    } else {
      await prefs.remove('saved_email');
    }
  }

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

      final uid = credential.user!.uid;

      // 2. Check students/{uid} — any existing doc means authorized
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        final userName = data['name'] as String? ?? 'User';
        final userRole = data['role'] as String? ?? 'student';
        print('[LoginScreen] role from Firestore: "$userRole"');

        await _saveOrClearRememberMe(email);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: userName,
              userRole: userRole,
            ),
          ),
        );
        return;
      }

      // 3. Not in students/ → check registrationRequests
      final reqDoc = await FirebaseFirestore.instance
          .collection('registrationRequests')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (!reqDoc.exists) {
        setState(() {
          _errorMessage = 'Unknown account. Please sign up first.';
          _isLoading = false;
        });
        return;
      }

      final status = reqDoc.data()?['status'] as String?;

      switch (status) {
        case 'approved':
          // Copy approved request into students/ then navigate
          final reqData = reqDoc.data()!;
          await FirebaseFirestore.instance
              .collection('students')
              .doc(uid)
              .set({
            'name': reqData['name'] ?? '',
            'role': reqData['role'] as String? ?? 'student',
            'email': reqData['email'] ?? email,
          });

          await _saveOrClearRememberMe(email);
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                userName: reqData['name'] as String? ?? 'User',
                userRole: reqData['role'] as String? ?? 'student',
              ),
            ),
          );

        case 'pending':
          setState(() {
            _errorMessage = 'Your account is pending approval. Please wait.';
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
            _errorMessage = 'Unknown account. Please sign up first.';
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

  Future<void> _onForgotPasswordPressed() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email and we'll send you a reset link",
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Enter your email address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF185FA5),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              Navigator.pop(ctx);
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent! Check your inbox.'),
                    backgroundColor: Color(0xFF3B6D11),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                final msg = e.code == 'user-not-found'
                    ? 'No account found with this email.'
                    : 'Failed to send reset email. Please try again.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: const Color(0xFFA32D2D),
                  ),
                );
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );

    resetEmailController.dispose();
  }

  void _onBiometricPressed() {
    print('[LoginScreen] Fingerprint / Face ID pressed');
    // TODO: local_auth integration
  }

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

              // Username
              const Text('Email', style: AppTextStyles.label),
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

              // Password
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
              // ── Forgot password ──────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _onForgotPasswordPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF185FA5),
                    textStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 4),

              // ── Remember me ──────────────────────────────────────────────
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (v) =>
                        setState(() => _rememberMe = v ?? false),
                    activeColor: const Color(0xFF185FA5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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

              const SizedBox(height: 32),

              // Sign up
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
