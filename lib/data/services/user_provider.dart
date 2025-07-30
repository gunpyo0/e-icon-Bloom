// lib/data/services/user_provider.dart
import 'package:bloom/data/services/class.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';

/// 특정 uid 의 프로필을 받아오는纯 Future 함수
Future<EcoUser> fetchUserByUid(String uid) async {
  // Cloud Functions: getUserProfile 호출
  final json = await EcoBackend.instance.anotherProfile(uid);
  return EcoUser.fromJson(uid, json);
}

/// Riverpod FutureProvider family (UI 에서 바로 사용 가능)
final userProfileProvider = FutureProvider.family<EcoUser, String>((
  ref,
  uid,
) async {
  return fetchUserByUid(uid);
});
