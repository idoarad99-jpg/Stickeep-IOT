import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ConfirmScreen extends StatelessWidget {
  final String classroom;
  final String lessonName;
  final String date;
  final String timeStart;
  final String timeEnd;
  final int seatNumber;
  final DatabaseReference seatsRef;

  const ConfirmScreen({
    super.key,
    required this.classroom,
    required this.lessonName,
    required this.date,
    required this.timeStart,
    required this.timeEnd,
    required this.seatNumber,
    required this.seatsRef,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Reservation')),
      body: const Center(child: Text('Confirm screen coming soon...')),
    );
  }
}