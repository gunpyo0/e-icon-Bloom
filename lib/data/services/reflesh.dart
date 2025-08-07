import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'eco_backend.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'eco_backend.dart';

/// Flutter → Unity
/// { point, gardens:[{ uid,name,tiles:[{grassStage,cropType},…] }] } 전송
Future<void> pushRealGardenData(UnityWidgetController unity) async {
  try {
    /* 0) 내 포인트 ---------------------------------------------------- */
    final myPoint = await EcoBackend.instance.getUserPoints();

    /* 1) 리그 전체 정원 ------------------------------------------------ */
    final gardens = await EcoBackend.instance.getLeagueMembersGardens();
    debugPrint('[pushRealGardenData] RAW gardens: $gardens');

    /* 2) Unity 요구 포맷으로 변환 ------------------------------------ */
    final converted = gardens.take(9).map<Map<String, dynamic>>((g) {
      /* (1) 멤버 메타 */
      final member = Map<String, dynamic>.from(g['memberInfo'] ?? {});
      final uid    = member['uid']           ?? '';
      final name   = member['displayName']   ?? 'Unknown';

      /* (2) tiles Map → length 9 List */
      final rawTiles = Map<String, dynamic>.from(g['tiles'] ?? {});
      final tileList = List.generate(9, (idx) {
        // 3×3 좌표 계산
        final x = idx ~/ 3;
        final y = idx % 3;

        dynamic tileRaw;
        // ① 인덱스 키 "0"…"8"
        if (rawTiles.containsKey(idx.toString())) {
          tileRaw = rawTiles[idx.toString()];
        }
        // ② 좌표 키 "x,y"
        else if (rawTiles.containsKey('$x,$y')) {
          tileRaw = rawTiles['$x,$y'];
        }

        if (tileRaw is Map) {
          final t = Map<String, dynamic>.from(tileRaw);
          return {
            'grassStage': t['stage']   ?? 0,
            'cropType'  : t['cropId'] ?? 'none',
          };
        }
        // 키가 없으면 빈 타일
        return { 'grassStage': 0, 'cropType': 'none' };
      });

      return { 'uid': uid, 'name': name, 'tiles': tileList };
    }).toList(growable: false);

    debugPrint('[pushRealGardenData] CONVERTED: $converted');

    /* 3) JSON 직렬화 -------------------------------------------------- */
    final payload = jsonEncode({ 'point': myPoint, 'gardens': converted });
    debugPrint('[pushRealGardenData] ▶ payload: $payload');

    /* 4) Unity로 전송 ------------------------------------------------- */
    unity.postMessage('dataManager', 'RefreshFromFlutter', payload);
    debugPrint('[pushRealGardenData] 🚀 Sent garden data to Unity');
  } catch (e, st) {
    debugPrint('[pushRealGardenData] 🔥 Error: $e\n$st');
  }
}
