import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        title: const Text('My reservations'),
      ),
      body: const Center(
        child: Text(
          'Coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
