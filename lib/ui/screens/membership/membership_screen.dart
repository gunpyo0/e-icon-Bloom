import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/providers/membership_provider.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membershipState = ref.watch(membershipProvider);
    
    return Scaffold(
      backgroundColor: const Color.fromRGBO(15, 15, 30, 1),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(15, 15, 30, 1),
              Color.fromRGBO(25, 25, 50, 1),
              Color.fromRGBO(35, 35, 70, 1),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Premium Membership',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Current Status Card
                    if (membershipState.isPremium) ...[
                      _buildCurrentStatusCard(membershipState),
                      const SizedBox(height: 30),
                    ],
                    
                    // Premium Benefits Section
                    _buildBenefitsSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Membership Plans
                    _buildMembershipPlans(membershipState),
                    
                    const SizedBox(height: 30),
                    
                    // Terms and FAQ
                    _buildFooterSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(MembershipState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(255, 215, 0, 0.9),
            Color.fromRGBO(255, 193, 7, 0.9),
            Color.fromRGBO(255, 152, 0, 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(255, 215, 0, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'PREMIUM MEMBER',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'VIP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.membershipType,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Valid Until',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  state.expiryDate?.toString().split(' ')[0] ?? 'Lifetime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = [
      {
        'icon': Icons.eco,
        'title': 'Double Eco Points',
        'description': 'Earn 2x points for all eco-friendly activities',
      },
      {
        'icon': Icons.local_florist,
        'title': 'Premium Plants',
        'description': 'Access to exclusive rare plant varieties',
      },
      {
        'icon': Icons.star,
        'title': 'VIP Badge',
        'description': 'Show off your premium status with special badge',
      },
      {
        'icon': Icons.priority_high,
        'title': 'Priority Support',
        'description': 'Get faster response from our support team',
      },
      {
        'icon': Icons.trending_up,
        'title': 'Advanced Analytics',
        'description': 'Detailed insights into your eco impact',
      },
      {
        'icon': Icons.shopping_bag,
        'title': 'Exclusive Products',
        'description': 'Access to premium eco-friendly products',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Benefits',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        ...benefits.map((benefit) => _buildBenefitItem(
          benefit['icon'] as IconData,
          benefit['title'] as String,
          benefit['description'] as String,
        )).toList(),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(255, 215, 0, 0.8),
                  Color.fromRGBO(255, 193, 7, 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipPlans(MembershipState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        
        // Monthly Plan
        _buildPlanCard(
          title: 'Monthly Premium',
          price: '\$4.99',
          period: '/month',
          features: [
            'All premium benefits',
            'Cancel anytime',
            'Instant activation',
          ],
          isPopular: false,
          onTap: () => _purchaseMembership('monthly', 4.99),
          isActive: state.isPremium && state.membershipType == 'Monthly Premium',
        ),
        
        const SizedBox(height: 16),
        
        // Yearly Plan (Popular)
        _buildPlanCard(
          title: 'Yearly Premium',
          price: '\$49.99',
          period: '/year',
          originalPrice: '\$59.88',
          discount: 'Save 17%',
          features: [
            'All premium benefits',
            '2 months free',
            'Best value',
            'Priority support',
          ],
          isPopular: true,
          onTap: () => _purchaseMembership('yearly', 49.99),
          isActive: state.isPremium && state.membershipType == 'Yearly Premium',
        ),
        
        const SizedBox(height: 16),
        
        // Lifetime Plan
        _buildPlanCard(
          title: 'Lifetime Premium',
          price: '\$99.99',
          period: 'one-time',
          features: [
            'All premium benefits',
            'No recurring payments',
            'Lifetime access',
            'Future updates included',
          ],
          isPopular: false,
          onTap: () => _purchaseMembership('lifetime', 99.99),
          isActive: state.isPremium && state.membershipType == 'Lifetime Premium',
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    String? originalPrice,
    String? discount,
    required List<String> features,
    required bool isPopular,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isPopular 
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(255, 215, 0, 0.2),
                Color.fromRGBO(255, 193, 7, 0.1),
              ],
            )
          : null,
        color: isPopular ? null : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular 
            ? Color.fromRGBO(255, 215, 0, 0.5)
            : Colors.white.withOpacity(0.1),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(255, 215, 0, 1),
                      Color.fromRGBO(255, 193, 7, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'POPULAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              price,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isPopular 
                                  ? Color.fromRGBO(255, 215, 0, 1)
                                  : Colors.white,
                              ),
                            ),
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        if (originalPrice != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                originalPrice,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.5),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (discount != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    discount,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade300,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade300,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Features
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isPopular 
                          ? Color.fromRGBO(255, 215, 0, 1)
                          : Colors.green.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                
                const SizedBox(height: 24),
                
                // Purchase Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isActive ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive 
                        ? Colors.grey.withOpacity(0.3)
                        : isPopular 
                          ? Color.fromRGBO(255, 215, 0, 1)
                          : Colors.white.withOpacity(0.9),
                      foregroundColor: isActive 
                        ? Colors.white.withOpacity(0.5)
                        : isPopular 
                          ? Colors.black
                          : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isPopular ? 8 : 4,
                    ),
                    child: Text(
                      isActive 
                        ? 'CURRENT PLAN' 
                        : 'GET PREMIUM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Can I cancel anytime?',
                'Yes, you can cancel your subscription at any time from your account settings.',
              ),
              _buildFAQItem(
                'What happens to my benefits if I cancel?',
                'Your premium benefits will remain active until the end of your current billing period.',
              ),
              _buildFAQItem(
                'Is my payment secure?',
                'Yes, all payments are processed securely through encrypted payment gateways.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'By purchasing, you agree to our Terms of Service and Privacy Policy',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _purchaseMembership(String type, double price) {
    // Show purchase dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color.fromRGBO(25, 25, 50, 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Confirm Purchase',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Purchase ${type} membership for \$${price.toStringAsFixed(2)}?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processPurchase(type, price);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(255, 215, 0, 1),
              foregroundColor: Colors.black,
            ),
            child: Text('Purchase'),
          ),
        ],
      ),
    );
  }

  void _processPurchase(String type, double price) {
    // Simulate purchase processing
    ref.read(membershipProvider.notifier).purchaseMembership(type, price);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome to Premium! Your membership is now active.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}