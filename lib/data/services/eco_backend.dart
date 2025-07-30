// lib/services/eco_backend.dart
//  Flutter 3.16.x  /  Firebase SDK  11월 2025 기준

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// ⚡  EcoBackend  –  앱 전역에서 쓰이는 Firebase/CloudFunctions 래퍼
///    EcoBackend.instance 로 싱글턴 접근
class EcoBackend {
  /*───────────────────────── singleton ─────────────────────────*/
  EcoBackend._internal();
  static final EcoBackend instance = EcoBackend._internal();

  /*──────────────────── Firebase root 인스턴스 ───────────────────*/
  final _auth   = FirebaseAuth.instance;
  final _fs     = FirebaseFirestore.instance;
  final _func   = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  final _store  = FirebaseStorage.instance;

  /*╔═══════════════════════  인증  ═══════════════════════╗*/
  /// 현재 Firebase User  (로그아웃 상태면 null)
  User? get currentUser => _auth.currentUser;
  String get uidOrEmpty => _auth.currentUser?.uid ?? '';

  /// auth 변경 스트림 – ex) Provider listen
  Stream<User?> get onAuthChanged => _auth.userChanges();

  /// ▸ Google 로그인 (웹/모바일 자동 처리)
  Future<UserCredential> signInWithGoogle() async {
  final auth = FirebaseAuth.instance;

  if (kIsWeb) {
    // ───────── WEB ─────────
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});
    return await auth.signInWithPopup(provider);
  } else {
    // ───────── Android / iOS ─────────
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('로그인 취소됨');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await auth.signInWithCredential(credential);
  }
}

  /// ▸ 이메일/패스워드 로그인
  Future<UserCredential> signIn(String email, String pw)
      => _auth.signInWithEmailAndPassword(email: email, password: pw);

  /// ▸ 회원가입
  Future<UserCredential> signUp(String email, String pw)
      => _auth.createUserWithEmailAndPassword(email: email, password: pw);

  /// ▸ 로그아웃
  Future<void> signOut() async {
    await GoogleSignIn().signOut().catchError((_) {});
    await _auth.signOut();
  }
  /*╚══════════════════════════════════════════════════════╝*/

  /*───────────────────────── Profile ──────────────────────────*/
  Future<Map<String, dynamic>> myProfile() async =>
      (await _func.httpsCallable('getMyProfile').call()).data;

  Future<Map<String, dynamic>> myLeague() async =>
      (await _func.httpsCallable('getMyLeague').call()).data;

  Future<Map<String, dynamic>> anotherProfile(String uid) async =>
      (await _func.httpsCallable('getUserProfile')
                .call({'targetUid': uid})).data;

  /*──────────────────────── Lessons ───────────────────────────*/
  Future<void> completeLessons(List<String> ids) =>
      _func.httpsCallable('completeLesson').call({'lessonIds': ids});

  /*──────────────────────── Garden ────────────────────────────*/
  Future<Map<String, dynamic>> myGarden() async =>
      (await _func.httpsCallable('getMyGarden').call()).data;

  Future<Map<String, dynamic>> otherGarden(String uid) async =>
      (await _func.httpsCallable('getUserGarden')
                .call({'targetUid': uid})).data;

  Future<void> plantCrop(int x, int y, String cropId) =>
      _func.httpsCallable('plantCrop').call({'x': x, 'y': y, 'cropId': cropId});

  Future<void> progressCrop(int x, int y) =>
      _func.httpsCallable('progressCrop').call({'x': x, 'y': y});

  Future<void> harvestCrop(int x, int y) =>
      _func.httpsCallable('harvestCrop').call({'x': x, 'y': y});

  /*──────────────────────── Posts ────────────────────────────*/
  /// ① 새 글 생성 → Storage 업로드 경로 반환
  Future<({String postId, String storagePath})> createPost({
    required String description,
    File? image,
  }) async {
    final res = await _func.httpsCallable('createPost')
                           .call({'description': description, 'extension': 'jpg'});
    final postId      = res.data['postId']     as String;
    final storagePath = res.data['storagePath'] as String;

    if (image != null) {
      await _store.ref(storagePath).putFile(image);
    }
    return (postId: postId, storagePath: storagePath);
  }

  /// ② 투표
  Future<void> votePost(String postId, int score) =>
      _func.httpsCallable('votePost').call({'postId': postId, 'score': score});

  /// ③ 피드
  Future<List<dynamic>> unvotedPosts() async =>
      (await _func.httpsCallable('listUnvotedPosts').call()).data as List<dynamic>;

  Future<List<dynamic>> allPosts() async =>
      (await _func.httpsCallable('listAllPosts').call()).data as List<dynamic>;

  /*──────────────── Stream / 실시간 순위표 ────────────────────*/
  Stream<QuerySnapshot<Map<String, dynamic>>> leagueMembers(String leagueId) =>
      _fs.collection('leagues').doc(leagueId).collection('members')
         .orderBy('point', descending: true).snapshots();
}