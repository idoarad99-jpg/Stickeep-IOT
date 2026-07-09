import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/screens/auth/login_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/theme/theme_controller.dart';
import 'package:stickeep_app/theme/accessibility_controller.dart';
import 'package:stickeep_app/firebase_options.dart';
import 'package:stickeep_app/utils/classroom_seed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ensureDefaultClassroomsSeeded();
  await ThemeController.instance.init();
  await AccessibilityController.instance.init();

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
      animation: Listenable.merge(
          [ThemeController.instance, AccessibilityController.instance]),
      builder: (context, _) => MaterialApp(
        title: 'Stickeep',
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.mode,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                  AccessibilityController.instance.textScale),
            ),
            child: child!,
          );
        },
        home: LoginScreen(initialEmail: initialEmail),
      ),
    );
  }
}
