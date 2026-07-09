import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class GraveyardScreen extends StatelessWidget {
  const GraveyardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('graveyard')
        .orderBy('cancelled_at', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Cancelled reservations'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No cancelled reservations',
                  style: AppTextStyles.cardSubtitle),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final cancelledAt = data['cancelled_at'] as Timestamp?;
              final cancelledLabel = cancelledAt != null
                  ? cancelledAt.toDate().toString().split('.').first
                  : '—';

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
                        Text(data['classroom'] ?? '—',
                            style: AppTextStyles.cardTitle),
                        StatusTag(
                          label: 'Cancelled',
                          backgroundColor: AppColors.gray,
                          textColor: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seat ${data['seat_number'] ?? '—'} · ${data['date'] ?? ''} · ${data['time_start'] ?? ''}–${data['time_end'] ?? ''}',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text('Student: ${data['student_id'] ?? '—'}',
                        style: AppTextStyles.label),
                    const SizedBox(height: 4),
                    Text('Cancelled: $cancelledLabel',
                        style: AppTextStyles.label),
                    if ((data['cancelled_by'] as String?) == 'admin') ...[
                      const SizedBox(height: 4),
                      Text('⚠️ Cancelled by admin',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.red,
                              fontWeight: FontWeight.w500)),
                    ],
                    if ((data['nfc_status'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'NFC: ${data['nfc_status'] == 'approved' ? '✓ Checked in' : '✗ Access denied'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: data['nfc_status'] == 'approved'
                              ? AppColors.green
                              : AppColors.red,
                        ),
                      ),
                    ],
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
