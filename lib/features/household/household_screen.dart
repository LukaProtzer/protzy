import 'package:flutter/material.dart';

class HouseholdScreen extends StatelessWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Haushalt"),
      ),
      body: const Center(
        child: Text(
          "👨‍👩‍👧 Haushalt\n\nKommt bald",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}