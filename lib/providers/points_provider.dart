import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';

/// 포인트 상태 관리를 위한 StateNotifier
class PointsNotifier extends StateNotifier<AsyncValue<int>> {
  PointsNotifier() : super(const AsyncValue.loading()) {
    loadPoints();
  }

  /// 포인트 로드
  Future<void> loadPoints() async {
    try {
      state = const AsyncValue.loading();
      final points = await EcoBackend.instance.getUserPoints();
      state = AsyncValue.data(points);
      print('Points loaded: $points');
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      print('Error loading points: $error');
    }
  }

  /// 포인트 새로고침
  Future<void> refresh() async {
    await loadPoints();
  }

  /// 포인트 추가
  void addPoints(int points) {
    state.whenData((currentPoints) {
      state = AsyncValue.data(currentPoints + points);
      print('Points added: +$points (total: ${currentPoints + points})');
    });
  }

  /// 포인트 차감
  void subtractPoints(int points) {
    state.whenData((currentPoints) {
      final newTotal = (currentPoints - points).clamp(0, double.infinity).toInt();
      state = AsyncValue.data(newTotal);
      print('Points subtracted: -$points (total: $newTotal)');
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