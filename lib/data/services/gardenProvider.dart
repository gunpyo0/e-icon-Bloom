import 'package:bloom/data/models/crop.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gardenProvider = FutureProvider<Garden>((ref) async {
  final gData = await EcoBackend.instance.myGarden(); // 정원
  final meData = await EcoBackend.instance.myProfile(); // 사용자

  gData['playerCoins'] = meData['point'] ?? 0; // 🔑 병합
  return Garden.fromJson(gData);
});
