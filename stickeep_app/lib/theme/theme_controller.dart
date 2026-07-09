import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/theme/app_theme.dart';

/// Drives light/dark mode across the app. [AppColors] getters read the
/// current brightness synchronously (no BuildContext needed at call sites),
/// while this controller triggers the MaterialApp rebuild that makes those
/// getters re-evaluate everywhere.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    AppColors.setDark(isDark);
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    AppColors.setDark(isDark);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', isDark ? 'dark' : 'light');
  }
}
