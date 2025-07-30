// lib/screens/eco_debug_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/eco_backend.dart';      // ← 방금 확장한 싱글턴 래퍼
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EcoDebugPage extends StatefulWidget {
  const EcoDebugPage({super.key});
  @override
  State<EcoDebugPage> createState() => _EcoDebugPageState();
}

class _EcoDebugPageState extends State<EcoDebugPage> {
  final _b = EcoBackend.instance;
  final _log = <String>[];                 // 최근 로그 보관

  /* util – 로그   --------------------------------------------------- */
  void _addLog(Object o) {
    final ts = DateFormat.Hms().format(DateTime.now());
    setState(() => _log.insert(0, '[$ts] $o'));
  }

  /* util –﻿ 이미지 픽커   ------------------------------------------- */
  Future<File?> _pickImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1024);
    return x != null ? File(x.path) : null;
  }

  /* ---------------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco‑app All‑in‑One Debug'),
        actions: [
          StreamBuilder<User?>(
            stream: _b.onAuthChanged,
            builder: (_, snap) {
              final user = snap.data;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(user?.email ?? '로그아웃 상태')),
              );
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [

          /*────────── 인증 ─────────*/
          const Text('🟢 Auth', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                  onPressed: () async {
                    await _b.signInWithGoogle();
                    _addLog('✅ Google 로그인 완료');
                  },
                  child: const Text('Google Sign‑in')),
              ElevatedButton(
                  onPressed: () async {
                    await _b.signOut();
                    _addLog('🚪 로그아웃 완료');
                  },
                  child: const Text('Sign‑out')),
            ],
          ),
          const Divider(),

          /*────────── 프로필 / 리그 ─────────*/
          const Text('🟢 Profile / League'),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                  onPressed: () async => _addLog(await _b.myProfile()),
                  child: const Text('myProfile')),
              ElevatedButton(
                  onPressed: () async => _addLog(await _b.myLeague()),
                  child: const Text('myLeague')),
            ],
          ),
          const Divider(),

          /*────────── 레슨 ─────────*/
          const Text('🟢 Lessons'),
          ElevatedButton(
              onPressed: () async {
                // 예시: 임의 두 과목 완료
                await _b.completeLessons(['edu101', 'edu102']);
                _addLog('🎓 lessons edu101, edu102 완료');
              },
              child: const Text('complete demo lessons')),
          const Divider(),

          /*────────── Garden ─────────*/
          const Text('🟢 Garden'),
          Wrap(spacing: 8, children: [
            ElevatedButton(
                onPressed: () async => _addLog(await _b.myGarden()),
                child: const Text('myGarden')),
            ElevatedButton(
                onPressed: () async {
                  await _b.plantCrop(0, 0, 'carrot');
                  _addLog('🌱 (0,0) carrot 심기 OK');
                },
                child: const Text('plant (0,0) carrot')),
            ElevatedButton(
                onPressed: () async {
                  await _b.progressCrop(0, 0);
                  _addLog('🔼 (0,0) 성장 진행');
                },
                child: const Text('progress (0,0)')),
            ElevatedButton(
                onPressed: () async {
                  await _b.harvestCrop(0, 0);
                  _addLog('🧺 (0,0) 수확 완료');
                },
                child: const Text('harvest (0,0)')),
          ]),
          const Divider(),

          /*────────── Posts ─────────*/
          const Text('🟢 Posts'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                  onPressed: () async {
                    final img = await _pickImage();
                    final res = await _b.createPost(
                        description: 'debug‑post', image: img);
                    _addLog('📸 post ${res.postId} 업로드 완료');
                  },
                  child: const Text('createPost (gallery)')),
              ElevatedButton(
                  onPressed: () async => _addLog(await _b.unvotedPosts()),
                  child: const Text('listUnvotedPosts')),
              ElevatedButton(
                  onPressed: () async => _addLog(await _b.allPosts()),
                  child: const Text('listAllPosts')),
              ElevatedButton(
                  onPressed: () async {
                    final list = await _b.unvotedPosts();
                    if (list.isEmpty) {
                      _addLog('⚠️ 투표할 글이 없음');
                      return;
                    }
                    final id = list.first['id'] as String;
                    await _b.votePost(id, 10);
                    _addLog('🗳️ 글 $id 에 10점 투표');
                  },
                  child: const Text('vote first unvoted (10)')),
            ],
          ),
          const Divider(),

          /*────────── League 실시간 랭킹 스트림 ─────────*/
          const Text('🟢 Live Ranking Stream'),
          ElevatedButton(
              onPressed: () async {
                final leagueId = (await _b.myLeague())['leagueId'];
                if (leagueId == null) return _addLog('리그 없음');
                _addLog('📡 스트림 listen 시작…');
                _b.leagueMembers(leagueId).listen((snap) {
                  _addLog('▶️ ${snap.docs.map((d) => '${d.id}:${d["point"]}').toList()}');
                });
              },
              child: const Text('listen league stream')),
          const SizedBox(height: 24),

          /*────────── 로그 출력 ─────────*/
          const Text('⇣  LOG', style: TextStyle(fontWeight: FontWeight.bold)),
          Container(
            height: 300,
            padding: const EdgeInsets.all(8),
            color: Colors.black12,
            child: SingleChildScrollView(
              reverse: true,
              child: Text(_log.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }
}