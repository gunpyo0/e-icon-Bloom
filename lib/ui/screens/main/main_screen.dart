import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/models/crop.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/ui/screens/garden/garden_screen.dart';
import 'package:bloom/ui/screens/profile/profile_screen.dart';
import 'package:bloom/providers/points_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/core/app_router.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // 화면이 재생성되도록 함
  int userRank = 0;
  bool isLoading = true;
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    
    // 포인트 초기 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pointsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 포인트 새로고침
      ref.read(pointsProvider.notifier).refresh();
    }
  }

  Future<void> _loadData() async {
    try {
      // Load user league rank (consistent with profile screen)
      final leagueData = await EcoBackend.instance.myLeague();
      final rank = leagueData['rank'] ?? 0;
      
      // Load user profile for name
      final profileData = await EcoBackend.instance.myProfile();
      final name = profileData['displayName'] ?? 
                   profileData['name'] ?? 
                   EcoBackend.instance.currentUser?.displayName ?? 
                   EcoBackend.instance.currentUser?.email?.split('@')[0] ??
                   'User';
      
      setState(() {
        userRank = rank;
        userName = name;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        userRank = 0;
        userName = 'User';
        isLoading = false;
      });
    }
  }

    Map<String, String> _getDailyQuote() {
    final quotes = [
      {
        "quote": '"The Earth does not belong to us; we belong to the Earth."',
        "author": "Chief Seattle"
      },
      {
        "quote": '"Climate change is no longer some far-off problem; it is happening here, it is happening now."',
        "author": "Barack Obama"
      },
      {
        "quote": '"The greatest threat to our planet is the belief that someone else will save it."',
        "author": "Robert Swan"
      },
      {
        "quote": '"We don\'t inherit the Earth from our ancestors; we borrow it from our children."',
        "author": "Native American Proverb"
      },
      {
        "quote": '"The time for action is now. We cannot afford to be indifferent or complacent."',
        "author": "Greta Thunberg"
      },
      {
        "quote": '"A nation that destroys its soils destroys itself. Forests are the lungs of our land."',
        "author": "Franklin D. Roosevelt"
      },
      {
        "quote": '"The environment is where we all meet; where we all have a mutual interest."',
        "author": "Lady Bird Johnson"
      },
      {
        "quote": '"What we are doing to the forests of the world is but a mirror reflection of what we are doing to ourselves."',
        "author": "Mahatma Gandhi"
      },
      {
        "quote": '"Climate action is a global necessity, not a choice."',
        "author": "Ban Ki-moon"
      },
      {
        "quote": '"The good man is the friend of all living things."',
        "author": "Mahatma Gandhi"
      },
    ];
    
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필요
    
    final pointsAsync = ref.watch(pointsProvider);
    
    // 디버그: 포인트 상태 로그
    pointsAsync.when(
      data: (points) => print('MainScreen - Points: $points'),
      loading: () => print('MainScreen - Points loading'),
      error: (error, _) => print('MainScreen - Points error: $error'),
    );
    return Scaffold(
      resizeToAvoidBottomInset : false,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: () async {
                await ref.read(pointsProvider.notifier).refresh();
                await _loadData();
              },
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Quote
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromRGBO(120, 170, 120, 1),
                          Color.fromRGBO(100, 150, 100, 1),
                          Color.fromRGBO(85, 130, 85, 1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(120, 170, 120, 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background decorative elements
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.03),
                            ),
                          ),
                        ),
                        // Main content
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.format_quote,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Daily Inspiration',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _getDailyQuote()['quote']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '— ${_getDailyQuote()['author']!}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // My Garden Section Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.eco,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'My Garden',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Virtual Ecosystem',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // My Garden Section - Simple & Pretty
                  GestureDetector(
                    onTap: () {
                      mainScaffoldKey.currentState?.switchToTab(1); // Garden tab index
                    },
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.fromRGBO(76, 175, 80, 1),
                            Color.fromRGBO(139, 195, 74, 1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(76, 175, 80, 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Left side - Greeting
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hello! $userName',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(0, 1),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Welcome to your garden',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.grass,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '3 plants growing',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Right side - Beautiful Garden Image
                            Expanded(
                              flex: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Stack(
                                    children: [
                                      // Placeholder garden image background
                                      Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color.fromRGBO(46, 125, 50, 0.8),
                                              Color.fromRGBO(27, 94, 32, 0.9),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Garden elements
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Icon(
                                          Icons.local_florist,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 20,
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Icon(
                                          Icons.eco,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 18,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        right: 8,
                                        child: Icon(
                                          Icons.spa,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 16,
                                        ),
                                      ),
                                      // Center garden icon
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.nature_people,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats Section Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.analytics,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Your Progress',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            'Live Stats',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ranking information and Currency side by side
                  Row(
                    children: [
                      // Ranking information (left side)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromRGBO(72, 187, 120, 1),   // 바이옴과 유사한 톤
                                Color.fromRGBO(52, 168, 83, 1),    // 중간 톤
                                Color.fromRGBO(39, 174, 96, 1),    // 프로덕트와 유사한 톤
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(52, 168, 83, 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Color.fromRGBO(39, 174, 96, 1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Ranking',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Rank $userRank',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Navigate to ranking screen
                                },
                                child: Text(
                                  'View More',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Currency display (right side)
                      GestureDetector(
                        onTap: () {
                          // 포인트 표시를 탭하면 새로고침
                          ref.read(pointsProvider.notifier).refresh();
                        },
                        child: pointsAsync.when(
                          data: (totalPoints) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.green.shade400,
                                    Colors.green.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco, color: Colors.white, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$totalPoints',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade300,
                                  Colors.grey.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.eco, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                          error: (_, __) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.eco, color: Colors.white, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Explore Section Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.explore,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Explore',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            'Interactive Features',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Biome - First row
                  _buildBiomeCard(
                    icon: Icons.public,
                    title: 'Biome',
                    subtitle: 'Explore Earth Ecosystems',
                    onTap: () {
                      mainScaffoldKey.currentState?.switchToTab(3); // Learn tab index
                    },
                  ),

                  const SizedBox(height: 12),

                  // Membership - Second row
                  _buildMembershipCard(
                    icon: Icons.card_membership,
                    title: 'Membership',
                    subtitle: 'Unlock Premium Features',
                    onTap: () {
                      // Navigate to membership screen
                    },
                  ),

                  const SizedBox(height: 12),

                  // Product Store - Second row
                  _buildProductCard(
                    icon: Icons.eco,
                    title: 'Product',
                    subtitle: 'Purchase Leaves & Eco Products',
                    onTap: () {
                      context.push('/product');
                    },
                  ),

                  const SizedBox(height: 12),

                  // CO2 Emissions - Third row
                  _buildCO2Card(
                    icon: Icons.cloud,
                    title: 'CO₂ Emissions',
                    subtitle: 'Track Your Carbon Footprint',
                    onTap: () {
                      // Navigate to CO2 tracking screen
                    },
                  ),
                ], // children 리스트 닫기
              ), // Column 닫기
              ), // SingleChildScrollView 닫기
        ), // RefreshIndicator 닫기
      ), // Container 닫기
    ); // Scaffold 닫기
  } // build() 메서드 닫기

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(120, 170, 120, 1),
            Color.fromRGBO(100, 150, 100, 1),
            Color.fromRGBO(85, 130, 85, 1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(120, 170, 120, 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiomeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(41, 128, 185, 1),  // Vibrant ocean blue
            Color.fromRGBO(52, 152, 219, 1),
            Color.fromRGBO(155, 89, 182, 1),  // Purple accent
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(52, 152, 219, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(142, 68, 173, 1),   // Premium purple
            Color.fromRGBO(155, 89, 182, 1),
            Color.fromRGBO(243, 156, 18, 1),   // Golden accent
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(142, 68, 173, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(46, 204, 113, 1),   // Emerald green
            Color.fromRGBO(39, 174, 96, 1),
            Color.fromRGBO(22, 160, 133, 1),   // Teal accent
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(46, 204, 113, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.nature,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Go Green',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCO2Card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(52, 73, 94, 1),     // Dark slate
            Color.fromRGBO(44, 62, 80, 1),
            Color.fromRGBO(26, 188, 156, 1),   // Turquoise accent
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(52, 73, 94, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '2.4kg',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'today',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

} // _MainScreenState 클래스 닫기


class GardenPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw subtle leaf patterns
    for (int i = 0; i < 8; i++) {
      final x = (size.width / 8) * i + (size.width / 16);
      final y = size.height * 0.3 + (i % 2) * 20;
      
      // Simple leaf shape using path
      final path = Path();
      path.moveTo(x, y);
      path.quadraticBezierTo(x + 10, y - 8, x + 20, y);
      path.quadraticBezierTo(x + 10, y + 8, x, y);
      path.close();
      
      canvas.drawPath(path, paint);
    }
    
    // Add some circle patterns
    for (int i = 0; i < 5; i++) {
      final x = (size.width / 5) * i;
      final y = size.height * 0.7;
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
