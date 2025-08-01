import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/models/crop.dart';
import 'package:bloom/data/services/eco_backend.dart';
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
    // 이제 액션 오버레이가 Flame 내에서 처리됨
    // 이 메서드는 더 이상 사용되지 않음
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.eco, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('작물 심기'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Crop.crops.values.map((crop) {
            return Container(
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
                title: Text(
                  crop.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('비용: ${crop.cost[0]} 포인트'),
                trailing: Icon(Icons.add_circle, color: Colors.green[600]),
                onTap: () {
                  Navigator.of(context).pop();
                  _plantCrop(context, tile, crop, x, y);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProgressDialog(BuildContext context, GardenTile tile, int x, int y) {
    final crop = tile.crop;
    if (crop == null) return;

    final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
    final cost = crop.cost[nextStageIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.trending_up, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('작물 성장시키기'),
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
                Text('성장 비용:', style: TextStyle(color: Colors.grey[600])),
                Text('$cost 포인트', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('보유 포인트:', style: TextStyle(color: Colors.grey[600])),
                Text('${widget.garden.playerPoints} 포인트', 
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: widget.garden.playerPoints >= cost ? Colors.green[600] : Colors.red[600],
                     )),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: widget.garden.playerPoints >= cost
                ? () {
                    Navigator.of(context).pop();
                    _progressCrop(context, tile, x, y);
                  }
                : null,
            child: const Text('성장시키기', style: TextStyle(color: Colors.white)),
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
            const Text('수확하기'),
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
                    '수확 보상: ${crop.reward} 포인트',
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
            child: const Text('취소'),
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
            child: const Text('수확하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _plantCrop(BuildContext context, GardenTile tile, Crop crop, int x, int y) async {
    try {
      await EcoBackend.instance.plantCrop(tile.x, tile.y, crop.id);
      gameInstance.addPlantingEffect(x, y);
      widget.onRefresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(crop.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('${crop.displayName}을(를) 심었습니다!'),
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
            content: Text('심기 실패: ${e.toString()}'),
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
      await EcoBackend.instance.progressCrop(tile.x, tile.y);
      gameInstance.addGrowthEffect(x, y);
      widget.onRefresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🌱', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('작물이 성장했습니다!'),
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
            content: Text('성장 실패: ${e.toString()}'),
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
      await EcoBackend.instance.harvestCrop(tile.x, tile.y);
      
      // 실제 수확 보상을 Flame 효과에 전달
      gameInstance.addHarvestEffect(x, y, rewardPoints: crop?.reward);
      widget.onRefresh();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(crop?.icon ?? '🌾', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('${crop?.displayName ?? '작물'}을(를) 수확했습니다! +${crop?.reward ?? 0} 포인트'),
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
            content: Text('수확 실패: ${e.toString()}'),
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