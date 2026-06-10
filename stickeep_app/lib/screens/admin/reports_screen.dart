import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref('reports');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Reports'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.border),
                  SizedBox(height: 16),
                  Text('No reports yet', style: AppTextStyles.cardSubtitle),
                ],
              ),
            );
          }

          final raw = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final reports = raw.entries.toList()
            ..sort((a, b) {
              final aDate = (a.value as Map)['created_at'] as String? ?? '';
              final bDate = (b.value as Map)['created_at'] as String? ?? '';
              return bDate.compareTo(aDate);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final data = reports[index].value as Map<dynamic, dynamic>;
              final tag = data['tag'] as String? ?? 'Unknown';
              final desc = data['description'] as String? ?? '';
              final status = data['status'] as String? ?? 'open';
              final uid = data['uid'] as String? ?? '';
              final date =
                  (data['created_at'] as String? ?? '').split('T').first;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'open'
                                ? AppColors.redLight
                                : AppColors.greenLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: status == 'open'
                                  ? AppColors.red
                                  : AppColors.green,
                            ),
                          ),
                        ),
                        Text(date, style: AppTextStyles.label),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(desc, style: AppTextStyles.cardSubtitle),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'User: $uid',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
