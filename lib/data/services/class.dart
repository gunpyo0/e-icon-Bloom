// lib/data/models/league_ranking.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

DateTime? _toDate(dynamic v) {
  // ① 이미 Timestamp 인스턴스
  if (v is Timestamp) return v.toDate();

  // ② 1970 epoch milliseconds 숫자
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);

  // ③ Cloud Functions JSON: { _seconds / seconds , _nanoseconds / nanoseconds }
  if (v is Map) {
    final sec = v['_seconds'] ?? v['seconds'];
    final nano = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
    if (sec is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        sec * 1000 + (nano ~/ 1e6) as int,
      );
    }
  }

  // ④ ISO‑8601 문자열
  if (v is String) return DateTime.tryParse(v);

  return null; // 파싱 실패
}

/// 개별 멤버
class LeagueMember {
  final String uid;
  final String displayName; // 표기를 위해 users/{uid}.displayName 도 함께 받습니다
  final int point;
  final int rank; // 1‑based

  const LeagueMember({
    required this.uid,
    required this.displayName,
    required this.point,
    required this.rank,
  });

  /// Firestore members 서브컬렉션의 DocumentSnapshot 과
  /// users/{uid} 스냅(또는 Map) 을 합쳐 한 객체로
  factory LeagueMember.fromDocs({
    required DocumentSnapshot<Map<String, dynamic>> memberDoc,
    required Map<String, dynamic>? userJson,
    required int rank,
  }) {
    final data = memberDoc.data()!;
    return LeagueMember(
      uid: memberDoc.id,
      displayName: userJson?['displayName'] as String? ?? 'Unknown',
      point: data['point'] as int? ?? 0,
      rank: rank,
    );
  }
}

/// 리그 전체 랭킹
class LeagueRanking {
  final String leagueId;
  final List<LeagueMember> members; // point 내림차순

  const LeagueRanking({required this.leagueId, required this.members});

  /// members 스냅 + users 컬렉션 스냅을 한 번에 받아 변환
  factory LeagueRanking.fromSnapshots({
    required String leagueId,
    required QuerySnapshot<Map<String, dynamic>> memberSnap,
    required QuerySnapshot<Map<String, dynamic>> usersSnap,
  }) {
    // usersSnap 을 uid -> json 맵으로
    final userMap = {for (final d in usersSnap.docs) d.id: d.data()};

    final list = <LeagueMember>[];
    for (var i = 0; i < memberSnap.docs.length; i++) {
      final doc = memberSnap.docs[i];
      list.add(
        LeagueMember.fromDocs(
          memberDoc: doc,
          userJson: userMap[doc.id],
          rank: i + 1, // 이미 point 로 정렬된 상태
        ),
      );
    }

    return LeagueRanking(leagueId: leagueId, members: list);
  }
}

class MyLeagueInfo {
  final String? leagueId;
  final int? rank;
  final int? memberCount;

  const MyLeagueInfo({this.leagueId, this.rank, this.memberCount});

  factory MyLeagueInfo.fromJson(Map<String, dynamic> j) => MyLeagueInfo(
    leagueId: j['leagueId'] as String?,
    rank: (j['rank'] ?? 0) as int?,
    memberCount: (j['memberCount'] ?? 0) as int?,
  );
}

/// ▌투표 1건 → EcoVote  (별도 댓글 필드는 아직 없음)
class EcoVote {
  final String voterUid; // 투표자 UID
  final int score; // 0 / 10 / 20 / 30
  final String userName;
  const EcoVote({
    required this.voterUid,
    required this.score,
    required this.userName,
  });

  factory EcoVote.fromEntry(Map<String, dynamic> json) {
    return EcoVote(
      voterUid: json["uid"],
      score: json["score"].toInt(),
      userName: json["userName"] ?? 'Anonymous',
    );
  }
}

/// ▌게시글 1건 → EcoPost
class EcoPost {
  final String id; // doc id
  final String authorUid;
  final String description;
  final String photoPath; // gs://.. or posts/{id}.jpg
  final DateTime createdAt;
  final String? userName; // 유저 이름은 별도 가져와야 함
  final List<EcoVote> votes;

  const EcoPost({
    required this.id,
    required this.authorUid,
    required this.description,
    required this.photoPath,
    required this.createdAt,
    required this.votes,
    required this.userName,
  });

  /*────────────── JSON → 객체 ─────────────*/
  factory EcoPost.fromJson(String id, Map<String, dynamic> json) {
    // get user name
    return EcoPost(
      id: id,
      authorUid: json['authorUid'] as String? ?? '',
      description: json['description'] as String? ?? '',
      photoPath: json['photoPath'] as String? ?? '',
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      votes:
          (json['votes'] as List<dynamic>?)
              ?.map((e) => EcoVote.fromEntry(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      userName: json['userName'] as String?,
    );
  }

  /*────────────── 편의 프로퍼티 ─────────────*/
  double get averageScore => votes.isEmpty
      ? 0
      : votes.map((v) => v.score).reduce((a, b) => a + b) / votes.length;

  /// Storage 경로를 HTTPS URL 로 변환
  Future<String?> get downloadUrl async {
    if (photoPath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(photoPath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}

class EcoUser {
  EcoUser({
    required this.uid,
    required this.displayName,
    required this.point,
    required this.gardenLevel,
    required this.leagueId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final int point; // 현재 보유 포인트
  final int gardenLevel; // 0 = 씨앗
  final String? leagueId; // 속한 리그 ID
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Firestore / Cloud Functions 응답 → 객체로 변환
  factory EcoUser.fromJson(String uid, Map<String, dynamic> json) {
    return EcoUser(
      uid: uid,
      displayName: json['displayName']?.toString() ?? 'Anonymous',
      point: json['point'] as int? ?? 0,
      gardenLevel: json['gardenLevel'] as int? ?? 0,
      leagueId: json['leagueId']?.toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }
}
