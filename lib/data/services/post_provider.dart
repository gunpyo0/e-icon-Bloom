// lib/data/services/post_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/services/class.dart';
import 'package:bloom/data/services/user_provider.dart'; // userProfileProvider

/*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 1) Cloud Functions → EcoPost 리스트 변환
 *━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/
Future<List<EcoPost>> _fetchRawPosts() async {
  // ① Cloud Functions 호출
  final raw = await EcoBackend.instance.allPosts();

  // ② JSON → EcoPost 변환 & 최신순 정렬
  final posts = raw.map<EcoPost>((item) {
    final m = Map<String, dynamic>.from(item as Map);

    // 문서‑ID 확보 (혹시 모를 필드명 예외 처리)
    final id = (m['id'] ?? m['postId'] ?? m['docId'] ?? '').toString();

    // votes → EcoVote 리스트 변환
    final votesRaw = m['votes'];
    final List<EcoVote> votes = (votesRaw is List)
        ? votesRaw
              .whereType<Map>()
              .map((e) => EcoVote.fromEntry(Map<String, dynamic>.from(e)))
              .toList()
        : const [];

    return EcoPost.fromJson(id, {...m, 'votes': votes});
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return posts;
}

/*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 2) 내부 Provider – ①의 결과만 캐싱
 *━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

/*━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 3) 외부용 Provider – 이름 주입까지 마친 최종 리스트
 *━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/
Future<List<EcoPost>> fetchEnrichedPosts() async {
  // 1) Cloud Functions → EcoPost 기본 목록
  final raw = await EcoBackend.instance.allPosts();
  final List<EcoPost> basePosts = raw.map<EcoPost>((item) {
    final m = Map<String, dynamic>.from(item as Map);
    final id = (m['id'] ?? m['postId'] ?? m['docId'] ?? '').toString();

    // votes
    final votesRaw = m['votes'];
    final List<EcoVote> votes = (votesRaw is List)
        ? votesRaw
              .whereType<Map>()
              .map((e) => EcoVote.fromEntry(Map<String, dynamic>.from(e)))
              .toList()
        : const [];

    return EcoPost.fromJson(id, {...m, 'votes': votes});
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // 2) 포함된 모든 UID 모으기
  final Set<String> uids = {
    for (final p in basePosts) ...[
      p.authorUid,
      ...p.votes.map((v) => v.voterUid),
    ],
  };

  // 3) 프로필 일괄 조회
  final Map<String, EcoUser> profileMap = {};
  await Future.wait(
    uids.map((uid) async {
      final userJson = await EcoBackend.instance.anotherProfile(uid);
      profileMap[uid] = EcoUser.fromJson(uid, userJson);
    }),
  );

  // 4) 이름 주입
  final enriched = basePosts.map((p) {
    final authorName = profileMap[p.authorUid]?.displayName ?? 'Unknown';

    final votesFilled = p.votes
        .map(
          (v) => EcoVote(
            voterUid: v.voterUid,
            score: v.score,
            userName: profileMap[v.voterUid]?.displayName ?? v.userName,
          ),
        )
        .toList();

    return EcoPost(
      id: p.id,
      authorUid: p.authorUid,
      description: p.description,
      photoPath: p.photoPath,
      createdAt: p.createdAt,
      votes: votesFilled,
      userName: authorName,
    );
  }).toList();

  return enriched;
}
