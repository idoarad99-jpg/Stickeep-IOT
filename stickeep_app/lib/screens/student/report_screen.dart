import 'package:stickeep_app/screens/student/classroom_screen.dart';

ElevatedButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ClassroomScreen()),
  ),
  child: const Text('🪑  New reservation'),
),