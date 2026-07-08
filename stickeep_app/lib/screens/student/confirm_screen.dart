import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/student/recurrence_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/booking.dart';
import 'package:stickeep_app/utils/seat_id.dart';

class ConfirmScreen extends StatefulWidget {
  final String classroom;
  final String classroomCode;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final int seatNumber;
  final DatabaseReference seatsRef;

  const ConfirmScreen({
    super.key,
    required this.classroom,
    required this.classroomCode,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatNumber,
    required this.seatsRef,
  });

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  bool _isLoading = false;

  Future<void> _confirm() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      // Read studentNumber first so it is guaranteed available for all writes
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .get();
      final studentData = studentDoc.data();
      // Try camelCase first, fall back to snake_case
      final studentNumber = ((studentData?['studentNumber'] ??
              studentData?['student_number'] ??
              '') as Object)
          .toString();

      final seatId = seatIdFromClassroom(widget.classroomCode, widget.seatNumber);

      // Check: seat already reserved for this exact date+time slot
      if (seatId != null &&
          await isSeatTaken(
            seatId: seatId,
            date: widget.date,
            timeStart: widget.timeStart,
            timeEnd: widget.timeEnd,
          )) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('You already have a reservation for this time slot')),
        );
        return;
      }

      final booking = await createReservation(
        uid: uid,
        classroom: widget.classroom,
        classroomCode: widget.classroomCode,
        lessonName: widget.lessonName,
        date: widget.date,
        timeStart: widget.timeStart,
        timeEnd: widget.timeEnd,
        seatNumber: widget.seatNumber,
        studentNumber: studentNumber,
        seatsRef: widget.seatsRef,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RecurrenceScreen(
            classroom: widget.classroom,
            classroomCode: widget.classroomCode,
            lessonName: widget.lessonName,
            date: widget.date,
            timeStart: widget.timeStart,
            timeEnd: widget.timeEnd,
            seatNumber: widget.seatNumber,
            studentNumber: studentNumber,
            firstReservationRtdbKey: booking.rtdbKey,
            firstReservationFirestoreId: booking.firestoreId,
            seatsRef: widget.seatsRef,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = widget.timeStart + '–' + widget.timeEnd;
    final lesson = widget.lessonName.isEmpty ? '—' : widget.lessonName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        title: const Text('Confirm reservation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 24, color: AppColors.green),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Almost done!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please review your reservation',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Classroom', value: widget.classroom),
                  _InfoRow(label: 'Lesson', value: lesson),
                  _InfoRow(label: 'Date', value: widget.date),
                  _InfoRow(label: 'Time', value: time),
                  _InfoRow(
                    label: 'Seat',
                    value: widget.seatNumber.toString(),
                    valueColor: AppColors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _confirm,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm reservation'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Edit — back to step 4'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
