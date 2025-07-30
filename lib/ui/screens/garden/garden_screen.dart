import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/models/crop.dart';

final gardenProvider = FutureProvider<Garden>((ref) async {
  final gardenData = await EcoBackend.instance.myGarden();
  return Garden.fromJson(gardenData);
});

class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gardenAsync = ref.watch(gardenProvider);

    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, gardenAsync),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // My Garden 탭
                    gardenAsync.when(
                      data: (garden) => _buildMyGarden(context, ref, garden),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => _buildErrorView(error),
                    ),
                    // City Garden 탭
                    _buildCityGarden(context, ref),
                  ],
                ),
              ),
            ],
          ),
          _buildRankingDragHandle(context),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.green[400],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.green[700],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'My Garden'),
          Tab(text: 'City Garden'),
        ],
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            '정원을 불러올 수 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.red[600]),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(gardenProvider),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<Garden> gardenAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.yard,
                color: Colors.green[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '내 정원',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: Colors.amber[700],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  gardenAsync.when(
                    data: (garden) => Text(
                      '${garden.playerCoins}',
                      style: TextStyle(
                        color: Colors.amber[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => const Text('...'),
                    error: (_, __) => const Text('0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyGarden(BuildContext context, WidgetRef ref, Garden garden) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(gardenProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 40,
              maxHeight: MediaQuery.of(context).size.width - 40,
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8D6E63),
                      const Color(0xFF6D4C41),
                      const Color(0xFF5D4037),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4E342E), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: garden.size,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: garden.size * garden.size,
                  itemBuilder: (context, index) {
                    final x = index % garden.size;
                    final y = index ~/ garden.size;
                    final tile = garden.getTile(x, y);
                    
                    return _buildGardenTile(context, ref, tile, garden);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityGarden(BuildContext context, WidgetRef ref) {
    final gardenAsync = ref.watch(gardenProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(gardenProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 상단 다른 플레이어 정원들
            _buildOtherPlayersRow(context, 'top'),
            const SizedBox(height: 8),
            
            // 중간 행 (왼쪽 정원 + 내 정원 + 오른쪽 정원)
            Row(
              children: [
                // 왼쪽 다른 플레이어 정원
                Expanded(child: _buildOtherPlayerGarden(context, 'left')),
                const SizedBox(width: 8),
                
                // 가운데 내 정원 (더 큰 크기)
                Expanded(
                  flex: 2,
                  child: gardenAsync.when(
                    data: (garden) => _buildCenterMyGarden(context, ref, garden),
                    loading: () => _buildLoadingGarden(),
                    error: (_, __) => _buildErrorGarden(),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 오른쪽 다른 플레이어 정원
                Expanded(child: _buildOtherPlayerGarden(context, 'right')),
              ],
            ),
            const SizedBox(height: 8),
            
            // 하단 다른 플레이어 정원들
            _buildOtherPlayersRow(context, 'bottom'),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherPlayersRow(BuildContext context, String position) {
    return Row(
      children: [
        Expanded(child: _buildOtherPlayerGarden(context, '$position-left')),
        const SizedBox(width: 8),
        Expanded(child: _buildOtherPlayerGarden(context, '$position-center')),
        const SizedBox(width: 8),
        Expanded(child: _buildOtherPlayerGarden(context, '$position-right')),
      ],
    );
  }

  Widget _buildOtherPlayerGarden(BuildContext context, String position) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.brown[300]!,
              Colors.brown[400]!,
              Colors.brown[500]!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.brown[600]!, width: 2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.all(0.5),
              decoration: BoxDecoration(
                color: _getRandomGreenColor(),
                border: Border.all(color: _getRandomGreenColor().withOpacity(0.7), width: 1),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCenterMyGarden(BuildContext context, WidgetRef ref, Garden garden) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8D6E63),
              const Color(0xFF6D4C41),
              const Color(0xFF5D4037),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4E342E), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: garden.size,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 1.1,
          ),
          itemCount: garden.size * garden.size,
          itemBuilder: (context, index) {
            final x = index % garden.size;
            final y = index ~/ garden.size;
            final tile = garden.getTile(x, y);
            
            return _buildGardenTile(context, ref, tile, garden);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingGarden() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[400]!, width: 3),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorGarden() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[300]!, width: 3),
        ),
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 32,
          ),
        ),
      ),
    );
  }

  Color _getRandomGreenColor() {
    final greens = [
      const Color(0xFF8BC34A),
      const Color(0xFF66BB6A),
      const Color(0xFF4CAF50),
      const Color(0xFF388E3C),
    ];
    return greens[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % greens.length];
  }

  Widget _buildGardenTile(BuildContext context, WidgetRef ref, GardenTile tile, Garden garden) {
    return GestureDetector(
      onTap: () => _onTileTap(context, ref, tile, garden),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _getTileTopColor(tile),
          border: Border.all(color: _getTileSideColor(tile), width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 타일 내용
            Center(
              child: _buildTileContent(tile),
            ),
            // 상태 표시 점
            if (tile.canProgress || tile.canHarvest)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tile.canHarvest ? Colors.yellow[600] : Colors.blue[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileContent(GardenTile tile) {
    switch (tile.stage) {
      case CropStage.empty:
        return Icon(
          Icons.add,
          color: Colors.brown[400],
          size: 20,
        );
      case CropStage.planted:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🌱',
              style: const TextStyle(fontSize: 16),
            ),
            if (tile.crop != null)
              Text(
                tile.crop!.displayName,
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center,
              ),
          ],
        );
      case CropStage.growing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🌾',
              style: const TextStyle(fontSize: 18),
            ),
            if (tile.crop != null)
              Text(
                tile.crop!.displayName,
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center,
              ),
          ],
        );
      case CropStage.mature:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tile.crop?.icon ?? '🌾',
              style: const TextStyle(fontSize: 20),
            ),
            if (tile.crop != null)
              Text(
                tile.crop!.displayName,
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center,
              ),
          ],
        );
    }
  }

  Color _getTileTopColor(GardenTile tile) {
    switch (tile.stage) {
      case CropStage.empty:
        return const Color(0xFF8BC34A);  // 밝은 초록
      case CropStage.planted:
        return const Color(0xFF66BB6A);  // 초록
      case CropStage.growing:
        return const Color(0xFF4CAF50);  // 진한 초록
      case CropStage.mature:
        return const Color(0xFF388E3C);  // 매우 진한 초록
    }
  }

  Color _getTileSideColor(GardenTile tile) {
    switch (tile.stage) {
      case CropStage.empty:
        return const Color(0xFF689F38);  // 어두운 초록
      case CropStage.planted:
        return const Color(0xFF558B2F);  // 더 어두운 초록
      case CropStage.growing:
        return const Color(0xFF388E3C);  // 진한 초록
      case CropStage.mature:
        return const Color(0xFF2E7D32);  // 매우 진한 초록
    }
  }

  double _getTileElevation(GardenTile tile) {
    switch (tile.stage) {
      case CropStage.empty:
        return 6.0;
      case CropStage.planted:
        return 8.0;
      case CropStage.growing:
        return 10.0;
      case CropStage.mature:
        return 12.0;
    }
  }

  void _onTileTap(BuildContext context, WidgetRef ref, GardenTile tile, Garden garden) {
    if (tile.canPlant) {
      _showPlantDialog(context, ref, tile);
    } else if (tile.canProgress) {
      _showProgressDialog(context, ref, tile, garden);
    } else if (tile.canHarvest) {
      _showHarvestDialog(context, ref, tile);
    }
  }

  void _showPlantDialog(BuildContext context, WidgetRef ref, GardenTile tile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작물 심기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Crop.crops.values.map((crop) {
            return ListTile(
              leading: Text(crop.icon, style: const TextStyle(fontSize: 24)),
              title: Text(crop.displayName),
              subtitle: Text('비용: ${crop.cost[0]} 코인'),
              onTap: () {
                Navigator.of(context).pop();
                _plantCrop(context, ref, tile, crop);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProgressDialog(BuildContext context, WidgetRef ref, GardenTile tile, Garden garden) {
    final crop = tile.crop;
    if (crop == null) return;

    final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
    final cost = crop.cost[nextStageIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작물 성장시키기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(crop.icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(crop.displayName, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text('성장 비용: $cost 코인'),
            Text('보유 코인: ${garden.playerCoins} 코인'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: garden.playerCoins >= cost
                ? () {
                    Navigator.of(context).pop();
                    _progressCrop(context, ref, tile);
                  }
                : null,
            child: const Text('성장시키기'),
          ),
        ],
      ),
    );
  }

  void _showHarvestDialog(BuildContext context, WidgetRef ref, GardenTile tile) {
    final crop = tile.crop;
    if (crop == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수확하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(crop.icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(crop.displayName, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text('수확 보상: ${crop.reward} 코인'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _harvestCrop(context, ref, tile);
            },
            child: const Text('수확하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _plantCrop(BuildContext context, WidgetRef ref, GardenTile tile, Crop crop) async {
    try {
      await EcoBackend.instance.plantCrop(tile.x, tile.y, crop.id);
      ref.refresh(gardenProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${crop.displayName}을(를) 심었습니다!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('심기 실패: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _progressCrop(BuildContext context, WidgetRef ref, GardenTile tile) async {
    try {
      await EcoBackend.instance.progressCrop(tile.x, tile.y);
      ref.refresh(gardenProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('작물이 성장했습니다!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('성장 실패: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _harvestCrop(BuildContext context, WidgetRef ref, GardenTile tile) async {
    try {
      await EcoBackend.instance.harvestCrop(tile.x, tile.y);
      ref.refresh(gardenProvider);
      if (context.mounted) {
        final crop = tile.crop;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${crop?.displayName ?? '작물'}을(를) 수확했습니다! +${crop?.reward ?? 0} 코인')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수확 실패: ${e.toString()}')),
        );
      }
    }
  }
}

class IsometricTilePainter extends CustomPainter {
  final Color topColor;
  final Color sideColor;
  final double elevation;

  IsometricTilePainter({
    required this.topColor,
    required this.sideColor,
    required this.elevation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    final width = size.width;
    final height = size.height;
    final depth = elevation;
    
    // 상단면 (다이아몬드 모양)
    final topPath = Path();
    topPath.moveTo(width * 0.5, 0);
    topPath.lineTo(width, height * 0.25);
    topPath.lineTo(width * 0.5, height * 0.5);
    topPath.lineTo(0, height * 0.25);
    topPath.close();
    
    paint.color = topColor;
    canvas.drawPath(topPath, paint);
    
    // 왼쪽 옆면
    final leftPath = Path();
    leftPath.moveTo(0, height * 0.25);
    leftPath.lineTo(width * 0.5, height * 0.5);
    leftPath.lineTo(width * 0.5, height * 0.5 + depth);
    leftPath.lineTo(0, height * 0.25 + depth);
    leftPath.close();
    
    paint.color = sideColor.withOpacity(0.8);
    canvas.drawPath(leftPath, paint);
    
    // 오른쪽 옆면  
    final rightPath = Path();
    rightPath.moveTo(width * 0.5, height * 0.5);
    rightPath.lineTo(width, height * 0.25);
    rightPath.lineTo(width, height * 0.25 + depth);
    rightPath.lineTo(width * 0.5, height * 0.5 + depth);
    rightPath.close();
    
    paint.color = sideColor.withOpacity(0.6);
    canvas.drawPath(rightPath, paint);
    
    // 상단면 테두리
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = sideColor.withOpacity(0.4);
    canvas.drawPath(topPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IsometricTilePainter &&
        other.topColor == topColor &&
        other.sideColor == sideColor &&
        other.elevation == elevation;
  }

  @override
  int get hashCode => Object.hash(topColor, sideColor, elevation);
}

  Widget _buildRankingDragHandle(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (details.delta.dy < -10) {
            _showRankingModal(context);
          }
        },
        onTap: () => _showRankingModal(context),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.leaderboard,
                    color: Colors.green[700],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ranking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRankingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              _buildRankingHeader(),
              Expanded(
                child: _buildRankingList(scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[600],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.eco,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Ranking',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList(ScrollController scrollController) {
    final mockRankings = [
      {'rank': 1, 'name': 'Username', 'points': '300p'},
      {'rank': 2, 'name': 'User', 'points': '250p'},
      {'rank': 3, 'name': 'User', 'points': '220p'},
      {'rank': 4, 'name': 'User', 'points': '200p'},
      {'rank': 5, 'name': 'User', 'points': '180p'},
      {'rank': 6, 'name': 'User', 'points': '160p'},
      {'rank': 7, 'name': 'User', 'points': '140p'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView.builder(
        controller: scrollController,
        itemCount: mockRankings.length + 1, // +1 for promote line
        itemBuilder: (context, index) {
          // PROMOTE 선을 3등 뒤에 표시
          if (index == 3) {
            return _buildPromoteLine();
          }
          
          // 인덱스 조정 (PROMOTE 선 때문에)
          final rankingIndex = index > 3 ? index - 1 : index;
          final ranking = mockRankings[rankingIndex];
          final isTopThree = ranking['rank'] as int <= 3;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTopThree ? Colors.green[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTopThree ? Colors.green[200]! : Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isTopThree ? Colors.green[600] : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${ranking['rank']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    ranking['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  ranking['points'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoteLine() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[300]!,
                    Colors.orange[500]!,
                    Colors.orange[300]!,
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[500],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'PROMOTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[300]!,
                    Colors.orange[500]!,
                    Colors.orange[300]!,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }