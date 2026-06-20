import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/reservation.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/seat_id.dart';
import 'package:stickeep_app/widgets/reservation_card.dart';
import 'package:stickeep_app/widgets/qr_code_dialog.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';

class ReservationsScreen extends StatelessWidget {
  final bool showUpcoming;

  const ReservationsScreen({super.key, this.showUpcoming = true});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final ref = FirebaseDatabase.instance.ref('reservations/$uid');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),
        title: Text(showUpcoming ? 'My Reservations' : 'Reservation History'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _emptyState();
          }

          final raw = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          final reservations = raw.entries
              .map((e) => Reservation.fromJson(
                  e.key.toString(), e.value as Map<dynamic, dynamic>))
              .where((r) => r.isUpcoming == showUpcoming)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          if (reservations.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final r = reservations[index];
              return ReservationCard(
                reservation: r,
                onCancel: showUpcoming
                    ? () => _cancelReservation(context, uid, r)
                    : null,
                onShowQr: (r.isUpcoming &&
                        r.qrToken != null &&
                        r.qrToken!.isNotEmpty)
                    ? () => showQrDialog(
                          context,
                          reservationId: r.qrToken!,
                          classroom: r.classroom,
                          seat: r.seatNumber.toString(),
                          date: r.date,
                          time: '${r.timeStart}–${r.timeEnd}',
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            showUpcoming ? 'No upcoming reservations' : 'No past reservations',
            style: AppTextStyles.cardSubtitle,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(
      BuildContext context, String uid, Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseDatabase.instance
        .ref('reservations/$uid/${r.id}')
        .update({'is_upcoming': false});

    // Clear the Firestore seats document for this reservation
    final seatId = seatIdFromClassroom(r.classroom, r.seatNumber);
    if (seatId != null) {
      final seatDocRef =
          FirebaseFirestore.instance.collection('seats').doc(seatId);
      final seatDoc = await seatDocRef.get();
      if (seatDoc.exists) {
        final data = seatDoc.data()!;
        // Only clear if this seat is currently holding the same slot
        if (data['date'] == r.date &&
            data['startTime'] == r.timeStart &&
            data['endTime'] == r.timeEnd) {
          final fsReservationId = data['reservationId'] as String?;
          await seatDocRef.update({
            'status': 'free',
            'studentNumber': '',
            'startTime': '',
            'endTime': '',
            'date': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (fsReservationId != null) {
            await seatDocRef
                .collection('reservations')
                .doc(fsReservationId)
                .update({'status': 'cancelled'});
            await FirebaseFirestore.instance
                .collection('reservations')
                .doc(fsReservationId)
                .update({'status': 'cancelled'});
          }
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled')),
      );
    }
  }
}
