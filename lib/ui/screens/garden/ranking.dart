import 'package:bloom/data/services/class.dart';
import 'package:bloom/data/services/league_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// drag‑handle + modal 전부 분리
class RankingDragHandle extends ConsumerWidget {
  const RankingDragHandle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onPanUpdate: (d) {
          if (d.delta.dy < -10) _showRankingModal(context, ref);
        },
        onTap: () => _showRankingModal(context, ref),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.1),
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
                  Icon(Icons.leaderboard, color: Colors.green[700]),
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

  /*──────────────────────── modal ────────────────────────*/
  void _showRankingModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .8,
        minChildSize: .5,
        maxChildSize: .9,
        builder: (ctx, controller) => _RankingSheet(scroll: controller),
      ),
    );
  }
}

/*──────────────────────── sheet 본문 ────────────────────────*/
class _RankingSheet extends ConsumerWidget {
  const _RankingSheet({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /* 1️⃣ 내 리그 id → 랭킹 스트림 */
    final leagueAsync = ref.watch(myLeagueProvider); // { leagueId, … }
    return leagueAsync.when(
      loading: _loading,
      error: _err,
      data: (lg) {
        if (lg.leagueId == null) return _err('아직 리그 없음', null);
        final rankingAsync = ref.watch(rankingProvider(lg.leagueId!));
        return rankingAsync.when(
          loading: _loading,
          error: _err,
          data: (ranking) => _buildContent(context, ranking),
        );
      },
    );
  }

  /* UI */
  Widget _buildContent(BuildContext ctx, LeagueRanking rnk) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    child: Column(
      children: [
        _header(),
        Expanded(child: _list(rnk)),
      ],
    ),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.green[600],
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: const [
          Icon(Icons.eco, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Text(
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

  Widget _list(LeagueRanking rnk) => ListView.builder(
    controller: scroll,
    padding: const EdgeInsets.all(20),
    itemCount: rnk.members.length + 1 /* promote line */,
    itemBuilder: (_, i) {
      if (i == 3) return _promoteLine(); // === PROMOTE 줄 ===

      final m = rnk.members[i > 3 ? i - 1 : i];
      final isTop3 = m.rank <= 3;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTop3 ? Colors.green[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop3 ? Colors.green[200]! : Colors.grey[200]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isTop3 ? Colors.green[600] : Colors.grey[400],
              child: Text(
                '${m.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE0E0E0)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                m.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${m.point}p',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _promoteLine() => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(child: _gradientBar()),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[500],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.trending_up, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
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
        Expanded(child: _gradientBar()),
      ],
    ),
  );

  Widget _gradientBar() => Container(
    height: 2,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.orange[300]!, Colors.orange[500]!, Colors.orange[300]!],
      ),
    ),
  );

  /* util */
  Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24.0),
      child: CircularProgressIndicator(),
    ),
  );

  Widget _err(Object e, StackTrace? _) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e')),
  );
}
