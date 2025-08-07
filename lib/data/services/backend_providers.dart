// ──────────────────────────────────────────────
// lib/providers/backend_providers.dart
// ──────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // ‼️ 실시간 스트림용
import '../services/eco_backend.dart';

/* ① EcoBackend 싱글턴 */
final ecoBackendProvider =
Provider<EcoBackend>((_) => EcoBackend.instance);

/* ② FirebaseAuth User 스트림 */
final authUserProvider = StreamProvider<User?>(
      (ref) => ref.read(ecoBackendProvider).onAuthChanged,
);

/* ③ 내 프로필 */
final myProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final backend = ref.read(ecoBackendProvider);
  return backend.myProfile();
});

/* ④ 실시간 포인트 (totalPoints)  ─ Firestore doc 스트림으로 즉시 반영 */
final userPointsProvider = StreamProvider<int>((ref) {
  final userAsync = ref.watch(authUserProvider);      // 로그인 상태 의존
  return userAsync.when(
    data: (u) {
      if (u == null) return Stream<int>.value(0);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .snapshots()
          .map((d) => (d.data()?['point'] ?? 0) as int);
    },
    loading:   () => Stream<int>.value(0),
    error:     (_, __) => Stream<int>.value(0),
  );
});

/* ⑤ 내 리그 정보 */
final myLeagueProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final backend = ref.read(ecoBackendProvider);
  return backend.myLeague();
});

