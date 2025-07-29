import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 임시
    const username = "UserName";
    const totalPoints = 350;
    const eduPoints = 200;
    const jobPoints = 150;

    return Scaffold(
      appBar: AppBar(title: const Text('BLOOM')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 임시
            Expanded(
              flex: 2,
              child: Container(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text("#3 $username", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text("$totalPoints P", style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text("edu $eduPoints + job $jobPoints"),
          ],
        ),
      ),
    );
  }
}
