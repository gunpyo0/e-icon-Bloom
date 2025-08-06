<<<<<<< Updated upstream
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/models/crop.dart';
import 'package:bloom/ui/screens/profile/profile_screen.dart';
import 'package:bloom/providers/points_provider.dart';
=======
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_unity_widget/flutter_unity_widget.dart';
  import 'package:bloom/data/services/eco_backend.dart';
>>>>>>> Stashed changes

  class GardenScreen extends ConsumerStatefulWidget {
    const GardenScreen({super.key});

    @override
    ConsumerState<GardenScreen> createState() => _GardenScreenState();
  }

  class _GardenScreenState extends ConsumerState<GardenScreen> {
    UnityWidgetController? _unity;
    Map<String, dynamic>? _myLeague;
    List<Map<String, dynamic>> _leagueRanking = [];

    @override
    void initState() {
      super.initState();
      _initLeague();
    }

    Future<void> _initLeague() async {
      await EcoBackend.instance.ensureUserInLeague();
      final league = await EcoBackend.instance.myLeague();
      setState(() => _myLeague = league);

      if (league['leagueId'] != null) {
        EcoBackend.instance
            .leagueMembers(league['leagueId'])
            .listen((snap) {
          setState(() {
            _leagueRanking =
                snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
          });
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            /* 1) Unity 화면 + 모든 포인터 흡수! */
            GestureDetector(
              behavior: HitTestBehavior.opaque,   // 빈 영역까지 히트
              // ↓ 빈 콜백들로 모든 제스처를 ‘Claim’
              onTap: () {},
              onDoubleTap: () {},
              onLongPress: () {},
              onScaleStart: (_) {},
              onScaleUpdate: (_) {},
              onScaleEnd: (_) {},
              child: UnityWidget(
                onUnityCreated: (c) => _unity = c,
                onUnityMessage: (msg) =>
                    debugPrint('💌 from Unity: ${msg.toString()}'),
                fullscreen: true,
                placeholder:
                const Center(child: CircularProgressIndicator()),
                // 성능 + 멀티터치 안정
                useAndroidViewSurface: true,
              ),
            ),

            /* 2) 랭킹 드래그 핸들 */
            _buildRankingDragHandle(context),
          ],
        ),
<<<<<<< Updated upstream
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
    final gardenAsync = ref.watch(gardenProvider);
    final leagueGardensAsync = ref.watch(leagueMembersGardensProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(gardenProvider);
        ref.refresh(leagueMembersGardensProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: leagueGardensAsync.when(
          data: (memberGardens) => _buildCityGardenWithData(context, ref, gardenAsync, memberGardens),
          loading: () => _buildCityGardenLoading(),
          error: (error, stack) => _buildCityGardenError(context, ref, error),
        ),
      ),
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
              ref.refresh(leagueMembersGardensProvider);
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
=======
>>>>>>> Stashed changes
      );
    }

    /* 이하 랭킹 UI 로직은 그대로 */
    Widget _buildRankingDragHandle(BuildContext ctx) => Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onPanUpdate: (d) {
          if (d.delta.dy < -10) _showRankingModal(ctx);
        },
        onTap: () => _showRankingModal(ctx),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2))
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
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard,
                      color: Colors.green[700], size: 24),
                  const SizedBox(width: 8),
                  Text('Ranking',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    void _showRankingModal(BuildContext ctx) => showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .8,
        minChildSize: .5,
        maxChildSize: .9,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildRankingHeader(),
              Expanded(child: _buildRankingList(sc)),
            ],
          ),
        ),
      ),
    );

    Widget _buildRankingHeader() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[600],
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.eco, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Text('Ranking',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );

    Widget _buildRankingList(ScrollController sc) {
      final selfUid = EcoBackend.instance.uidOrEmpty;

      final rows = List<Map<String, dynamic>>.from(_leagueRanking)
        ..sort((a, b) => (b['point'] ?? 0).compareTo(a['point'] ?? 0));
      while (rows.length < 7) {
        rows.add({'isEmpty': true, 'id': 'empty_${rows.length}'});
      }

      return ListView.builder(
        controller: sc,
        itemCount: 8,
        itemBuilder: (_, i) {
          if (i == 3) return _buildPromoteLine();
          final idx = i > 3 ? i - 1 : i;
          final m = rows[idx];
          final empty = m['isEmpty'] == true;
          final rank = idx + 1;
          final me = m['id'] == selfUid && !empty;

          Color badgeColor() {
            if (empty) return Colors.grey;
            if (me) return Colors.blue;
            return [Colors.amber, Colors.grey, Colors.brown][rank - 1] ??
                Colors.grey;
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: empty
                  ? Colors.grey[100]
                  : me
                  ? Colors.blue[50]
                  : rank <= 3
                  ? Colors.green[50]
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: empty
                      ? Colors.grey[300]!
                      : me
                      ? Colors.blue[300]!
                      : rank <= 3
                      ? Colors.green[200]!
                      : Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor(),
                  child: empty
                      ? const Icon(Icons.person_add_outlined,
                      color: Colors.white)
                      : Text('$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(
                      empty ? '빈 자리' : (m['displayName'] ?? 'User'),
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: empty
                              ? Colors.grey
                              : me
                              ? Colors.blue[700]
                              : Colors.black),
                    )),
                Text(
                  empty ? '-' : '${m['point'] ?? 0}p',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: me ? Colors.blue : Colors.green),
                )
              ],
            ),
          );
        },
      );
    }

    Widget _buildPromoteLine() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(
            child: Divider(thickness: 2, color: Colors.orangeAccent)),
        Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('PROMOTE',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        const Expanded(
            child: Divider(thickness: 2, color: Colors.orangeAccent)),
      ]),
    );
  }
