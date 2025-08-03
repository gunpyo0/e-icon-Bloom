import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/models/crop.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/ui/screens/profile/profile_screen.dart';
import 'package:bloom/providers/points_provider.dart';
import 'flame_garden_game.dart';

class FlameGardenWidget extends ConsumerStatefulWidget {
  final Garden garden;
  final VoidCallback onRefresh;

  const FlameGardenWidget({
    super.key,
    required this.garden,
    required this.onRefresh,
  });

  @override
  ConsumerState<FlameGardenWidget> createState() => _FlameGardenWidgetState();
}

class _FlameGardenWidgetState extends ConsumerState<FlameGardenWidget> {
  late FlameGardenGame gameInstance;

  @override
  void initState() {
    super.initState();
    gameInstance = FlameGardenGame(
      gardenData: widget.garden,
      onTileTapped: _onTileTapped,
      onTileActionSelected: _onTileActionSelected,
    );
  }

  @override
  void didUpdateWidget(FlameGardenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.garden != widget.garden) {
      gameInstance.updateGarden(widget.garden);
    }
  }

  void _onTileTapped(int x, int y) {
    // Action overlay is now handled within Flame
    // This method is no longer used
  }

  void _onTileActionSelected(int x, int y, String actionType) {
    final tile = widget.garden.getTile(x, y);
    
    switch (actionType) {
      case 'plant':
        _showPlantDialog(context, tile, x, y);
        break;
      case 'progress':
        _progressCrop(context, tile, x, y);
        break;
      case 'harvest':
        _harvestCrop(context, tile, x, y);
        break;
    }
  }

  void _showPlantDialog(BuildContext context, GardenTile tile, int x, int y) {
    final profileAsync = ref.watch(profileProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.eco, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Plant Crop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display current points
            profileAsync.when(
              data: (profile) {
                final totalPoints = profile['totalPoints'] ?? 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Points: ${totalPoints} P',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Unable to load point information'),
            ),
            
            // Crop list
            ...Crop.crops.values.map((crop) {
              final plantCost = crop.cost[0];
              
              return profileAsync.when(
                data: (profile) {
                  final totalPoints = profile['totalPoints'] ?? 0;
                  final canAfford = totalPoints >= plantCost;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canAfford ? Colors.green[200]! : Colors.grey[300]!,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: canAfford ? Colors.green[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(crop.icon, style: const TextStyle(fontSize: 24)),
                      ),
                      title: Text(
                        crop.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: canAfford ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        'Cost: ${plantCost} points',
                        style: TextStyle(
                          color: canAfford ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Icon(
                        canAfford ? Icons.add_circle : Icons.block,
                        color: canAfford ? Colors.green[600] : Colors.grey,
                      ),
                      onTap: canAfford ? () {
                        Navigator.of(context).pop();
                        _plantCrop(context, tile, crop, x, y);
                      } : null,
                      enabled: canAfford,
                    ),
                  );
                },
                loading: () => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(crop.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    title: Text(crop.displayName),
                    subtitle: Text('Cost: ${plantCost} points'),
                  ),
                ),
                error: (_, __) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(crop.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    title: Text(crop.displayName),
                    subtitle: Text('Cost: ${plantCost} points'),
                    enabled: false,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showProgressDialog(BuildContext context, GardenTile tile, int x, int y) {
    final crop = tile.crop;
    if (crop == null) return;

    final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
    final cost = crop.cost[nextStageIndex];
    final profileAsync = ref.watch(profileProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.trending_up, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Grow Crop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(crop.icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(crop.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Growth Cost:', style: TextStyle(color: Colors.grey[600])),
                Text('$cost points', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            profileAsync.when(
              data: (profile) {
                final totalPoints = profile['totalPoints'] ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Points:', style: TextStyle(color: Colors.grey[600])),
                    Text('$totalPoints points', 
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: totalPoints >= cost ? Colors.green[600] : Colors.red[600],
                         )),
                  ],
                );
              },
              loading: () => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Points:', style: TextStyle(color: Colors.grey[600])),
                  const Text('Loading...'),
                ],
              ),
              error: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Points:', style: TextStyle(color: Colors.grey[600])),
                  const Text('Error'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          profileAsync.when(
            data: (profile) {
              final totalPoints = profile['totalPoints'] ?? 0;
              final canAfford = totalPoints >= cost;
              
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? Colors.blue[600] : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: canAfford ? () {
                  Navigator.of(context).pop();
                  _progressCrop(context, tile, x, y);
                } : null,
                child: Text(
                  canAfford ? 'Grow' : 'Not enough points',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
            loading: () => const ElevatedButton(
              onPressed: null,
              child: Text('Loading...'),
            ),
            error: (_, __) => const ElevatedButton(
              onPressed: null,
              child: Text('Error'),
            ),
          ),
        ],
      ),
    );
  }

  void _showHarvestDialog(BuildContext context, GardenTile tile, int x, int y) {
    final crop = tile.crop;
    if (crop == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.agriculture, color: Colors.amber[600]),
            const SizedBox(width: 8),
            const Text('Harvest'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(crop.icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(crop.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Harvest Reward: ${crop.reward} points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _harvestCrop(context, tile, x, y);
            },
            child: const Text('Harvest', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _plantCrop(BuildContext context, GardenTile tile, Crop crop, int x, int y) async {
    try {
      final plantCost = crop.cost[0];
      await EcoBackend.instance.plantCropWithPoints(tile.x, tile.y, crop.id, plantCost);
      gameInstance.addPlantingEffect(x, y);
      
      // Refresh profile and garden providers
      ref.read(pointsProvider.notifier).refresh();
      widget.onRefresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(crop.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('${crop.displayName} planted! (-${plantCost}P)'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planting failed: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _progressCrop(BuildContext context, GardenTile tile, int x, int y) async {
    try {
      final crop = tile.crop;
      if (crop == null) return;
      
      final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
      final growthCost = crop.cost[nextStageIndex];
      
      await EcoBackend.instance.progressCropWithPoints(tile.x, tile.y, growthCost);
      gameInstance.addGrowthEffect(x, y);
      
      // Refresh profile and garden providers
      ref.read(pointsProvider.notifier).refresh();
      widget.onRefresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Crop has grown! (-${growthCost}P)'),
              ],
            ),
            backgroundColor: Colors.blue[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Growth failed: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _harvestCrop(BuildContext context, GardenTile tile, int x, int y) async {
    try {
      final crop = tile.crop;
      if (crop == null) return;
      
      final earnedPoints = await EcoBackend.instance.harvestCropWithPoints(tile.x, tile.y, crop.reward);
      
      // 포인트를 즉시 추가 (UI 빠른 반응용)
      ref.read(pointsProvider.notifier).addPoints(earnedPoints);
      
      // Pass actual harvest reward to Flame effect
      gameInstance.addHarvestEffect(x, y, rewardPoints: crop.reward);
      
      widget.onRefresh();
      
      // 실제 포인트 새로고침 (정확한 값 확인용)
      await ref.read(pointsProvider.notifier).refresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(crop.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('${crop.displayName} harvested! +${crop.reward} points'),
              ],
            ),
            backgroundColor: Colors.amber[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Harvest failed: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GameWidget.controlled(gameFactory: () => gameInstance),
        ),
      ),
    );
  }
}