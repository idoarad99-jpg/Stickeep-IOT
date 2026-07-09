import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descController = TextEditingController();

  final List<String> _tags = [
    'Seat broken',
    'Sensor issue',
    'Screen not working',
    'Accessibility issue',
    'Other',
  ];

  String? _selectedTag;
  bool _isLoading = false;

  // Location selection
  String? _selectedBuilding;
  String? _selectedClassroomId;
  String? _selectedSeatId;
  List<Map<String, dynamic>> _classrooms = [];
  List<String> _buildings = [];
  List<Map<String, dynamic>> _seatsInRoom = [];

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    final snap = await FirebaseFirestore.instance
        .collection('classrooms')
        .where('active', isEqualTo: true)
        .get();

    final classrooms = snap.docs.map((d) => {
          'id': d.id,
          'building': d.data()['building'] as String? ?? '',
          'roomName': d.data()['roomName'] as String? ?? '',
        }).toList();

    final buildings = <String>[];
    for (final c in classrooms) {
      if (!buildings.contains(c['building'])) {
        buildings.add(c['building'] as String);
      }
    }

    if (mounted) {
      setState(() {
        _classrooms = classrooms;
        _buildings = buildings;
      });
    }
  }

  Future<void> _loadSeats(String classroomId) async {
    final snap = await FirebaseFirestore.instance
        .collection('classrooms')
        .doc(classroomId)
        .collection('seats')
        .get();

    final seats = snap.docs.map((d) => {
          'id': d.id,
          'label': d.data()['label'] as String? ?? '',
        }).toList();

    if (mounted) setState(() => _seatsInRoom = seats);
  }

  List<Map<String, dynamic>> get _roomsInBuilding => _classrooms
      .where((c) => c['building'] == _selectedBuilding)
      .toList();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue type')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      String studentName = '';
      if (uid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('students')
            .doc(uid)
            .get();
        studentName = doc.data()?['name'] as String? ?? '';
      }

      // Find room name for display
      final selectedRoom = _classrooms
          .where((c) => c['id'] == _selectedClassroomId)
          .firstOrNull;
      final roomDisplay = selectedRoom != null
          ? '${selectedRoom['building']} ${selectedRoom['roomName']}'
          : '';

      await FirebaseDatabase.instance.ref('reports').push().set({
        'uid': uid,
        'student_name': studentName,
        'tag': _selectedTag,
        'description': _descController.text.trim(),
        'building': _selectedBuilding ?? '',
        'room': selectedRoom?['roomName'] ?? '',
        'seat': _selectedSeatId ?? '',
        'location_display': roomDisplay,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'open',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue type', style: AppTextStyles.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final selected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTag = tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.redLight : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.red : AppColors.border,
                      ),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.red
                              : AppColors.textPrimary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            Text('Location (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),

            // Building picker
            if (_buildings.isNotEmpty) ...[
              Text('Building',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildings.map((b) {
                  final selected = _selectedBuilding == b;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedBuilding = b;
                      _selectedClassroomId = null;
                      _selectedSeatId = null;
                      _seatsInRoom = [];
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.blueLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.blue
                              : AppColors.border,
                        ),
                      ),
                      child: Text(b,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? AppColors.blue
                                : AppColors.textPrimary,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Room picker
            if (_selectedBuilding != null &&
                _roomsInBuilding.isNotEmpty) ...[
              Text('Room',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roomsInBuilding.map((r) {
                  final selected = _selectedClassroomId == r['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedClassroomId = r['id'] as String;
                        _selectedSeatId = null;
                        _seatsInRoom = [];
                      });
                      _loadSeats(r['id'] as String);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.blueLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.blue
                              : AppColors.border,
                        ),
                      ),
                      child: Text(r['roomName'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? AppColors.blue
                                : AppColors.textPrimary,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Seat picker
            if (_selectedClassroomId != null &&
                _seatsInRoom.isNotEmpty) ...[
              Text('Seat',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _seatsInRoom.map((s) {
                  final id = s['id'] as String;
                  final label = s['label'] as String;
                  final selected = _selectedSeatId == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSeatId = id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.blueLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.blue
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                          label.isNotEmpty ? '$id ($label)' : id,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? AppColors.blue
                                : AppColors.textPrimary,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            Text('Description (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: 'Describe the issue...'),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
