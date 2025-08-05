import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';

/// 포인트 상태 관리를 위한 StateNotifier
class PointsNotifier extends StateNotifier<AsyncValue<int>> {
  Timer? _refreshTimer;
  
  PointsNotifier() : super(const AsyncValue.loading()) {
    loadPoints();
    _startPeriodicRefresh();
    // Global notifier 설정
    setGlobalPointsNotifier(this);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 주기적 새로고침 시작 (30초마다)
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
  }

  /// 포인트 로드 (프로필과 동일한 데이터 소스 사용)
  Future<void> loadPoints() async {
    try {
      state = const AsyncValue.loading();
      // myProfile()에서 totalPoints를 가져와서 일관성 보장
      final profile = await EcoBackend.instance.myProfile();
      final points = profile['point'] ?? 0;
      state = AsyncValue.data(points);
      print('Points loaded from profile: $points');
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      print('Error loading points: $error');
    }
  }

  /// 포인트 새로고침
  Future<void> refresh() async {
    await loadPoints();
  }

  /// 포인트 추가 (즉시 UI 업데이트 + 서버 동기화)
  void addPoints(int points) {
    state.whenData((currentPoints) {
      state = AsyncValue.data(currentPoints + points);
      print('Points added: +$points (total: ${currentPoints + points})');
      // 서버와 동기화를 위해 잠시 후 새로고침
      Future.delayed(const Duration(milliseconds: 500), () => refresh());
    });
  }

  /// 포인트 차감 (즉시 UI 업데이트 + 서버 동기화)
  void subtractPoints(int points) {
    state.whenData((currentPoints) {
      final newTotal = (currentPoints - points).clamp(0, double.infinity).toInt();
      state = AsyncValue.data(newTotal);
      print('Points subtracted: -$points (total: $newTotal)');
      // 서버와 동기화를 위해 잠시 후 새로고침
      Future.delayed(const Duration(milliseconds: 500), () => refresh());
    });
  }

  /// 포인트 직접 설정
  void setPoints(int points) {
    state = AsyncValue.data(points);
    print('Points set to: $points');
  }
}

/// 포인트 상태 Provider
final pointsProvider = StateNotifierProvider<PointsNotifier, AsyncValue<int>>(
  (ref) => PointsNotifier(),
);

/// Global 포인트 알림 함수 (EcoBackend에서 사용)
PointsNotifier? _globalPointsNotifier;

void setGlobalPointsNotifier(PointsNotifier notifier) {
  _globalPointsNotifier = notifier;
}

void notifyPointsChanged() {
  _globalPointsNotifier?.refresh();
}