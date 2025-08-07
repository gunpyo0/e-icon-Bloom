import 'package:flutter_riverpod/flutter_riverpod.dart';

class MembershipState {
  final bool isPremium;
  final String membershipType;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final double paidAmount;

  MembershipState({
    this.isPremium = false,
    this.membershipType = 'Free',
    this.purchaseDate,
    this.expiryDate,
    this.paidAmount = 0.0,
  });

  MembershipState copyWith({
    bool? isPremium,
    String? membershipType,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? paidAmount,
  }) {
    return MembershipState(
      isPremium: isPremium ?? this.isPremium,
      membershipType: membershipType ?? this.membershipType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPremium': isPremium,
      'membershipType': membershipType,
      'purchaseDate': purchaseDate?.millisecondsSinceEpoch,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'paidAmount': paidAmount,
    };
  }

  factory MembershipState.fromJson(Map<String, dynamic> json) {
    return MembershipState(
      isPremium: json['isPremium'] ?? false,
      membershipType: json['membershipType'] ?? 'Free',
      purchaseDate: json['purchaseDate'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['purchaseDate'])
        : null,
      expiryDate: json['expiryDate'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['expiryDate'])
        : null,
      paidAmount: json['paidAmount']?.toDouble() ?? 0.0,
    );
  }

  bool get isExpired {
    if (!isPremium) return false;
    if (expiryDate == null) return false; // Lifetime membership
    return DateTime.now().isAfter(expiryDate!);
  }

  String get vipTitle {
    if (!isPremium) return '';
    if (membershipType.contains('Lifetime')) return 'PREMIUM VIP';
    if (membershipType.contains('Yearly')) return 'GOLD VIP';
    if (membershipType.contains('Monthly')) return 'VIP';
    return 'VIP';
  }
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  // In-memory storage for demo purposes
  static MembershipState? _cachedState;
  
  MembershipNotifier() : super(_cachedState ?? MembershipState()) {
    _loadMembershipState();
  }

  Future<void> _loadMembershipState() async {
    // For now, just check if we have cached state and if it's expired
    if (_cachedState != null) {
      if (_cachedState!.isExpired) {
        // Expire the membership
        state = _cachedState!.copyWith(
          isPremium: false,
          membershipType: 'Free',
        );
        _saveMembershipState();
      } else {
        state = _cachedState!;
      }
    }
  }

  Future<void> _saveMembershipState() async {
    // Cache the state in memory
    _cachedState = state;
    
    // In a real app, you would save to persistent storage here
    // For now, we'll just keep it in memory for the session
  }

  Future<void> purchaseMembership(String type, double price) async {
    try {
      final now = DateTime.now();
      DateTime? expiryDate;
      String membershipType;

      switch (type.toLowerCase()) {
        case 'monthly':
          membershipType = 'Monthly Premium';
          expiryDate = now.add(const Duration(days: 30));
          break;
        case 'yearly':
          membershipType = 'Yearly Premium';
          expiryDate = now.add(const Duration(days: 365));
          break;
        case 'lifetime':
          membershipType = 'Lifetime Premium';
          expiryDate = null; // No expiry for lifetime
          break;
        default:
          membershipType = 'Monthly Premium';
          expiryDate = now.add(const Duration(days: 30));
      }

      state = state.copyWith(
        isPremium: true,
        membershipType: membershipType,
        purchaseDate: now,
        expiryDate: expiryDate,
        paidAmount: price,
      );

      await _saveMembershipState();
      
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      print('Error purchasing membership: $e');
      rethrow;
    }
  }

  Future<void> cancelMembership() async {
    state = state.copyWith(
      isPremium: false,
      membershipType: 'Free',
      expiryDate: null,
    );
    
    await _saveMembershipState();
  }

  void checkMembershipExpiry() {
    if (state.isExpired) {
      state = state.copyWith(
        isPremium: false,
        membershipType: 'Free',
      );
      _saveMembershipState();
    }
  }

  // Helper methods for benefits
  bool get canAccessPremiumFeatures => state.isPremium && !state.isExpired;
  bool get hasDoublePoints => canAccessPremiumFeatures;
  bool get hasPremiumPlants => canAccessPremiumFeatures;
  bool get hasPrioritySupport => canAccessPremiumFeatures;
  bool get hasAdvancedAnalytics => canAccessPremiumFeatures;
  bool get hasExclusiveProducts => canAccessPremiumFeatures;
  
  String get displayTitle => state.vipTitle;
}

final membershipProvider = StateNotifierProvider<MembershipNotifier, MembershipState>(
  (ref) => MembershipNotifier(),
);