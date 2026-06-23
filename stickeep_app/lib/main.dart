import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/screens/auth/login_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final savedEmail = prefs.getString('saved_email') ?? '';

  runApp(MyApp(initialEmail: savedEmail));
}

class MyApp extends StatelessWidget {
  final String initialEmail;

  const MyApp({super.key, this.initialEmail = ''});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickeep',
      theme: AppTheme.theme,
      home: LoginScreen(initialEmail: initialEmail),
    );
  }
}
