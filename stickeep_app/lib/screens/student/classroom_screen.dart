import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/student/seat_map_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  final List<String> _classrooms = ['Taub 1', 'Taub 2', 'Taub 3', 'Taub 4', 'Taub 5'];
  String? _selectedClassroom;
  DateTime? _selectedDate;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  final _lessonController = TextEditingController();

  @override
  void dispose() {
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
      appBar: AppBar(title: const Text('New Reservation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Classroom ──────────────────────────────────────────────────
            const Text('Classroom', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classrooms.map((room) {
                final selected = _selectedClassroom == room;
                return GestureDetector(
                  onTap: () => setState(() => _selectedClassroom = room),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.blue : AppColors.border,
                      ),
                    ),
                    child: Text(
                      room,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
                            classroom: _selectedClassroom!,
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