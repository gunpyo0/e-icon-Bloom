import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: _buildEcoProductsTab(context),
    );
  }

  Widget _buildEcoProductsTab(BuildContext context) {
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
                        'Purchase eco‑friendly products delivered to your door',
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
                return _buildEcoProductCard(context, product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoProductCard(BuildContext context, EcoProduct product) {
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
          onTap: () => _showEcoProductDialog(context, product),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product icon/image
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
                            '3‑5 days delivery',
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
                // Price + CTA
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
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
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

  void _showEcoProductDialog(BuildContext context, EcoProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              '• Free shipping included\n• 3‑5 business days delivery\n• Eco‑friendly packaging',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} ordered! Tracking info soon.'),
                  backgroundColor: Colors.green[600],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }
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

// Sample eco‑product data
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
    name: 'Eco‑Friendly Soil',
    description: 'Organic compost‑enriched soil, 5kg bag. Perfect for vegetable gardens.',
    price: 19.99,
    icon: Icons.grass,
  ),
  EcoProduct(
    name: 'Solar Garden Light',
    description: 'LED solar‑powered garden lights. Set of 4 waterproof lights.',
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
    description: 'All‑natural organic fertilizer, 2kg bag. Safe for vegetables and flowers.',
    price: 16.99,
    icon: Icons.science,
  ),
];
