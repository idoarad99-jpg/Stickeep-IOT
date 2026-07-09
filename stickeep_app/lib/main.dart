import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/screens/auth/login_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/theme/theme_controller.dart';
import 'package:stickeep_app/firebase_options.dart';
import 'package:stickeep_app/utils/classroom_seed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ensureDefaultClassroomsSeeded();
  await ThemeController.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final savedEmail = prefs.getString('saved_email') ?? '';

  runApp(MyApp(initialEmail: savedEmail));
}

class MyApp extends StatelessWidget {
  final String initialEmail;

  const MyApp({super.key, this.initialEmail = ''});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'Stickeep',
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.mode,
        home: LoginScreen(initialEmail: initialEmail),
      ),
    );
  }
}
