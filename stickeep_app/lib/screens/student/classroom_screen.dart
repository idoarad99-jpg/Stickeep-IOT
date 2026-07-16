import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/models/classroom.dart';
import 'package:stickeep_app/screens/student/seat_map_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/screens/student/home_screen.dart';
import 'package:stickeep_app/utils/page_route.dart';

// Used if Firestore's classrooms/ collection can't be loaded (missing
// composite index, permissions error, or the query simply times out).
List<Classroom> _fallbackClassrooms() {
  return [
    Classroom(id: 'T1', building: 'Taub', roomName: '1', order: 1, active: true),
    Classroom(id: 'T2', building: 'Taub', roomName: '2', order: 2, active: true),
    Classroom(id: 'T3', building: 'Taub', roomName: '3', order: 3, active: true),
    Classroom(id: 'T4', building: 'Taub', roomName: '4', order: 4, active: true),
    Classroom(id: 'T5', building: 'Taub', roomName: '5', order: 5, active: true),
  ];
}

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  Classroom? _selectedClassroom;
  String? _selectedBuilding;
  DateTime? _selectedDate;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  final _lessonController = TextEditingController();

  List<Classroom>? _classrooms;
  bool _classroomsFallback = false;
  String? _classroomsError;
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

    // Filtering 'active' client-side (rather than chaining
    // .where('active', ...).orderBy('order') server-side) avoids needing a
    // composite Firestore index for this tiny collection — that combination
    // throws FAILED_PRECONDITION without one, which is what was silently
    // triggering the hardcoded fallback list below.
    _classroomsSub = FirebaseFirestore.instance
        .collection('classrooms')
        .orderBy('order')
        .snapshots()
        .listen(
      (snapshot) {
        _classroomsTimeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _classrooms = snapshot.docs
              .map(Classroom.fromDoc)
              .where((c) => c.active)
              .toList();
          _classroomsFallback = false;
        });
      },
      onError: (e) {
        _classroomsTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _classroomsFallback = true;
            _classroomsError = e.toString();
          });
        }
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
          tooltip: 'Home',
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            AppPageRoute(builder: (_) => const HomeScreen(userName: '', userRole: '')),
            (route) => false,
          ),
        ),title: const Text('New Reservation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BookingStepIndicator(
              step: 1,
              totalSteps: 3,
              label: 'Classroom & time',
            ),
            const SizedBox(height: 20),
            // ── Classroom ──────────────────────────────────────────────────
            Text('Classroom', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              if (_classroomsFallback) {
                final fallback = _fallbackClassrooms();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_classroomsError != null) ...[
                      Text(
                        'Couldn\'t load classrooms live — showing a fallback list. '
                        '($_classroomsError)',
                        style: TextStyle(color: AppColors.red, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: fallback.map((room) {
                        final selected = _selectedClassroom?.id == room.id;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: room.displayName,
                          child: GestureDetector(
                          onTap: () => setState(() => _selectedClassroom = room),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.blue : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? AppColors.blue : AppColors.border,
                              ),
                            ),
                            child: Text(
                              room.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:
                                    selected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ));
                      }).toList(),
                    ),
                  ],
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
                return Text(
                  'No classrooms available yet. Ask an admin to add one.',
                  style: AppTextStyles.cardSubtitle,
                );
              }

              final buildings = <String>[];
              for (final c in _classrooms!) {
                if (!buildings.contains(c.building)) buildings.add(c.building);
              }

              final selectedBuilding =
                  (_selectedBuilding != null && buildings.contains(_selectedBuilding))
                      ? _selectedBuilding!
                      : buildings.first;

              final roomsInBuilding =
                  _classrooms!.where((c) => c.building == selectedBuilding).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (buildings.isNotEmpty) ...[
                    Text('Building', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: buildings.map((building) {
                        final selected = building == selectedBuilding;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: '$building building',
                          child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedBuilding = building;
                            _selectedClassroom = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.textPrimary : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              building,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ));
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Room', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: roomsInBuilding.map((room) {
                      final selected = _selectedClassroom?.id == room.id;
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: room.roomName,
                        child: GestureDetector(
                        onTap: () => setState(() => _selectedClassroom = room),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.blue : AppColors.border,
                            ),
                          ),
                          child: Text(
                            room.roomName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ));
                    }).toList(),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),

            // ── Lesson name ────────────────────────────────────────────────
            Text('Lesson name (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextField(
              controller: _lessonController,
              decoration: const InputDecoration(hintText: 'e.g. Data Structures'),
            ),
            const SizedBox(height: 20),

            // ── Date ───────────────────────────────────────────────────────
            Text('Date', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: _selectedDate == null
                  ? 'Date, not selected'
                  : 'Date, ${_formatDate(_selectedDate!)}',
              child: GestureDetector(
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
                    Icon(Icons.calendar_today_outlined,
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
            )),
            const SizedBox(height: 20),

            // ── Time ───────────────────────────────────────────────────────
            Text('Time', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _timeStart == null
                        ? 'Start time, not selected'
                        : 'Start time, ${_formatTime(_timeStart!)}',
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
                          Icon(Icons.access_time_outlined,
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
                  )),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _timeEnd == null
                        ? 'End time, not selected'
                        : 'End time, ${_formatTime(_timeEnd!)}',
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
                          Icon(Icons.access_time_outlined,
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
                  )),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Next ───────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _canProceed
                  ? () => Navigator.push(
                        context,
                        AppPageRoute(
                          builder: (_) => SeatMapScreen(
                            classroomDisplayName: _selectedClassroom!.displayName,
                            classroomId: _selectedClassroom!.id,
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