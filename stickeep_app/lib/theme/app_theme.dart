import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const blue = Color(0xFF185FA5);
  static const blueLight = Color(0xFFE6F1FB);

  // Status
  static const green = Color(0xFF3B6D11);
  static const greenLight = Color(0xFFEAF3DE);
  static const red = Color(0xFFA32D2D);
  static const redLight = Color(0xFFFCEBEB);
  static const amber = Color(0xFF854F0B);
  static const amberLight = Color(0xFFFAEEDA);

  // Admin
  static const purple = Color(0xFF3C3489);
  static const purpleLight = Color(0xFFEEEDFE);

  // Neutral
  static const gray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          primary: AppColors.blue,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        fontFamily: 'DM Sans',
        useMaterial3: true,

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        // כפתורים — גובה מינימלי 50px לנגישות
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // שדות קלט
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.gray,
          labelStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );
}

// סגנונות טקסט לשימוש חוזר
class AppTextStyles {
  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const cardSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );

  static const value = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

// Widget עזר לתגיות סטטוס (free / reserved / occupied)
class StatusTag extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusTag.free() => const StatusTag(
        label: 'Free',
        backgroundColor: AppColors.greenLight,
        textColor: AppColors.green,
      );

  factory StatusTag.occupied() => const StatusTag(
        label: 'Occupied',
        backgroundColor: AppColors.redLight,
        textColor: AppColors.red,
      );

  factory StatusTag.reserved() => const StatusTag(
        label: 'Reserved',
        backgroundColor: AppColors.amberLight,
        textColor: AppColors.amber,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
