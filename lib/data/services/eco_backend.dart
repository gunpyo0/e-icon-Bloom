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

  Future<Map<String, dynamic>> myLeague() async {
    try {
      // 임시로 Cloud Function 대신 클라이언트에서 직접 처리
      return await _getMyLeagueLocal();
    } catch (e) {
      print('Local league lookup failed, trying cloud function: $e');
      // 실패하면 원래 방식 시도
      return (await _func.httpsCallable('getMyLeague').call()).data;
    }
  }

  Future<Map<String, dynamic>> _getMyLeagueLocal() async {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw Exception('No authenticated user');
    }

    print('Looking up league for user: $uid');

    // Find leagues where user is a member
    final leaguesSnapshot = await _fs.collection('leagues').get();
    
    for (final leagueDoc in leaguesSnapshot.docs) {
      final leagueId = leagueDoc.id;
      final leagueData = leagueDoc.data();
      
      // Check if user is member of this league
      final memberDoc = await _fs
          .collection('leagues')
          .doc(leagueId)
          .collection('members')
          .doc(uid)
          .get();
      
      if (memberDoc.exists) {
        // Get all members ordered by points (descending)
        final membersSnapshot = await _fs
            .collection('leagues')
            .doc(leagueId)
            .collection('members')
            .orderBy('point', descending: true)
            .get();
        
        // Calculate actual rank and member count
        int rank = 1;
        int actualMemberCount = 0;
        
        for (int i = 0; i < membersSnapshot.docs.length; i++) {
          final doc = membersSnapshot.docs[i];
          final memberData = doc.data();
          // Only count valid members (with displayName)
          if (memberData['displayName'] != null && 
              memberData['displayName'].toString().trim().isNotEmpty) {
            actualMemberCount++;
            if (doc.id == uid) {
              rank = actualMemberCount; // Use actual rank based on valid members
            }
          }
        }
        
        print('User found in league $leagueId, rank: $rank, members: $actualMemberCount');
        
        return {
          'leagueId': leagueId,
          'league': {
            ...leagueData,
            'memberCount': actualMemberCount // Use actual member count
          },
          'rank': rank,
          'memberCount': actualMemberCount
        };
      }
    }
    
    // User not in any league
    print('User $uid not found in any league');
    return {
      'leagueId': null,
      'league': null,
      'rank': null,
      'memberCount': 0
    };
  }

  Future<Map<String, dynamic>> anotherProfile(String uid) async =>
      (await _func.httpsCallable('getUserProfile')
                .call({'targetUid': uid})).data;

  /*──────────────────────── Lessons ───────────────────────────*/
  Future<void> completeLessons(List<String> ids) =>
      _func.httpsCallable('completeLesson').call({'lessonIds': ids});

  /*──────────────────────── Garden ────────────────────────────*/
  Future<Map<String, dynamic>> myGarden() async {
    try {
      return (await _func.httpsCallable('getMyGarden').call()).data;
    } catch (e) {
      print('Cloud Function failed, returning mock garden data: $e');
      // Cloud Function이 실패하면 임시 데이터 반환
      return {
        'size': 3,
        'point': 100,
        'tiles': {
          "0,0": {'stage': 0}, // 0 = empty
          "0,1": {'stage': 0},
          "0,2": {'stage': 0},
          "1,0": {'stage': 0},
          "1,1": {'stage': 0},
          "1,2": {'stage': 0},
          "2,0": {'stage': 0},
          "2,1": {'stage': 0},
          "2,2": {'stage': 0},
        }
      };
    }
  }

  Future<Map<String, dynamic>> otherGarden(String uid) async =>
      (await _func.httpsCallable('getUserGarden')
                .call({'targetUid': uid})).data;

  Future<void> plantCrop(int x, int y, String cropId) =>
      _func.httpsCallable('plantCrop').call({'x': x, 'y': y, 'cropId': cropId});

  Future<void> progressCrop(int x, int y) =>
      _func.httpsCallable('progressCrop').call({'x': x, 'y': y});

  Future<void> harvestCrop(int x, int y) =>
      _func.httpsCallable('harvestCrop').call({'x': x, 'y': y});

  Future<void> addPoints(int amount) =>
      _func.httpsCallable('addPoints').call({'amount': amount});

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

  Future<void> deleteAllPosts() async =>
      (await _func.httpsCallable('deleteAllPosts').call());

  /*──────────────── Stream / 실시간 순위표 ────────────────────*/
  Stream<QuerySnapshot<Map<String, dynamic>>> leagueMembers(String leagueId) =>
      _fs.collection('leagues').doc(leagueId).collection('members')
         .orderBy('point', descending: true).snapshots();

  /*──────────────────── 자동 리그 참여 (최대 7명) ────────────────────*/  
  Future<void> ensureUserInLeague() async {
    final uid = currentUser?.uid;
    print('=== ensureUserInLeague called with uid: $uid ===');
    if (uid == null) {
      print('No current user, skipping league join');
      return;
    }

    try {
      // 이미 리그에 속해있는지 확인
      print('Checking if user is already in a league...');
      final userLeague = await myLeague();
      print('Current league status: $userLeague');
      if (userLeague['leagueId'] != null) {
        print('User already in league: ${userLeague['leagueId']}');
        return; // 이미 리그에 속해있음
      }
    } catch (e) {
      print('User not in league yet (expected): $e');
      // 리그에 속해있지 않음, 계속 진행
    }

    try {
      print('Looking for available leagues...');
      // 7명 미만인 리그 찾기
      final leaguesQuery = await _fs.collection('leagues')
          .where('memberCount', isLessThan: 7)
          .orderBy('memberCount', descending: true)
          .limit(1)
          .get();

      String leagueId;
      
      if (leaguesQuery.docs.isNotEmpty) {
        // 기존 리그에 참여
        leagueId = leaguesQuery.docs.first.id;
        print('Found existing league: $leagueId with ${leaguesQuery.docs.first.data()['memberCount']} members');
        
        try {
          // 리그 멤버수 증가
          await _fs.collection('leagues').doc(leagueId).update({
            'memberCount': FieldValue.increment(1),
          });
          print('Updated league member count');
        } catch (updateError) {
          print('Error updating member count: $updateError');
          // 계속 진행 (멤버 추가는 시도)
        }
      } else {
        // 새 리그 생성
        final newLeagueRef = _fs.collection('leagues').doc();
        leagueId = newLeagueRef.id;
        print('Creating new league: $leagueId');
        
        try {
          await newLeagueRef.set({
            'name': 'League ${DateTime.now().millisecondsSinceEpoch}',
            'memberCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('New league created');
        } catch (createError) {
          print('Error creating league: $createError');
          throw createError; // 리그 생성 실패시 중단
        }
      }

      // 사용자를 리그 멤버로 추가
      final displayName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'User';
      print('Adding user to league with displayName: $displayName');
      
      final memberData = {
        'uid': uid,
        'displayName': displayName,
        'point': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      };
      print('Member data to add: $memberData');
      
      await _fs.collection('leagues').doc(leagueId).collection('members').doc(uid).set(memberData);
      print('Firestore write completed');

      // 추가 확인: 실제로 추가되었는지 확인
      final addedDoc = await _fs.collection('leagues').doc(leagueId).collection('members').doc(uid).get();
      print('Verification - Document exists: ${addedDoc.exists}');
      if (addedDoc.exists) {
        print('Verification - Document data: ${addedDoc.data()}');
      }

      print('User successfully joined league: $leagueId');
    } catch (e) {
      print('Failed to join league: $e');
      print('Error details: ${e.toString()}');
    }
  }

  /*──────────────────── 리그 멤버 백업/복구 ────────────────────*/
  Future<void> backupLeagueMembers() async {
    try {
      print('=== BACKING UP LEAGUE MEMBERS ===');
      
      // 먼저 기존 사용자들 찾기
      await _findExistingUsers();
      
      // 알려진 사용자들을 다시 추가
      final knownUsers = [
        {
          'uid': 'AFMf69C8UkWutorsxQnUToAurTI2', // 임건표의 UID
          'displayName': '임건표',
          'point': 0,
        },
        {
          'uid': currentUser?.uid, // 현재 사용자
          'displayName': currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'User',  
          'point': 0,
        },
      ];

      // s1l1 리그에 멤버들 추가
      const leagueId = 's1l1';
      
      for (final user in knownUsers) {
        if (user['uid'] != null && user['uid'].toString().isNotEmpty) {
          try {
            await _fs.collection('leagues').doc(leagueId).collection('members').doc(user['uid'].toString()).set({
              'uid': user['uid'],
              'displayName': user['displayName'],
              'point': user['point'],
              'joinedAt': FieldValue.serverTimestamp(),
            });
            print('Added user: ${user['displayName']} (${user['uid']})');
          } catch (e) {
            print('Failed to add user ${user['displayName']}: $e');
          }
        }
      }

      // 리그 정보도 복구
      await _fs.collection('leagues').doc(leagueId).set({
        'stage': 1,
        'index': 1,
        'memberCount': knownUsers.where((u) => u['uid'] != null).length,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('League backup completed for league: $leagueId');
      
    } catch (e) {
      print('Error during backup: $e');
    }
  }

  /*──────────────────── 기존 사용자 찾기 ────────────────────*/
  Future<void> _findExistingUsers() async {
    try {
      print('=== FINDING EXISTING USERS ===');
      
      // 모든 리그에서 기존 멤버들 찾기
      final leaguesSnapshot = await _fs.collection('leagues').get();
      
      for (final leagueDoc in leaguesSnapshot.docs) {
        final leagueId = leagueDoc.id;
        print('Checking league: $leagueId');
        
        final membersSnapshot = await _fs
            .collection('leagues')
            .doc(leagueId)
            .collection('members')
            .get();
        
        for (final memberDoc in membersSnapshot.docs) {
          final memberData = memberDoc.data();
          final uid = memberDoc.id;
          final displayName = memberData['displayName'] ?? 'Unknown';
          print('Found existing member: $displayName (UID: $uid)');
          
          // mb M을 찾으면 별도 로그
          if (displayName.toLowerCase().contains('mb') || displayName.toLowerCase().contains('m')) {
            print('*** POTENTIAL MB M USER: $displayName (UID: $uid) ***');
          }
        }
      }
      
    } catch (e) {
      print('Error finding existing users: $e');
    }
  }

  /*──────────────────── 현재 리그 상태 확인 ────────────────────*/
  Future<void> checkLeagueStatus() async {
    try {
      print('=== LEAGUE STATUS CHECK ===');
      
      final leaguesSnapshot = await _fs.collection('leagues').get();
      
      for (final leagueDoc in leaguesSnapshot.docs) {
        final leagueId = leagueDoc.id;
        final leagueData = leagueDoc.data();
        
        print('League: $leagueId');
        print('Data: $leagueData');
        
        // Get members
        final membersSnapshot = await _fs
            .collection('leagues')
            .doc(leagueId)
            .collection('members')
            .get();
            
        print('Members count: ${membersSnapshot.docs.length}');
        
        for (final memberDoc in membersSnapshot.docs) {
          final memberData = memberDoc.data();
          print('  - ${memberDoc.id}: ${memberData['displayName']} (${memberData['point']} points)');
        }
        print('---');
      }
      
    } catch (e) {
      print('Error checking league status: $e');
    }
  }

  /*──────────────────── 사용자 포인트 조회 ────────────────────*/
  Future<int> getUserPoints() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      // 현재 사용자 정보 조회
      final userDoc = await _fs.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return 0;

      final userData = userDoc.data()!;
      return userData['totalPoints'] ?? 0;
    } catch (e) {
      print('Error getting user points: $e');
      return 0;
    }
  }

  /*──────────────────── 사용자 랭킹 조회 ────────────────────*/
  Future<int> getUserRank() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      // 현재 사용자 포인트 조회
      final currentUserPoints = await getUserPoints();
      
      // 전체 사용자 중에서 현재 사용자보다 높은 포인트를 가진 사용자 수 조회
      final higherScoreUsersSnapshot = await _fs
          .collection('users')
          .where('totalPoints', isGreaterThan: currentUserPoints)
          .get();

      // 랭킹은 자신보다 높은 점수를 가진 사용자 수 + 1
      return higherScoreUsersSnapshot.docs.length + 1;
    } catch (e) {
      print('Error getting user rank: $e');
      return 0;
    }
  }
}