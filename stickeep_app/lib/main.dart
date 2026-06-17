import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
