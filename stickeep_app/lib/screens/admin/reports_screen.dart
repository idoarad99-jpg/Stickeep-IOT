import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _toggleStatus(String key, String currentStatus) async {
    final newStatus = currentStatus == 'open' ? 'resolved' : 'open';
    await FirebaseDatabase.instance
        .ref('reports/$key')
        .update({'status': newStatus});
  }

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

          final raw =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final reports = raw.entries.toList()
            ..sort((a, b) {
              final aDate =
                  (a.value as Map)['created_at'] as String? ?? '';
              final bDate =
                  (b.value as Map)['created_at'] as String? ?? '';
              return bDate.compareTo(aDate);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final key = reports[index].key as String;
              final data =
                  reports[index].value as Map<dynamic, dynamic>;
              final tag = data['tag'] as String? ?? 'Unknown';
              final desc = data['description'] as String? ?? '';
              final status = data['status'] as String? ?? 'open';
              final studentName =
                  data['student_name'] as String? ?? '';
              final uid = data['uid'] as String? ?? '';
              final building = data['building'] as String? ?? '';
              final room = data['room'] as String? ?? '';
              final seat = data['seat'] as String? ?? '';
              final date = (data['created_at'] as String? ?? '')
                  .split('T')
                  .first;

              final isResolved = status == 'resolved';
              final locationParts = [
                if (building.isNotEmpty) building,
                if (room.isNotEmpty) 'Room $room',
                if (seat.isNotEmpty) 'Seat $seat',
              ];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isResolved
                      ? const Color(0xFFF8FFF4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isResolved
                        ? AppColors.green.withOpacity(0.3)
                        : AppColors.border,
                  ),
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
                            color: isResolved
                                ? AppColors.greenLight
                                : AppColors.redLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isResolved
                                  ? AppColors.green
                                  : AppColors.red,
                            ),
                          ),
                        ),
                        Text(date, style: AppTextStyles.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Student name
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          studentName.isNotEmpty
                              ? studentName
                              : uid,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    // Location
                    if (locationParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            locationParts.join(' · '),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(desc, style: AppTextStyles.cardSubtitle),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),
                    // Resolve button
                    GestureDetector(
                      onTap: () => _toggleStatus(key, status),
                      child: Row(
                        children: [
                          Icon(
                            isResolved
                                ? Icons.refresh_outlined
                                : Icons.check_circle_outline,
                            size: 16,
                            color: isResolved
                                ? AppColors.textSecondary
                                : AppColors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isResolved
                                ? 'Mark as open'
                                : 'Mark as resolved',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isResolved
                                  ? AppColors.textSecondary
                                  : AppColors.green,
                            ),
                          ),
                        ],
                      ),
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
