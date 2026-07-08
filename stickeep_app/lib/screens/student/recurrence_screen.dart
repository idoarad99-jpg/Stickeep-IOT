import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/student/success_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/booking.dart';

// Safety cap: never generate more occurrences than this in one go.
const int _maxOccurrences = 26;

class RecurrenceScreen extends StatefulWidget {
  final String classroom;
  final String classroomId;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final String seatId;
  final int seatNumber;
  final String studentNumber;
  final String firstReservationRtdbKey;
  final String firstReservationFirestoreId;

  const RecurrenceScreen({
    super.key,
    required this.classroom,
    required this.classroomId,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatId,
    required this.seatNumber,
    required this.studentNumber,
    required this.firstReservationRtdbKey,
    required this.firstReservationFirestoreId,
  });

  @override
  State<RecurrenceScreen> createState() => _RecurrenceScreenState();
}

class _RecurrenceScreenState extends State<RecurrenceScreen> {
  bool _repeatEnabled = false;
  int _intervalWeeks = 1;
  DateTime? _untilDate;
  bool _isSubmitting = false;

  late final DateTime _firstDate = _parseDate(widget.date);

  DateTime _parseDate(String d) {
    final p = d.split('.');
    return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _weekdayName(DateTime d) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][d.weekday - 1];

  Future<void> _pickUntilDate() async {
    final minDate = _firstDate.add(Duration(days: 7 * _intervalWeeks));
    final maxDate = _firstDate.add(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: maxDate,
    );
    if (picked != null) setState(() => _untilDate = picked);
  }

  void _goToSuccess({String? recurrenceSummary}) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final time = '${widget.timeStart}–${widget.timeEnd}';
    final lesson = widget.lessonName.isEmpty ? '—' : widget.lessonName;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          email: email,
          classroom: widget.classroom,
          seat: widget.seatNumber.toString(),
          date: widget.date,
          lesson: lesson,
          time: time,
          reservationId: widget.firstReservationFirestoreId,
          studentName: email,
          studentNumber: widget.studentNumber,
          recurrenceSummary: recurrenceSummary,
        ),
      ),
    );
  }

  Future<void> _setUpRecurrence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _untilDate == null) return;

    setState(() => _isSubmitting = true);

    final occurrenceDates = <DateTime>[];
    var next = _firstDate.add(Duration(days: 7 * _intervalWeeks));
    while (!next.isAfter(_untilDate!) && occurrenceDates.length < _maxOccurrences) {
      occurrenceDates.add(next);
      next = next.add(Duration(days: 7 * _intervalWeeks));
    }

    final groupId = widget.firstReservationFirestoreId;
    var createdCount = 0;
    final skippedDates = <String>[];

    for (final occDate in occurrenceDates) {
      final dateStr = _formatDate(occDate);
      final taken = await isSeatTaken(
        seatId: widget.seatId,
        date: dateStr,
        timeStart: widget.timeStart,
        timeEnd: widget.timeEnd,
      );
      if (taken) {
        skippedDates.add(dateStr);
        continue;
      }
      await createReservation(
        uid: uid,
        classroom: widget.classroom,
        classroomId: widget.classroomId,
        lessonName: widget.lessonName,
        date: dateStr,
        timeStart: widget.timeStart,
        timeEnd: widget.timeEnd,
        seatId: widget.seatId,
        seatNumber: widget.seatNumber,
        studentNumber: widget.studentNumber,
        recurringGroupId: groupId,
      );
      createdCount++;
    }

    // Only tag the first reservation as part of the group if at least one
    // repeat was actually created.
    if (createdCount > 0) {
      await tagReservationAsRecurring(
        uid: uid,
        rtdbKey: widget.firstReservationRtdbKey,
        firestoreId: widget.firstReservationFirestoreId,
        recurringGroupId: groupId,
      );
    }

    if (!mounted) return;

    final summary = createdCount == 0
        ? 'No additional occurrences could be booked — all requested dates were already taken.'
        : skippedDates.isEmpty
            ? 'Repeated $createdCount more time${createdCount == 1 ? '' : 's'}, every $_intervalWeeks week${_intervalWeeks == 1 ? '' : 's'} until ${_formatDate(_untilDate!)}.'
            : 'Repeated $createdCount more time${createdCount == 1 ? '' : 's'}. Skipped ${skippedDates.length} date${skippedDates.length == 1 ? '' : 's'} already booked: ${skippedDates.join(', ')}.';

    _goToSuccess(recurrenceSummary: summary);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_repeatEnabled || _untilDate != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        automaticallyImplyLeading: false,
        title: const Text('Repeat this reservation?'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Your seat for ${widget.classroom} on ${widget.date} is confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Make this a recurring reservation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _repeatEnabled,
                activeColor: AppColors.blue,
                onChanged: (val) => setState(() => _repeatEnabled = val),
              ),
            ),
            if (_repeatEnabled) ...[
              const SizedBox(height: 20),
              const Text('Every', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _intervalWeeks,
                      items: List.generate(8, (i) => i + 1)
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n week${n == 1 ? '' : 's'}'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() {
                        _intervalWeeks = val ?? 1;
                        _untilDate = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('on ${_weekdayName(_firstDate)}s',
                      style: AppTextStyles.value),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Until', style: AppTextStyles.label),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickUntilDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _untilDate == null
                            ? 'Select end date'
                            : _formatDate(_untilDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: _untilDate == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If a date is already booked by someone else, it will be skipped and you\'ll be notified.',
                style: AppTextStyles.cardSubtitle,
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting || !canSubmit
                  ? null
                  : () => _repeatEnabled ? _setUpRecurrence() : _goToSuccess(),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_repeatEnabled
                      ? 'Create recurring reservations'
                      : 'Continue'),
            ),
            if (_repeatEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSubmitting ? null : () => _goToSuccess(),
                child: const Text('Skip — just this once'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
