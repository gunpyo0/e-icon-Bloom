import 'package:bloom/ui/screens/fund/fund_create_screen.dart';
import 'package:bloom/ui/screens/fund/fund_screen.dart';
import 'package:bloom/ui/screens/fund/fund_detail_screen.dart';
import 'package:bloom/ui/screens/auth/login_screen.dart';
import 'package:bloom/ui/screens/auth/signup_screen.dart';
import 'package:bloom/ui/screens/profile/profile_screen.dart';
import 'package:bloom/ui/screens/garden/garden_screen.dart';
import 'package:bloom/ui/screens/learn/learn_screen.dart';
import 'package:bloom/ui/screens/evaluation/evaluation_screen.dart';
import 'package:bloom/ui/screens/eco_debug_page.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/screens/main/main_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isLoggedIn = EcoBackend.instance.currentUser != null;
    final isLoginRoute = state.uri.path == '/login';
    final isSignupRoute = state.uri.path == '/signup';
    
    if (!isLoggedIn && !isLoginRoute && !isSignupRoute) {
      return '/login';
    }
    if (isLoggedIn && (isLoginRoute || isSignupRoute)) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => MainScaffold(key: mainScaffoldKey),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/garden',
      builder: (context, state) => const GardenScreen(),
    ),
    GoRoute(
      path: '/learn',
      builder: (context, state) => const LearnScreen(),
    ),
    GoRoute(
      path: '/fund/create',
      builder: (context, state) => const FundCreateScreen(),
    ),
    GoRoute(
      path: '/fund/:fundId',
      builder: (context, state) {
        final fundId = state.pathParameters['fundId']!;
        return FundDetailScreen(fundId: fundId);
      },
    ),
    GoRoute(
      path: '/debug',
      builder: (context, state) => const EcoDebugPage(),
    ),

  ],
);

// GlobalKey for MainScaffold to access tab switching from anywhere
final GlobalKey<_MainScaffoldState> mainScaffoldKey = GlobalKey<_MainScaffoldState>();

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with TickerProviderStateMixin {
  int _index = 2; // 0: info, 1: garden, 2: main, 3: learn, 4: fund
  late PageController _pageController;
  late AnimationController _animationController;

  final pages = [
    const EvaluationScreen(),
    const GardenScreen(),
    const MainScreen(),
    const LearnScreen(),
    const FundScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_index != index) {
      setState(() => _index = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // External method to switch tabs
  void switchToTab(int index) {
    _onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(context),
          Container(
            height: 10,
            color: Color.fromRGBO(171, 101, 119, 1),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _index = index);
              },
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.post_add_outlined),
            selectedIcon: Icon(Icons.post_add),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.yard_outlined),
            selectedIcon: Icon(Icons.yard),
            label: 'Garden',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Main',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money_outlined),
            selectedIcon: Icon(Icons.attach_money),
            label: 'Fund',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Color.fromRGBO(54, 61, 56, 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BLOOM',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: "aggro",
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}