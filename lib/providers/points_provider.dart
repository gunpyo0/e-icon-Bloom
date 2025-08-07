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
      final points = profile['totalPoints'] ?? 0;
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

  /// 포인트 추가 (낙관적 업데이트 + 서버 검증)
  Future<bool> addPoints(int points) async {
    final currentState = state;
    if (!currentState.hasValue) {
      await refresh(); // 상태가 없으면 먼저 로드
      return addPoints(points);
    }
    
    final currentPoints = currentState.value!;
    
    // 낙관적 업데이트
    final newTotal = currentPoints + points;
    state = AsyncValue.data(newTotal);
    print('Points added optimistically: +$points (total: $newTotal)');
    
    // 서버 검증 (1초 후)
    try {
      await Future.delayed(const Duration(seconds: 1));
      await refresh();
      
      final finalState = state;
      if (finalState.hasValue) {
        final serverPoints = finalState.value!;
        print('Server points after addition: $serverPoints');
        
        // 서버와 클라이언트 포인트가 예상과 다르면 경고
        if ((serverPoints - newTotal).abs() > 1) {
          print('⚠️ Point sync warning: Expected $newTotal, Server has $serverPoints');
        }
        return true;
      }
    } catch (e) {
      print('Error during point sync: $e');
      // 에러 발생 시 원래 포인트로 롤백
      state = AsyncValue.data(currentPoints);
      return false;
    }
    
    return true;
  }

  /// 포인트 차감 (낙관적 업데이트 + 서버 검증)
  Future<bool> subtractPoints(int points) async {
    final currentState = state;
    if (!currentState.hasValue) return false;
    
    final currentPoints = currentState.value!;
    if (currentPoints < points) {
      print('Insufficient points: $currentPoints < $points');
      return false;
    }
    
    // 낙관적 업데이트
    final newTotal = currentPoints - points;
    state = AsyncValue.data(newTotal);
    print('Points subtracted optimistically: -$points (total: $newTotal)');
    
    // 서버 검증 (1초 후)
    try {
      await Future.delayed(const Duration(seconds: 1));
      await refresh();
      
      final finalState = state;
      if (finalState.hasValue) {
        final serverPoints = finalState.value!;
        print('Server points after donation: $serverPoints');
        
        // 서버와 클라이언트 포인트가 예상과 다르면 경고
        if ((serverPoints - newTotal).abs() > 1) {
          print('⚠️ Point sync warning: Expected $newTotal, Server has $serverPoints');
        }
        return true;
      }
    } catch (e) {
      print('Error during point sync: $e');
      // 에러 발생 시 원래 포인트로 롤백
      state = AsyncValue.data(currentPoints);
      return false;
    }
    
    return true;
  }

  /// 포인트 직접 설정
  void setPoints(int points) {
    state = AsyncValue.data(points);
    print('Points set to: $points');
  }
  
  /// 강제 동기화 (서버에서 최신 포인트 가져오기)
  Future<void> forceSync() async {
    print('🔄 Forcing point synchronization...');
    await refresh();
    
    // 리그 포인트도 함께 동기화
    try {
      await EcoBackend.instance.syncMyLeaguePoints();
    } catch (e) {
      print('⚠️ League sync failed during force sync: $e');
    }
    
    final currentPoints = state.value ?? 0;
    print('✅ Points synchronized: $currentPoints');
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