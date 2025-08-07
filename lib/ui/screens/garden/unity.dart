// lib/ui/screens/unity_full_screen.dart
//--------------------------------------------------------------
import 'dart:convert';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/services/reflesh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

class UnityFullScreen extends StatefulWidget {
  const UnityFullScreen({super.key});
  @override
  State<UnityFullScreen> createState() => _UnityFullScreenState();
}

class _UnityFullScreenState extends State<UnityFullScreen>
    with WidgetsBindingObserver {
  UnityWidgetController? _ctrl;

  /* ───────────────── 생명주기 ───────────────── */
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ctrl != null) {
      pushRealGardenData(_ctrl!);          // 앱 복귀 시 무조건 리프레시
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.pause();
    super.dispose();
  }

  /* ──────────── Unity ↔ Flutter 브리지 ──────────── */

  /* ───────────── UI (Unity 위젯) ───────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: UnityWidget(
        useAndroidViewSurface: true,
        fullscreen: true,
        placeholder: const Center(child: CircularProgressIndicator()),
        onUnityCreated: (c) async {
          _ctrl = c;
          await pushRealGardenData(c);               // 최초 한 번
        },
        onUnityMessage: (msg) async {
          final raw = msg;                            // ★ msg.value → msg.data
          debugPrint('⚠️제츠보제츠보');
          final Map<String, dynamic> m = raw is Map
              ? Map<String, dynamic>.from(raw)
              : Map<String, dynamic>.from(jsonDecode(raw));

          final action    = m['action']    as String?;
          final tileIndex = m['tileIndex'] as int?;
          final cropType  = m['cropType']  as String? ?? 'none';

          if (action == null || tileIndex == null) return;

          // 2) 행위별 Cloud Function 호출 ---------------------------------
          switch (action) {
            case 'add':
              await EcoBackend.instance.plantTileArray(tileIndex, cropType);
              break;
            case 'delete':
              await EcoBackend.instance.removeTileArray(tileIndex);
              break;
            case 'update':      // Unity 쪽에서 stage 1칸 ↑ 후 보내므로 upgrade 1회
              await EcoBackend.instance.upgradeTileArray(tileIndex);
              break;
            default:
              debugPrint('⚠️  Unknown action from Unity: $action');
          }
          await pushRealGardenData(_ctrl!);// ★ 변경된 부분
        }

      ),
    );
  }
}
