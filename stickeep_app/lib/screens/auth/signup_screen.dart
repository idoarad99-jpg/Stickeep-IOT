import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/web_nfc.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── Form controllers ──────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _nfcController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitted = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isScanningNfc = false;

  // ── Photo ─────────────────────────────────────────────────────────────────
  Uint8List? _avatarBytes;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _nfcController.dispose();
    super.dispose();
  }

  // ── NFC scan (Chrome on Android only — see lib/utils/web_nfc.dart) ────────

  Future<void> _scanNfcCard() async {
    setState(() => _isScanningNfc = true);
    try {
      final serial = await scanNfcCard();
      if (!mounted) return;
      if (serial == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No card detected — try again or enter it manually')),
        );
      } else {
        setState(() => _nfcController.text = serial.toUpperCase());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t read the card — check NFC is turned on, or enter the number manually'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanningNfc = false);
    }
  }

  // ── Photo logic ───────────────────────────────────────────────────────────

  void _showPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (!kIsWeb)
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.blue,
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.blue,
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  // ── Auth + Firestore ──────────────────────────────────────────────────────

  Future<void> _onCreateAccount() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _studentIdController.text.trim().isEmpty) {
      return;
    }

    final studentId = _studentIdController.text.trim();
    if (!RegExp(r'^[0-9]{6,9}$').hasMatch(studentId)) {
      setState(() => _errorMessage = 'Student ID must be 6–9 digits only.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create Firebase Auth account
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save registration request to Firestore
      final nfcCleaned = _nfcController.text
          .replaceAll(':', '')
          .replaceAll(' ', '')
          .toUpperCase();

      await FirebaseFirestore.instance
          .collection('registrationRequests')
          .doc(credential.user!.uid)
          .set({
        'studentNumber': _studentIdController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'nfcSerialNumber': nfcCleaned,
        'status': 'pending',
        'submittedAt': DateTime.now(),
      });

      if (!mounted) return;

      // 3. Success dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Request Submitted'),
          content: const Text(
            'Your request has been submitted! You will be notified once approved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // 4. Back to LoginScreen
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email sign-up is not enabled. Contact support.';
      default:
        return 'Sign-up failed ($code). Please try again.';
    }
  }

  String? _required(TextEditingController c) =>
      (_submitted && c.text.trim().isEmpty) ? 'This field is required' : null;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Gradient header with back button + avatar ────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.blue, AppColors.blue.withOpacity(0.75)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back',
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Create account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // balances the back button
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── Tappable avatar with "+" badge ───────────────────────
                    Semantics(
                      button: true,
                      label: 'Add profile photo',
                      child: GestureDetector(
                        onTap: _showPhotoBottomSheet,
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _avatarBytes != null
                                  ? CircleAvatar(
                                      radius: 42,
                                      backgroundImage:
                                          MemoryImage(_avatarBytes!),
                                    )
                                  : Container(
                                      width: 84,
                                      height: 84,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.blue, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 15,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Full name ────────────────────────────────────────────────
                    Text('Full name', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        errorText: _required(_nameController),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Email ────────────────────────────────────────────────────
                    Text('Email', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        errorText: _required(_emailController),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────────────────
                    Text('Password', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Create a password',
                        errorText: _required(_passwordController),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Student ID (highlighted) ─────────────────────────────────
                    Text('Student ID number', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _studentIdController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: '123456789',
                        hintStyle: TextStyle(
                          color: AppColors.blue.withOpacity(0.45),
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: AppColors.blueLight,
                        errorText: _required(_studentIdController),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.blue),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.blue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AppColors.blue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '⭐ This number will appear on your seat sticker',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── NFC Card Serial Number (optional) ────────────────────────
                    Text('NFC Card Serial Number', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nfcController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'e.g. AA:BB:CC:DD:EE:FF',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isWebNfcSupported)
                      OutlinedButton.icon(
                        onPressed: _isScanningNfc ? null : _scanNfcCard,
                        icon: _isScanningNfc
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.blue,
                                ),
                              )
                            : Icon(Icons.nfc, color: AppColors.blue, size: 18),
                        label: Text(
                          _isScanningNfc ? 'Hold your card near the phone…' : 'Tap your card instead',
                        ),
                      )
                    else
                      Text(
                        '📱 Scan your Technion card with any NFC reader app to find this number',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 28),

                    // ── Create account ───────────────────────────────────────────
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onCreateAccount,
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
                          : const Text('Create account'),
                    ),

                    // ── Error message ────────────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ── Back to login ────────────────────────────────────────────
                    OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
