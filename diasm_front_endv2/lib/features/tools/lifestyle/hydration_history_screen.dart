
import 'package:flutter/material.dart';

class HydrationHistoryScreen extends StatelessWidget {
  const HydrationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hydration History"),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Hydration history view will be added later.\n\n"
            "Currently, only today's total is shown on the "
            "Lifestyle Overview screen.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
