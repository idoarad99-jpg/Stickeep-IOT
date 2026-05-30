import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // אתחול Firebase עם הנתונים המדויקים מהמסך שלך!
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCjbSpVQLYr1h6z1NpsXRMQppizFI392og',
      appId: '1:533886545260:web:05d58c3e975ee7ee439749',
      messagingSenderId: '533886545260',
      projectId: 'stickeep',
      storageBucket: 'stickeep.firebasestorage.app',
      databaseURL: 'https://stickeep-default-rtdb.firebaseio.com',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Stickeep Test',
      home: FirebaseTestScreen(),
    );
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  // חיבור ישיר למשתנה שיצרת בענן
  final DatabaseReference _statusRef =
      FirebaseDatabase.instance.ref('chair_status');
  String _currentStatus = "Loading...";

  @override
  void initState() {
    super.initState();
    _activateStatusListener();
  }

  void _activateStatusListener() {
    // האזנה בזמן אמת לשינויים בענן (Observer Pattern)
    _statusRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;

      // הדפסה לקונסול של המחשב (דרישת המשימה בשבוע 1!)
      print('--- [Firebase Update] chair_status current value is: $data ---');

      setState(() {
        _currentStatus = data?.toString() ?? "No data";
      });
    }, onError: (error) {
      print('Error listening to database: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stickeep Integration 0'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chair Status from Cloud:',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _currentStatus,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _currentStatus == "free" ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Check your VS Code Debug Console to see the exact print logs!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
