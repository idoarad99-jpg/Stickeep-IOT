import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _showOpen = true;
  bool _showResolved = true;

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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Open'),
                  selected: _showOpen,
                  onSelected: (val) => setState(() => _showOpen = val),
                  selectedColor: AppColors.redLight,
                  checkmarkColor: AppColors.red,
                ),
                FilterChip(
                  label: const Text('Resolved'),
                  selected: _showResolved,
                  onSelected: (val) => setState(() => _showResolved = val),
                  selectedColor: AppColors.greenLight,
                  checkmarkColor: AppColors.green,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No reports yet',
              subtitle: 'Everything looks fine around here.',
            );
          }

          final raw =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final allReports = raw.entries.toList()
            ..sort((a, b) {
              final aDate =
                  (a.value as Map)['created_at'] as String? ?? '';
              final bDate =
                  (b.value as Map)['created_at'] as String? ?? '';
              return bDate.compareTo(aDate);
            });

          final reports = allReports.where((e) {
            final status = (e.value as Map)['status'] as String? ?? 'open';
            if (status == 'open') return _showOpen;
            if (status == 'resolved') return _showResolved;
            return true;
          }).toList();

          if (reports.isEmpty) {
            return Center(
              child: Text('No reports match the filters',
                  style: AppTextStyles.cardSubtitle),
            );
          }

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
                      ? AppColors.greenLight.withOpacity(0.4)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
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
                        Icon(Icons.person_outline,
                            size: 14,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          studentName.isNotEmpty
                              ? studentName
                              : uid,
                          style: TextStyle(
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
                          Icon(Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            locationParts.join(' · '),
                            style: TextStyle(
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
                    Divider(height: 1, color: AppColors.border),
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
          ),
        ],
      ),
    );
  }
}
