import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/accessibility_controller.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/theme/theme_controller.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Accessibility')),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [ThemeController.instance, AccessibilityController.instance]),
        builder: (context, _) {
          final theme = ThemeController.instance;
          final a11y = AccessibilityController.instance;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Appearance', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark mode'),
                      subtitle: const Text('Easier on the eyes in low light'),
                      secondary: Icon(
                        theme.isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: AppColors.blue,
                      ),
                      value: theme.isDark,
                      onChanged: (_) => theme.toggle(),
                    ),
                    Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      title: const Text('Colorblind-friendly colors'),
                      subtitle: const Text(
                          'Swaps red/green status colors for a teal/orange pair, and adds icons to every status tag'),
                      secondary: Icon(Icons.palette_outlined, color: AppColors.blue),
                      value: a11y.colorBlindMode,
                      onChanged: (v) => a11y.setColorBlindMode(v),
                    ),
                    Divider(height: 1, color: AppColors.border),
                    SwitchListTile(
                      title: const Text('High contrast'),
                      subtitle: const Text(
                          'Darker text, thicker borders, and stronger edges for low vision'),
                      secondary: Icon(Icons.contrast_outlined, color: AppColors.blue),
                      value: a11y.highContrast,
                      onChanged: (v) => a11y.setHighContrast(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Text size', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...TextSizeOption.values.map((option) {
                      final selected = a11y.textSize == option;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => a11y.setTextSize(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.blueLight
                                  : AppColors.gray,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.blue
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? AppColors.blue
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.blue
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    Text('Preview', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    Text(
                      'Taub 1  •  Seat 3  •  09:00–11:00',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
