import 'package:flutter/material.dart';

/// Semantic colors used directly by screens (outside the Theme mechanism).
/// Values are getters driven by [ThemeController] so plain widgets like
/// `Container(color: AppColors.gray)` adapt to light/dark without needing
/// a BuildContext at every call site.
class AppColors {
  static bool _isDark = false;
  static bool get isDark => _isDark;
  static void setDark(bool value) => _isDark = value;

  // Colorblind-safe mode swaps the green/red status pair (the classic
  // red-green confusion for deuteranopia/protanopia, the most common forms)
  // for a teal/orange pair that stays distinguishable, and adds icons
  // wherever status is shown (see StatusTag) so color is never the only cue.
  static bool _colorBlindMode = false;
  static bool get colorBlindMode => _colorBlindMode;
  static void setColorBlindMode(bool value) => _colorBlindMode = value;

  // High-contrast mode: pushes text/border contrast ratios up and thickens
  // outlines for low-vision users, on top of whatever dark/colorblind mode
  // is already active.
  static bool _highContrast = false;
  static bool get highContrast => _highContrast;
  static void setHighContrast(bool value) => _highContrast = value;

  /// Card/tile borders are thicker in high-contrast mode so edges don't rely
  /// on a subtle color difference alone.
  static double get borderWidth => _highContrast ? 2 : 1;

  // Primary
  static Color get blue => _isDark ? const Color(0xFF5B9BD9) : const Color(0xFF185FA5);
  static Color get blueLight => _isDark ? const Color(0xFF17324B) : const Color(0xFFE6F1FB);

  // Status — "green" semantically means free/success/positive.
  static Color get green => _colorBlindMode
      ? (_isDark ? const Color(0xFF4FC3C7) : const Color(0xFF00707A))
      : (_isDark ? const Color(0xFF8BC34A) : const Color(0xFF3B6D11));
  static Color get greenLight => _colorBlindMode
      ? (_isDark ? const Color(0xFF102E30) : const Color(0xFFE0F4F5))
      : (_isDark ? const Color(0xFF203015) : const Color(0xFFEAF3DE));

  // Status — "red" semantically means taken/danger/negative.
  static Color get red => _colorBlindMode
      ? (_isDark ? const Color(0xFFFFB74D) : const Color(0xFFB1500A))
      : (_isDark ? const Color(0xFFEF9A9A) : const Color(0xFFA32D2D));
  static Color get redLight => _colorBlindMode
      ? (_isDark ? const Color(0xFF3D2A10) : const Color(0xFFFDECD8))
      : (_isDark ? const Color(0xFF3D2020) : const Color(0xFFFCEBEB));

  static Color get amber => _isDark ? const Color(0xFFFFB74D) : const Color(0xFF854F0B);
  static Color get amberLight => _isDark ? const Color(0xFF3D2E14) : const Color(0xFFFAEEDA);

  // Admin
  static Color get purple => _isDark ? const Color(0xFFA48CE0) : const Color(0xFF3C3489);
  static Color get purpleLight => _isDark ? const Color(0xFF261F4D) : const Color(0xFFEEEDFE);

  // Neutral
  static Color get gray => _isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5);
  static Color get border => _highContrast
      ? (_isDark ? const Color(0xFF8A8A8A) : const Color(0xFF4A4A4A))
      : (_isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0));
  static Color get textPrimary => _isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
  // Muted secondary text is the classic low-contrast offender — bump it much
  // closer to full black/white when high-contrast mode is on.
  static Color get textSecondary => _highContrast
      ? (_isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2E2E2E))
      : (_isDark ? const Color(0xFFA0A6B0) : const Color(0xFF6B7280));

  // Card/sheet background — use instead of a literal Colors.white so cards
  // adapt in dark mode.
  static Color get surface => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color get scaffoldBg => _isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F8);

  /// Soft drop shadow for cards — subtler in dark mode where contrast
  /// already comes from the surface/background split.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: _isDark ? Colors.black.withOpacity(0.35) : const Color(0x14185FA5),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppTheme {
  static ThemeData _build({required bool dark}) {
    final primary = dark ? const Color(0xFF5B9BD9) : const Color(0xFF185FA5);
    final scaffoldBg = dark ? const Color(0xFF121212) : const Color(0xFFF0F4F8);
    final surface = dark ? const Color(0xFF1E1E1E) : Colors.white;
    final fill = dark ? const Color(0xFF242424) : const Color(0xFFF5F5F5);
    // Mirrors AppColors.border/.textSecondary but keyed off this build's own
    // `dark` param (not the static AppColors._isDark flag) — _build runs
    // once per light/dark variant regardless of which one is active.
    final highContrast = AppColors.highContrast;
    final border = highContrast
        ? (dark ? const Color(0xFF8A8A8A) : const Color(0xFF4A4A4A))
        : (dark ? const Color(0xFF383838) : const Color(0xFFE0E0E0));
    final textPrimary = dark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
    final textSecondary = highContrast
        ? (dark ? const Color(0xFFE0E0E0) : const Color(0xFF2E2E2E))
        : (dark ? const Color(0xFFA0A6B0) : const Color(0xFF6B7280));
    final borderWidth = AppColors.borderWidth;

    final base = dark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      cardColor: surface,
      dividerColor: border,
      textTheme: base.textTheme.apply(
        fontFamily: 'DM Sans',
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      useMaterial3: true,

      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'DM Sans',
        ),
      ),

      // כפתורים — גובה מינימלי 50px לנגישות, פינות רכות יותר
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'DM Sans',
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(color: border, width: borderWidth),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'DM Sans',
          ),
        ),
      ),

      // שדות קלט
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        labelStyle: TextStyle(fontSize: 14, color: textSecondary),
        hintStyle: TextStyle(fontSize: 14, color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: borderWidth + 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'DM Sans'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary.withOpacity(0.4) : null),
      ),
    );
  }

  static ThemeData get theme => _build(dark: false);
  static ThemeData get darkTheme => _build(dark: true);
}

// סגנונות טקסט לשימוש חוזר
class AppTextStyles {
  static TextStyle get sectionTitle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get cardTitle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardSubtitle => TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get value => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
}

/// A soft, elevated card used across the app instead of a plain bordered
/// Container, for the "soft & modern" visual direction.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: AppColors.highContrast
            ? Border.all(color: AppColors.border, width: AppColors.borderWidth)
            : null,
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Consistent empty-state placeholder: icon in a soft circle, title, and
/// an optional subtitle/action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.cardSubtitle,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress indicator for the multi-screen booking flow
/// (classroom -> seat -> confirm). Shows "Step X of N" plus a dotted track.
class BookingStepIndicator extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String label;

  const BookingStepIndicator({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Step $step of $totalSteps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(totalSteps, (i) {
            final done = i < step;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: done ? AppColors.blue : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// Widget עזר לתגיות סטטוס (free / reserved / occupied)
// Carries an icon alongside color+text so status is never conveyed by
// color alone (important for colorblind users).
class StatusTag extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusTag.free() => StatusTag(
        label: 'Free',
        backgroundColor: AppColors.greenLight,
        textColor: AppColors.green,
        icon: Icons.check_circle_outline,
      );

  factory StatusTag.occupied() => StatusTag(
        label: 'Occupied',
        backgroundColor: AppColors.redLight,
        textColor: AppColors.red,
        icon: Icons.block,
      );

  factory StatusTag.reserved() => StatusTag(
        label: 'Reserved',
        backgroundColor: AppColors.amberLight,
        textColor: AppColors.amber,
        icon: Icons.schedule,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
