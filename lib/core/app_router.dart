import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/screens/main/main_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(),
    ),
  ],
);

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 2;

  final pages = [
  const Center(child: Text('Info')),
  const Center(child: Text('Garden')),
  const Center(child: Text('Main')), 
  const Center(child: Text('Learn')),
  const Center(child: Text('Fund')),
];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info), label: 'Info'),
          NavigationDestination(icon: Icon(Icons.yard), label: 'Garden'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Main'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Fund'),
        ],
      ),
    );
  }
}