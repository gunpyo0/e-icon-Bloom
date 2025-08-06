// lib/ui/screens/unity_full_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

/// ─────────────────────────────────────────
///   UnityFullScreen  –  오직 유니티만!
///   • 아무 위젯도 덮지 않고 풀스크린
/// ─────────────────────────────────────────
class UnityFullScreen extends StatefulWidget {
  const UnityFullScreen({super.key});

  @override
  State<UnityFullScreen> createState() => _UnityFullScreenState();
}

class _UnityFullScreenState extends State<UnityFullScreen> {
  UnityWidgetController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 검은 배경으로 로딩 중 여백도 깔끔하게
      backgroundColor: Colors.black,
      body: UnityWidget(
        onUnityCreated: (ctrl) => _controller = ctrl,
        onUnityMessage: (msg) => debugPrint('💌 from Unity: $msg'),
        useAndroidViewSurface: true,   // 멀티터치·성능 안정
        fullscreen: true,              // 플러그인 자체 풀스크린
        placeholder: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.pause();
    super.dispose();
  }
}
