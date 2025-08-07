import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/providers/membership_provider.dart';

class LeafState {
  final int leafCount;
  final List<LeafPurchase> purchaseHistory;

  LeafState({
    this.leafCount = 0,
    this.purchaseHistory = const [],
  });

  LeafState copyWith({
    int? leafCount,
    List<LeafPurchase>? purchaseHistory,
  }) {
    return LeafState(
      leafCount: leafCount ?? this.leafCount,
      purchaseHistory: purchaseHistory ?? this.purchaseHistory,
    );
  }
}

class LeafPurchase {
  final int leafAmount;
  final double usdPrice;
  final DateTime purchaseDate;
  final String transactionId;
  final List<PhysicalItem> includedItems;

  LeafPurchase({
    required this.leafAmount,
    required this.usdPrice,
    required this.purchaseDate,
    required this.transactionId,
    required this.includedItems,
  });
}

class PhysicalItem {
  final String name;
  final String description;
  final String imageUrl;
  final bool isShipped;
  final String? trackingNumber;
  final DateTime? estimatedDelivery;

  PhysicalItem({
    required this.name,
    required this.description,
    required this.imageUrl,
    this.isShipped = false,
    this.trackingNumber,
    this.estimatedDelivery,
  });

  PhysicalItem copyWith({
    String? name,
    String? description,
    String? imageUrl,
    bool? isShipped,
    String? trackingNumber,
    DateTime? estimatedDelivery,
  }) {
    return PhysicalItem(
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isShipped: isShipped ?? this.isShipped,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
    );
  }
}

class LeafNotifier extends StateNotifier<LeafState> {
  static LeafState? _cachedState;
  final Ref ref;

  LeafNotifier(this.ref) : super(_cachedState ?? LeafState(leafCount: 100)) {
    _loadLeafState();
  }

  Future<void> _loadLeafState() async {
    if (_cachedState != null) {
      state = _cachedState!;
    }
  }

  Future<void> _saveLeafState() async {
    _cachedState = state;
  }

  // Purchase leaf packages with real money
  Future<void> purchaseLeafPackage(LeafPackage package) async {
    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate transaction ID
      final transactionId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create physical items based on package
      final physicalItems = _generatePhysicalItems(package);
      
      // Create purchase record
      final purchase = LeafPurchase(
        leafAmount: package.leafAmount,
        usdPrice: package.usdPrice,
        purchaseDate: DateTime.now(),
        transactionId: transactionId,
        includedItems: physicalItems,
      );
      
      // Check if user has premium membership for bonus leaves
      final membershipState = ref.read(membershipProvider);
      int bonusLeaves = 0;
      if (membershipState.isPremium) {
        bonusLeaves = (package.leafAmount * 0.2).round(); // 20% bonus for premium members
      }
      
      // Update state
      state = state.copyWith(
        leafCount: state.leafCount + package.leafAmount + bonusLeaves,
        purchaseHistory: [...state.purchaseHistory, purchase],
      );
      
      await _saveLeafState();
      
      // Schedule shipping (simulate)
      _scheduleShipping(purchase);
      
    } catch (e) {
      print('Error purchasing leaf package: $e');
      rethrow;
    }
  }

  void spendLeaves(int amount) {
    if (state.leafCount >= amount) {
      state = state.copyWith(
        leafCount: state.leafCount - amount,
      );
      _saveLeafState();
    }
  }

  void addLeaves(int amount) {
    state = state.copyWith(
      leafCount: state.leafCount + amount,
    );
    _saveLeafState();
  }

  List<PhysicalItem> _generatePhysicalItems(LeafPackage package) {
    final baseItems = [
      PhysicalItem(
        name: 'Mixed Vegetable Seeds',
        description: 'Organic seeds including tomatoes, carrots, and lettuce',
        imageUrl: 'assets/seeds_mixed.png',
        estimatedDelivery: DateTime.now().add(Duration(days: 5)),
      ),
      PhysicalItem(
        name: 'Bamboo Plant Markers',
        description: 'Set of 10 biodegradable plant markers',
        imageUrl: 'assets/plant_markers.png',
        estimatedDelivery: DateTime.now().add(Duration(days: 5)),
      ),
    ];

    // Add more items based on package size
    if (package.leafAmount >= 500) {
      baseItems.add(PhysicalItem(
        name: 'Eco-Friendly Watering Can',
        description: '2L recycled plastic watering can',
        imageUrl: 'assets/watering_can.png',
        estimatedDelivery: DateTime.now().add(Duration(days: 7)),
      ));
    }

    if (package.leafAmount >= 1000) {
      baseItems.add(PhysicalItem(
        name: 'Organic Compost Starter',
        description: '500g organic compost starter mix',
        imageUrl: 'assets/compost.png',
        estimatedDelivery: DateTime.now().add(Duration(days: 7)),
      ));
    }

    if (package.leafAmount >= 2000) {
      baseItems.add(PhysicalItem(
        name: 'Solar-Powered Garden Light',
        description: 'LED solar garden light with stake',
        imageUrl: 'assets/solar_light.png',
        estimatedDelivery: DateTime.now().add(Duration(days: 10)),
      ));
    }

    return baseItems;
  }

  void _scheduleShipping(LeafPurchase purchase) {
    // Simulate shipping process
    Future.delayed(Duration(hours: 24), () {
      // Mark items as shipped
      final updatedItems = purchase.includedItems.map((item) =>
        item.copyWith(
          isShipped: true,
          trackingNumber: 'ECO${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        ),
      ).toList();
      
      // Update purchase history
      final updatedHistory = state.purchaseHistory.map((p) {
        if (p.transactionId == purchase.transactionId) {
          return LeafPurchase(
            leafAmount: p.leafAmount,
            usdPrice: p.usdPrice,
            purchaseDate: p.purchaseDate,
            transactionId: p.transactionId,
            includedItems: updatedItems,
          );
        }
        return p;
      }).toList();
      
      state = state.copyWith(purchaseHistory: updatedHistory);
      _saveLeafState();
    });
  }

  // Get recent purchases
  List<LeafPurchase> get recentPurchases => 
    state.purchaseHistory.reversed.take(5).toList();

  // Get pending shipments
  List<PhysicalItem> get pendingShipments => 
    state.purchaseHistory
      .expand((purchase) => purchase.includedItems)
      .where((item) => !item.isShipped)
      .toList();

  // Get shipped items
  List<PhysicalItem> get shippedItems => 
    state.purchaseHistory
      .expand((purchase) => purchase.includedItems)
      .where((item) => item.isShipped)
      .toList();
}

class LeafPackage {
  final String name;
  final int leafAmount;
  final double usdPrice;
  final String description;
  final String badge;
  final bool isPopular;
  final double? originalPrice;

  LeafPackage({
    required this.name,
    required this.leafAmount,
    required this.usdPrice,
    required this.description,
    required this.badge,
    this.isPopular = false,
    this.originalPrice,
  });

  double get leafPerDollar => leafAmount / usdPrice;
  double get savings => originalPrice != null ? originalPrice! - usdPrice : 0;
  int get savingsPercent => originalPrice != null ? 
    ((savings / originalPrice!) * 100).round() : 0;
}

// Available leaf packages
final leafPackages = [
  LeafPackage(
    name: 'Starter Pack',
    leafAmount: 100,
    usdPrice: 0.99,
    description: 'Perfect for beginners',
    badge: 'STARTER',
  ),
  LeafPackage(
    name: 'Garden Pack',
    leafAmount: 500,
    usdPrice: 3.99,
    originalPrice: 4.95,
    description: 'Great value for regular players',
    badge: 'POPULAR',
    isPopular: true,
  ),
  LeafPackage(
    name: 'Eco Pack',
    leafAmount: 1000,
    usdPrice: 6.99,
    originalPrice: 9.90,
    description: 'Best for dedicated gardeners',
    badge: 'VALUE',
  ),
  LeafPackage(
    name: 'Premium Pack',
    leafAmount: 2500,
    usdPrice: 14.99,
    originalPrice: 24.75,
    description: 'Maximum leaves with premium items',
    badge: 'PREMIUM',
  ),
  LeafPackage(
    name: 'Mega Pack',
    leafAmount: 5000,
    usdPrice: 24.99,
    originalPrice: 49.50,
    description: 'Ultimate package for serious eco-warriors',
    badge: 'ULTIMATE',
  ),
];

final leafProvider = StateNotifierProvider<LeafNotifier, LeafState>((ref) {
  return LeafNotifier(ref);
});