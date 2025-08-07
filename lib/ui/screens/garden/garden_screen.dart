import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/models/crop.dart';
import 'package:bloom/ui/screens/profile/profile_screen.dart';
import 'package:bloom/providers/points_provider.dart';
import 'package:bloom/ui/widgets/ranking_widget.dart';

final gardenProvider = FutureProvider<Garden>((ref) async {
  final gardenData = await EcoBackend.instance.myGarden();
  return Garden.fromJson(gardenData);
});


class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 포어그라운드로 올 때 실시간 갱신
      _refreshData();
    }
  }

  void _refreshData() {
    // 포인트 provider 새로고침
    ref.read(pointsProvider.notifier).forceSync();
    
    // 정원 데이터 새로고침 
    ref.refresh(gardenProvider);
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
              Expanded(
                child: gardenAsync.when(
                  data: (garden) => _buildMyGarden(context, ref, garden),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildErrorView(error),
                ),
              ),
            ],
          ),
          _buildRankingDragHandle(),
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
            'Cannot load garden',
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
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<Garden> gardenAsync) {
    final profileAsync = ref.watch(profileProvider);
    
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
              'My Garden',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green[700],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Consumer(
                    builder: (context, ref, child) {
                      final pointsAsync = ref.watch(pointsProvider);
                      return pointsAsync.when(
                        data: (points) => Text(
                          '$points P',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        loading: () => const Text('... P', style: TextStyle(fontSize: 14)),
                        error: (_, __) => const Text('0 P', style: TextStyle(fontSize: 14)),
                      );
                    },
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

          ),
        ),
      ),
    );
  }

  Widget _buildCityGarden(BuildContext context, WidgetRef ref) {
    // City Garden 기능은 사용하지 않으므로 빈 컨테이너 반환
    return const Center(
      child: Text('City Garden feature is not available'),
    );
  }

  Widget _buildCityGardenWithData(BuildContext context, WidgetRef ref, AsyncValue<Garden> gardenAsync, List<Map<String, dynamic>> memberGardens) {
    // Find current user's garden
    final currentUserUid = EcoBackend.instance.uidOrEmpty;
    Map<String, dynamic>? myGardenData;
    List<Map<String, dynamic>> otherGardens = [];
    
    for (final garden in memberGardens) {
      final memberInfo = garden['memberInfo'];
      if (memberInfo != null && memberInfo['uid'] == currentUserUid) {
        myGardenData = garden;
      } else {
        otherGardens.add(garden);
      }
    }
    
    // Arrange gardens in 3x3 grid with my garden in center
    final List<Map<String, dynamic>?> arrangedGardens = List.filled(9, null);
    arrangedGardens[4] = myGardenData; // Center position for my garden
    
    // Fill other positions with other players' gardens
    final availablePositions = [0, 1, 2, 3, 5, 6, 7, 8]; // Skip center (4)
    for (int i = 0; i < otherGardens.length && i < availablePositions.length; i++) {
      arrangedGardens[availablePositions[i]] = otherGardens[i];
    }
    
    return Column(
      children: [
        // Top row
        _buildGardensRow(context, ref, gardenAsync, [arrangedGardens[0], arrangedGardens[1], arrangedGardens[2]]),
        const SizedBox(height: 8),
        
        // Middle row (with my garden in center)
        _buildGardensRow(context, ref, gardenAsync, [arrangedGardens[3], arrangedGardens[4], arrangedGardens[5]], centerIsMyGarden: true),
        const SizedBox(height: 8),
        
        // Bottom row
        _buildGardensRow(context, ref, gardenAsync, [arrangedGardens[6], arrangedGardens[7], arrangedGardens[8]]),
      ],
    );
  }
  
  Widget _buildGardensRow(BuildContext context, WidgetRef ref, AsyncValue<Garden> gardenAsync, List<Map<String, dynamic>?> gardens, {bool centerIsMyGarden = false}) {
    return Row(
      children: [
        Expanded(child: _buildPlayerGarden(context, ref, gardens[0])),
        const SizedBox(width: 8),
        Expanded(
          flex: centerIsMyGarden ? 2 : 1,
          child: centerIsMyGarden && gardens[1] != null
              ? gardenAsync.when(
                  data: (garden) => _buildMyGardenInCity(context, ref, garden),
                  loading: () => _buildLoadingGarden(),
                  error: (_, __) => _buildErrorGarden(),
                )
              : _buildPlayerGarden(context, ref, gardens[1]),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildPlayerGarden(context, ref, gardens[2])),
      ],
    );
  }
  
  Widget _buildCityGardenLoading() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Row(
            children: [
              for (int j = 0; j < 3; j++) ...[
                Expanded(
                  flex: (i == 1 && j == 1) ? 2 : 1,
                  child: _buildLoadingGarden(),
                ),
                if (j < 2) const SizedBox(width: 8),
              ],
            ],
          ),
          if (i < 2) const SizedBox(height: 8),
        ],
      ],
    );
  }
  
  Widget _buildCityGardenError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Cannot load league gardens',
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
            onPressed: () {
              ref.refresh(gardenProvider);
            },
            child: const Text('Retry'),
          ),
        ],
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

  Widget _buildPlayerGarden(BuildContext context, WidgetRef ref, Map<String, dynamic>? gardenData) {
    if (gardenData == null) {
      return _buildEmptyGardenSlot();
    }
    
    final memberInfo = gardenData['memberInfo'];
    final gardenSize = gardenData['size'] ?? 3;
    final tiles = gardenData['tiles'] ?? {};
    
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
        child: Stack(
          children: [
            // Garden grid (full container)
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 1, right: 1, bottom: 1),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gardenSize,
                  crossAxisSpacing: 0.3,
                  mainAxisSpacing: 0.3,
                  childAspectRatio: 1.0,
                ),
                itemCount: gardenSize * gardenSize,
                itemBuilder: (context, index) {
                  final x = index % gardenSize;
                  final y = index ~/ gardenSize;
                  final tileKey = '${x}_$y';
                  final tileData = tiles[tileKey];
                  
                  return _buildMiniGardenTile(tileData);
                },
              ),
            ),
            
            // Player info header (overlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        memberInfo['displayName'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${memberInfo['points'] ?? 0}P',
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildMyGardenInCity(BuildContext context, WidgetRef ref, Garden garden) {
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
        child: Stack(
          children: [
            // Garden grid (full container)
            Padding(
              padding: const EdgeInsets.only(top: 18, left: 2, right: 2, bottom: 2),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: garden.size,
                  crossAxisSpacing: 0.5,
                  mainAxisSpacing: 0.5,
                  childAspectRatio: 1.0,
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
            
            // My garden header (overlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home, color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Text(
                      'My Garden',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildEmptyGardenSlot() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Empty Slot',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGardenTile(Map<String, dynamic>? tileData) {
    if (tileData == null) {
      return Container(
        margin: const EdgeInsets.all(0.1),
        decoration: BoxDecoration(
          color: Colors.brown[100],
          borderRadius: BorderRadius.circular(0.5),
          border: Border.all(color: Colors.brown[300]!, width: 0.2),
        ),
      );
    }

    final stage = tileData['stage'] ?? 'empty';
    final cropId = tileData['cropId'];
    
    Color tileColor;
    String? emoji;
    
    switch (stage) {
      case 'empty':
        tileColor = Colors.brown[100]!;
        break;
      case 'planted':
        tileColor = Colors.green[200]!;
        emoji = '🌱';
        break;
      case 'growing':
        tileColor = Colors.green[300]!;
        emoji = '🌿';
        break;
      case 'mature':
        tileColor = Colors.orange[200]!;
        if (cropId != null && Crop.crops.containsKey(cropId)) {
          emoji = Crop.crops[cropId]!.icon;
        } else {
          emoji = '🌾';
        }
        break;
      default:
        tileColor = Colors.brown[100]!;
    }

    return Container(
      margin: const EdgeInsets.all(0.1),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(0.5),
        border: Border.all(color: tileColor.withOpacity(0.7), width: 0.2),
      ),
      child: emoji != null 
          ? Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 5),
              ),
            )
          : null,
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
        margin: const EdgeInsets.all(2),
        child: Stack(
          children: [
            // 메인 타일 내용
            _buildTileContent(tile),
            
            // 액션 가능 표시기
            if (tile.canProgress)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            
            if (tile.canHarvest)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
              
            // 호버 효과 (터치 피드백)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _onTileTap(context, ref, tile, garden),
                  child: Container(),
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
        return Container(
          decoration: BoxDecoration(
            color: Colors.brown[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown[300]!, width: 2, style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.brown[600],
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  'Plant',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.brown[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      case CropStage.planted:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[200]!, Colors.green[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[400]!, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🌱',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 2),
                if (tile.crop != null) ...[
                  Text(
                    tile.crop!.displayName,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Sprout',
                    style: TextStyle(
                      fontSize: 7,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case CropStage.growing:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[300]!, Colors.green[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[500]!, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🌿',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 2),
                if (tile.crop != null) ...[
                  Text(
                    tile.crop!.displayName,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Growing',
                    style: TextStyle(
                      fontSize: 7,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case CropStage.mature:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[200]!, Colors.orange[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[400]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tile.crop?.icon ?? '🌾',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 2),
                if (tile.crop != null) ...[
                  Text(
                    tile.crop!.displayName,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ready!',
                      style: TextStyle(
                        fontSize: 6,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final profileAsync = ref.watch(profileProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.eco, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Plant Crop'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 현재 포인트 표시
              Consumer(
                builder: (context, ref, child) {
                  final pointsAsync = ref.watch(pointsProvider);
                  return pointsAsync.when(
                    data: (totalPoints) => Container(
                      padding: const EdgeInsets.all(12),
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
                    ),
                    loading: () => Container(
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Points: ... P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                    error: (_, __) => Container(
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Points: 0 P', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // 작물 목록
              ...Crop.crops.values.map((crop) {
                final plantCost = crop.cost[0];
                
                return Consumer(
                  builder: (context, ref, child) {
                    final pointsAsync = ref.watch(pointsProvider);
                    return pointsAsync.when(
                      data: (totalPoints) {
                        final canAfford = totalPoints >= plantCost;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Text(crop.icon, style: const TextStyle(fontSize: 28)),
                        title: Text(
                          crop.displayName,
                          style: TextStyle(
                            color: canAfford ? Colors.black : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 16,
                              color: canAfford ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${plantCost} P',
                              style: TextStyle(
                                color: canAfford ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: canAfford 
                          ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green)
                          : const Icon(Icons.block, size: 16, color: Colors.grey),
                        onTap: canAfford ? () {
                          Navigator.of(context).pop();
                          _plantCrop(context, ref, tile, crop);
                        } : null,
                        enabled: canAfford,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: canAfford ? Colors.green.shade200 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                      },
                      loading: () => ListTile(
                        leading: Text(crop.icon, style: const TextStyle(fontSize: 28)),
                        title: Text(crop.displayName),
                        subtitle: Text('${plantCost} P'),
                      ),
                      error: (_, __) => ListTile(
                        leading: Text(crop.icon, style: const TextStyle(fontSize: 28)),
                        title: Text(crop.displayName),
                        subtitle: Text('${plantCost} P'),
                        enabled: false,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context, WidgetRef ref, GardenTile tile, Garden garden) {
    final crop = tile.crop;
    if (crop == null) return;

    final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
    final cost = crop.cost[nextStageIndex];
    final profileAsync = ref.watch(profileProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.trending_up, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Grow Crop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(crop.icon, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    crop.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tile.stage == CropStage.planted ? '🌱 → 🌾' : '🌾 → ${crop.icon}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Consumer(
              builder: (context, ref, child) {
                final pointsAsync = ref.watch(pointsProvider);
                return pointsAsync.when(
                  data: (totalPoints) {
                    final canAfford = totalPoints >= cost;
                    
                    return Column(
                      children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canAfford ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canAfford ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: canAfford ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Points: ${totalPoints} P',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: canAfford ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Growth Cost: ${cost} P',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          if (!canAfford) ...[
                            const SizedBox(height: 8),
                            Text(
                              '포인트가 부족합니다',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Cannot load points'),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final pointsAsync = ref.watch(pointsProvider);
              return pointsAsync.when(
                data: (totalPoints) {
                  final canAfford = totalPoints >= cost;
                  
                  return ElevatedButton(
                    onPressed: canAfford ? () {
                      Navigator.of(context).pop();
                      _progressCrop(context, ref, tile);
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(canAfford ? 'Grow' : 'Not enough points'),
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
              );
            },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.agriculture, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Harvest'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.yellow.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Text(crop.icon, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    crop.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎉 수확 완료! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Harvest Reward: +${crop.reward} P',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
            onPressed: () {
              Navigator.of(context).pop();
              _harvestCrop(context, ref, tile);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Harvest',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _plantCrop(BuildContext context, WidgetRef ref, GardenTile tile, Crop crop) async {
    try {
      // 포인트 확인만 하고 차감은 하지 않음 (Firebase Functions에서 처리)
      final profile = await ref.read(profileProvider.future);
      final totalPoints = profile['totalPoints'] ?? 0;
      final plantCost = crop.cost[0];
      
      if (totalPoints < plantCost) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not enough points. (Need: ${plantCost}P, Have: ${totalPoints}P)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // 작물 심기 (Firebase Functions에서 포인트 차감도 함께 처리)
      await EcoBackend.instance.plantCropWithPoints(tile.x, tile.y, crop.id, plantCost);
      
      // 프로필과 정원 새로고침
      ref.read(pointsProvider.notifier).refresh();
      ref.refresh(gardenProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${crop.displayName} planted! (-${plantCost}P)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Plant crop error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planting failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _progressCrop(BuildContext context, WidgetRef ref, GardenTile tile) async {
    try {
      final crop = tile.crop;
      if (crop == null) return;
      
      // 포인트 확인
      final profile = await ref.read(profileProvider.future);
      final totalPoints = profile['totalPoints'] ?? 0;
      final nextStageIndex = tile.stage == CropStage.planted ? 1 : 2;
      final growthCost = crop.cost[nextStageIndex];
      
      if (totalPoints < growthCost) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not enough points. (Need: ${growthCost}P, Have: ${totalPoints}P)'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // 작물 성장 (포인트 차감 포함)
      await EcoBackend.instance.progressCropWithPoints(tile.x, tile.y, growthCost);
      
      // 프로필과 정원 새로고침
      ref.read(pointsProvider.notifier).refresh();
      ref.refresh(gardenProvider);
      
      if (context.mounted) {
        final stageText = tile.stage == CropStage.planted ? 'grew' : 'matured';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${crop.displayName}이(가) ${stageText} 했습니다! (-${growthCost}P)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Progress crop error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Growth failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _harvestCrop(BuildContext context, WidgetRef ref, GardenTile tile) async {
    try {
      final crop = tile.crop;
      if (crop == null) return;
      
      // 수확하기 (포인트 지급 포함)
      final earnedPoints = await EcoBackend.instance.harvestCropWithPoints(tile.x, tile.y, crop.reward);
      
      // 포인트를 즉시 추가 (UI 빠른 반응용)
      ref.read(pointsProvider.notifier).addPoints(earnedPoints);
      
      // 실제 포인트 새로고침 (정확한 값 확인용)
      await ref.read(pointsProvider.notifier).refresh();
      ref.refresh(gardenProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${crop.displayName} harvested! (+${crop.reward}P)'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Harvest crop error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Harvest failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRankingDragHandle() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RankingDragHandle(
        onTap: _showRankingModal,
        primaryColor: Colors.green[700],
      ),
    );
  }

  void _showRankingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => RankingWidget(
          showAsModal: true,
          title: 'Garden Ranking',
          primaryColor: Colors.green[600],
          onRefresh: _refreshData,
        ),
      ),
    );
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