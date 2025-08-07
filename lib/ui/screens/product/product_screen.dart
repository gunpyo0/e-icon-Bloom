import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key});

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  int selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.brown[800]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Eco Store',
          style: TextStyle(
            color: Colors.brown[800],
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.brown[800]),
            onPressed: () {
              // Navigate to cart
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'Game Items',
                    Icons.games,
                    0,
                    'Purchase with game points',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton(
                    'Eco Products',
                    Icons.eco,
                    1,
                    'Real products delivered',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content area
          Expanded(
            child: selectedTabIndex == 0
                ? _buildGameItemsTab()
                : _buildEcoProductsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon, int index, String subtitle) {
    final isSelected = selectedTabIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    Color.fromRGBO(156, 39, 176, 1),
                    Color.fromRGBO(123, 31, 162, 1),
                  ]
                : [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color.fromRGBO(156, 39, 176, 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey[600],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameItemsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green[400]!,
                  Colors.green[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.videogame_asset, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Currency & Items',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Use your eco points or purchase with real money',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Game items grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _gameItems.length,
              itemBuilder: (context, index) {
                final item = _gameItems[index];
                return _buildGameItemCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoProductsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.brown[400]!,
                  Colors.brown[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real Eco Products',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Purchase real eco-friendly products delivered to your door',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Eco products list
          Expanded(
            child: ListView.builder(
              itemCount: _ecoProducts.length,
              itemBuilder: (context, index) {
                final product = _ecoProducts[index];
                return _buildEcoProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameItemCard(GameItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showGameItemDialog(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Item icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.color.withOpacity(0.2),
                        item.color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, color: item.color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price}P',
                        style: TextStyle(
                          color: item.color,
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

  Widget _buildEcoProductCard(EcoProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEcoProductDialog(product),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product image/icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[100]!,
                        Colors.green[50]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    product.icon,
                    color: Colors.green[700],
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Free Shipping',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '3-5 days delivery',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  children: [
                    Text(
                      '\$${product.price}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGameItemDialog(GameItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(item.icon, color: item.color),
              const SizedBox(width: 8),
              Text(item.name),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.description),
              const SizedBox(height: 16),
              Text(
                'Price: ${item.price} Eco Points',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _purchaseGameItem(item);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: item.color,
                foregroundColor: Colors.white,
              ),
              child: Text('Purchase'),
            ),
          ],
        );
      },
    );
  }

  void _showEcoProductDialog(EcoProduct product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(product.icon, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(product.name),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.description),
              const SizedBox(height: 16),
              Text(
                'Price: \$${product.price}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown[800],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Free shipping included\n• 3-5 business days delivery\n• Eco-friendly packaging',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _purchaseEcoProduct(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Buy Now'),
            ),
          ],
        );
      },
    );
  }

  void _purchaseGameItem(GameItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} purchased successfully!'),
        backgroundColor: item.color,
      ),
    );
  }

  void _purchaseEcoProduct(EcoProduct product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ordered! You will receive tracking info soon.'),
        backgroundColor: Colors.green[600],
      ),
    );
  }
}

// Game Items Data
class GameItem {
  final String name;
  final String description;
  final int price;
  final IconData icon;
  final Color color;

  GameItem({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.color,
  });
}

class EcoProduct {
  final String name;
  final String description;
  final double price;
  final IconData icon;

  EcoProduct({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
  });
}

// Sample data
final List<GameItem> _gameItems = [
  GameItem(
    name: 'Seed Pack',
    description: 'Premium seeds for faster growth',
    price: 100,
    icon: Icons.grass,
    color: Colors.green,
  ),
  GameItem(
    name: 'Fertilizer',
    description: 'Boost plant growth by 50%',
    price: 150,
    icon: Icons.science,
    color: Colors.orange,
  ),
  GameItem(
    name: 'Water Can',
    description: 'Auto-water plants for 24h',
    price: 80,
    icon: Icons.water_drop,
    color: Colors.blue,
  ),
  GameItem(
    name: 'Garden Plot',
    description: 'Expand your garden space',
    price: 300,
    icon: Icons.crop_landscape,
    color: Colors.brown,
  ),
  GameItem(
    name: 'Solar Panel',
    description: 'Generate eco points passively',
    price: 500,
    icon: Icons.solar_power,
    color: Colors.yellow[700]!,
  ),
  GameItem(
    name: 'Compost Bin',
    description: 'Recycle waste into fertilizer',
    price: 200,
    icon: Icons.recycling,
    color: Colors.green[800]!,
  ),
];

final List<EcoProduct> _ecoProducts = [
  EcoProduct(
    name: 'Organic Tomato Seeds',
    description: 'Heirloom organic tomato seeds, pack of 20 seeds. Perfect for home gardening.',
    price: 12.99,
    icon: Icons.local_florist,
  ),
  EcoProduct(
    name: 'Bamboo Planter Set',
    description: 'Sustainable bamboo planters with drainage. Set of 3 different sizes.',
    price: 29.99,
    icon: Icons.plumbing,
  ),
  EcoProduct(
    name: 'Eco-Friendly Soil',
    description: 'Organic compost-enriched soil, 5kg bag. Perfect for vegetable gardens.',
    price: 19.99,
    icon: Icons.grass,
  ),
  EcoProduct(
    name: 'Solar Garden Light',
    description: 'LED solar-powered garden lights. Set of 4 waterproof lights.',
    price: 39.99,
    icon: Icons.wb_sunny,
  ),
  EcoProduct(
    name: 'Seed Starter Kit',
    description: 'Complete kit with biodegradable pots, soil, and mixed vegetable seeds.',
    price: 24.99,
    icon: Icons.eco,
  ),
  EcoProduct(
    name: 'Organic Fertilizer',
    description: 'All-natural organic fertilizer, 2kg bag. Safe for vegetables and flowers.',
    price: 16.99,
    icon: Icons.science,
  ),
];