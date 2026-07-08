import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/classroom.dart';
import 'package:stickeep_app/screens/student/seat_map_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';

// Used if Firestore's classrooms/ collection can't be loaded (missing
// composite index, permissions error, or the query simply times out).
const _fallbackClassroomNames = ['Taub 1', 'Taub 2', 'Taub 3', 'Taub 4', 'Taub 5'];

List<Classroom> _fallbackClassrooms() => List.generate(
      _fallbackClassroomNames.length,
      (i) => Classroom(
        code: 'T${i + 1}',
        name: _fallbackClassroomNames[i],
        seatCount: 5,
        order: i + 1,
        active: true,
      ),
    );

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  Classroom? _selectedClassroom;
  DateTime? _selectedDate;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  final _lessonController = TextEditingController();

  List<Classroom>? _classrooms;
  bool _classroomsFallback = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _classroomsSub;
  Timer? _classroomsTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  void _loadClassrooms() {
    _classroomsTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (_classrooms == null && mounted) {
        setState(() => _classroomsFallback = true);
      }
    });

    _classroomsSub = FirebaseFirestore.instance
        .collection('classrooms')
        .where('active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .listen(
      (snapshot) {
        _classroomsTimeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _classrooms = snapshot.docs.map(Classroom.fromDoc).toList();
          _classroomsFallback = false;
        });
      },
      onError: (_) {
        _classroomsTimeoutTimer?.cancel();
        if (mounted) setState(() => _classroomsFallback = true);
      },
    );
  }

  @override
  void dispose() {
    _classroomsSub?.cancel();
    _classroomsTimeoutTimer?.cancel();
    _lessonController.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      _selectedClassroom != null &&
      _selectedDate != null &&
      _timeStart != null &&
      _timeEnd != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _timeStart = picked;
        } else {
          _timeEnd = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),title: const Text('New Reservation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Classroom ──────────────────────────────────────────────────
            const Text('Classroom', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              if (_classroomsFallback) {
                return _ClassroomChips(
                  classrooms: _fallbackClassrooms(),
                  selected: _selectedClassroom,
                  onSelect: (room) => setState(() => _selectedClassroom = room),
                );
              }

              if (_classrooms == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (_classrooms!.isEmpty) {
                return const Text(
                  'No classrooms available yet. Ask an admin to add one.',
                  style: AppTextStyles.cardSubtitle,
                );
              }

              return _ClassroomChips(
                classrooms: _classrooms!,
                selected: _selectedClassroom,
                onSelect: (room) => setState(() => _selectedClassroom = room),
              );
            }),
            const SizedBox(height: 20),

            // ── Lesson name ────────────────────────────────────────────────
            const Text('Lesson name (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextField(
              controller: _lessonController,
              decoration: const InputDecoration(hintText: 'e.g. Data Structures'),
            ),
            const SizedBox(height: 20),

            // ── Date ───────────────────────────────────────────────────────
            const Text('Date', style: AppTextStyles.label),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.gray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDate == null
                          ? 'Select date'
                          : _formatDate(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDate == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Time ───────────────────────────────────────────────────────
            const Text('Time', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.gray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            _timeStart == null ? 'Start' : _formatTime(_timeStart!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _timeStart == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.gray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            _timeEnd == null ? 'End' : _formatTime(_timeEnd!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _timeEnd == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Next ───────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _canProceed
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeatMapScreen(
                            classroom: _selectedClassroom!.name,
                            classroomCode: _selectedClassroom!.code,
                            seatCount: _selectedClassroom!.seatCount,
                            lessonName: _lessonController.text.trim(),
                            date: _formatDate(_selectedDate!),
                            timeStart: _formatTime(_timeStart!),
                            timeEnd: _formatTime(_timeEnd!),
                          ),
                        ),
                      )
                  : null,
              child: const Text('Next → Pick a seat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassroomChips extends StatelessWidget {
  final List<Classroom> classrooms;
  final Classroom? selected;
  final ValueChanged<Classroom> onSelect;

  const _ClassroomChips({
    required this.classrooms,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: classrooms.map((room) {
        final isSelected = selected?.code == room.code;
        return GestureDetector(
          onTap: () => onSelect(room),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.blue : AppColors.border,
              ),
            ),
            child: Text(
              room.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}