import 'package:bloom/data/services/class.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/eco_backend.dart';

/// ───────────────────────────────────────────────
/// ① 내가 속한 리그 정보  (한 번만 가져오는 Future)
///    getMyLeague Cloud Function 결과를
///    MyLeagueInfo 모델로 매핑
/// ───────────────────────────────────────────────
final myLeagueProvider = FutureProvider.autoDispose<MyLeagueInfo>((ref) async {
  final raw = await EcoBackend.instance.myLeague(); // Map<String,dynamic>
  return MyLeagueInfo.fromJson(raw);
});

/// ───────────────────────────────────────────────
/// ② 특정 리그의 실시간 랭킹  (StreamProvider.family)
///    leagueId 로 구독
/// ───────────────────────────────────────────────
final rankingProvider = StreamProvider.autoDispose
    .family<LeagueRanking, String>(
      (ref, leagueId) => EcoBackend.instance.rankingStream(leagueId),
    );
