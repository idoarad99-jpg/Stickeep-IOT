import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickeep_app/theme/app_theme.dart';

/// Text size steps offered in the accessibility settings screen.
enum TextSizeOption { normal, large, extraLarge }

extension TextSizeOptionScale on TextSizeOption {
  double get scale {
    switch (this) {
      case TextSizeOption.normal:
        return 1.0;
      case TextSizeOption.large:
        return 1.2;
      case TextSizeOption.extraLarge:
        return 1.4;
    }
  }

  String get label {
    switch (this) {
      case TextSizeOption.normal:
        return 'Normal';
      case TextSizeOption.large:
        return 'Large';
      case TextSizeOption.extraLarge:
        return 'Extra large';
    }
  }
}

/// Drives colorblind-safe palette + text scale, alongside [ThemeController]
/// for dark mode — together these are the app's accessibility settings.
class AccessibilityController extends ChangeNotifier {
  AccessibilityController._();
  static final AccessibilityController instance = AccessibilityController._();

  bool _colorBlindMode = false;
  TextSizeOption _textSize = TextSizeOption.normal;

  bool get colorBlindMode => _colorBlindMode;
  TextSizeOption get textSize => _textSize;
  double get textScale => _textSize.scale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _colorBlindMode = prefs.getBool('colorblind_mode') ?? false;
    final savedSize = prefs.getString('text_size');
    _textSize = TextSizeOption.values.firstWhere(
      (o) => o.name == savedSize,
      orElse: () => TextSizeOption.normal,
    );
    AppColors.setColorBlindMode(_colorBlindMode);
  }

  Future<void> setColorBlindMode(bool value) async {
    _colorBlindMode = value;
    AppColors.setColorBlindMode(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('colorblind_mode', value);
  }

  Future<void> setTextSize(TextSizeOption value) async {
    _textSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('text_size', value.name);
  }
}
