import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
      home: const LoginScreen(),
    );
  }
}
