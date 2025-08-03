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
  Future<Map<String, dynamic>> myProfile() async {
    try {
      // 먼저 로컬 Firestore에서 사용자 데이터 조회 시도
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _fs.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('Profile loaded from Firestore: ${userData['totalPoints']} points');
          return {
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? userData['displayName'],
            'photoURL': user.photoURL ?? userData['photoURL'],
            'totalPoints': userData['totalPoints'] ?? 0,
            'eduPoints': userData['eduPoints'] ?? 0,
            'jobPoints': userData['jobPoints'] ?? 0,
            'completedLessons': userData['completedLessons'] ?? 0,
            'completedLessonIds': userData['completedLessonIds'] ?? [],
            ...userData,
          };
        }
      }
      
      // Firestore에 데이터가 없으면 Cloud Function 시도
      print('No local user data, trying Cloud Function...');
      return (await _func.httpsCallable('getMyProfile').call()).data;
    } catch (e) {
      print('Error getting profile: $e');
      
      // 모든 것이 실패하면 기본 데이터 반환
      final user = _auth.currentUser;
      if (user != null) {
        return {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'totalPoints': 0,
          'eduPoints': 0,
          'jobPoints': 0,
          'completedLessons': 0,
          'completedLessonIds': [],
        };
      }
      
      throw Exception('사용자 프로필을 불러올 수 없습니다');
    }
  }

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
  Future<void> completeLessons(List<String> ids) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 클라이언트에서 직접 처리
      await _completeLessonsLocal(user.uid, ids);
      
      print('Lessons completed successfully: $ids for user ${user.uid}');
    } catch (e) {
      print('Error completing lessons locally: $e');
      // 로컬 처리 실패 시 Cloud Function 시도
      try {
        await _func.httpsCallable('completeLesson').call({'lessonIds': ids});
        print('Lessons completed via Cloud Function: $ids');
      } catch (cloudError) {
        print('Cloud Function also failed: $cloudError');
        // 에러를 던지지 않고 로그만 남김 (포인트 지급은 이미 성공했을 수 있음)
      }
    }
  }

  Future<void> _completeLessonsLocal(String uid, List<String> lessonIds) async {
    final userDocRef = _fs.collection('users').doc(uid);
    
    await _fs.runTransaction((transaction) async {
      final userDoc = await transaction.get(userDocRef);
      
      if (userDoc.exists) {
        final currentData = userDoc.data()!;
        final completedLessons = List<String>.from(currentData['completedLessonIds'] ?? []);
        
        // 새로운 레슨들만 추가
        final newLessons = lessonIds.where((id) => !completedLessons.contains(id)).toList();
        
        if (newLessons.isNotEmpty) {
          completedLessons.addAll(newLessons);
          
          transaction.update(userDocRef, {
            'completedLessonIds': completedLessons,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /*──────────────────────── Garden ────────────────────────────*/
  Future<Map<String, dynamic>> myGarden() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      print('=== myGarden() DEBUG ===');
      
      // 항상 최신 사용자 문서 가져오기 (캐시 방지)
      final userDoc = await _fs.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final currentPoints = userData['totalPoints'] ?? 0;
        print('Current user points from Firestore: $currentPoints');
        
        // 사용자 문서에서 정원 데이터 추출 및 타입 변환
        final rawGardenData = userData['garden'];
        Map<String, dynamic> gardenData;
        
        if (rawGardenData != null) {
          // Firestore LinkedMap을 Map<String, dynamic>으로 변환
          gardenData = Map<String, dynamic>.from(rawGardenData);
        } else {
          gardenData = {
            'size': 3,
            'tiles': {},
          };
        }
        
        // tiles 데이터도 안전하게 변환
        final rawTiles = gardenData['tiles'];
        Map<String, dynamic> tiles;
        
        if (rawTiles != null) {
          tiles = Map<String, dynamic>.from(rawTiles);
          // 각 타일 데이터도 변환
          tiles = tiles.map((key, value) {
            if (value is Map) {
              return MapEntry(key, Map<String, dynamic>.from(value));
            }
            return MapEntry(key, value);
          });
        } else {
          tiles = {};
        }
        
        print('Garden tiles count: ${tiles.length}');
        print('========================');
        
        // 항상 최신 포인트를 반환
        return {
          'size': gardenData['size'] ?? 3,
          'point': currentPoints, // 실시간 포인트
          'tiles': tiles,
          'updatedAt': DateTime.now().millisecondsSinceEpoch, // 항상 최신 시간으로 설정
        };
      } else {
        // 사용자 문서가 없으면 기본 정원 반환
        print('User document not found, returning default garden');
        return {
          'size': 3,
          'point': 0,
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
    } catch (e) {
      print('Error getting garden from user document: $e');
      // 에러 발생 시에도 프로필에서 포인트를 가져와서 동기화
      try {
        final profile = await myProfile();
        final cloudGarden = (await _func.httpsCallable('getMyGarden').call()).data;
        // Cloud Function 결과에 최신 포인트 덮어쓰기
        cloudGarden['point'] = profile['totalPoints'] ?? 0;
        return cloudGarden;
      } catch (cloudError) {
        print('Cloud Function also failed, returning default garden: $cloudError');
        // 모든 것이 실패하면 프로필 포인트로라도 동기화 시도
        try {
          final profile = await myProfile();
          return {
            'size': 3,
            'point': profile['totalPoints'] ?? 0,
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
        } catch (profileError) {
          return {
            'size': 3,
            'point': 0,
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
    }
  }

  Future<Map<String, dynamic>> otherGarden(String uid) async =>
      (await _func.httpsCallable('getUserGarden')
                .call({'targetUid': uid})).data;

  Future<void> plantCrop(int x, int y, String cropId) async {
    try {
      // Cloud Function을 통한 작물 심기
      await _func.httpsCallable('plantCrop').call({'x': x, 'y': y, 'cropId': cropId});
      print('Crop planted successfully at ($x, $y): $cropId');
    } catch (e) {
      print('Error planting crop: $e');
      throw Exception('작물 심기에 실패했습니다: $e');
    }
  }

  Future<void> plantCropWithPoints(int x, int y, String cropId, int cost) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 실제 사용자 포인트 상태 확인 (디버깅용)
      print('=== USER POINTS DEBUG ===');
      try {
        final profile = await myProfile();
        print('Profile points: ${profile['totalPoints']}');
        
        final userDoc = await _fs.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('Firestore direct points: ${userData['totalPoints']}');
        } else {
          print('User document does not exist in Firestore');
        }
      } catch (profileError) {
        print('Error getting profile: $profileError');
      }
      print('=========================');

      // 로컬에서 직접 처리 (Firebase Functions 문제 우회)
      await _plantCropLocal(user.uid, x, y, cropId, cost);
      
      print('Crop planted locally at ($x, $y): $cropId with cost $cost');
    } catch (e) {
      print('Error planting crop locally: $e');
      // 로컬 처리 실패 시 원래 방식 시도
      try {
        await _func.httpsCallable('plantCrop').call({'x': x, 'y': y, 'cropId': cropId});
        // 별도로 포인트 차감
        await addPoints(-cost);
        print('Crop planted via Cloud Function: $cropId');
      } catch (cloudError) {
        print('Cloud Function also failed: $cloudError');
        throw Exception('작물 심기에 실패했습니다: $cloudError');
      }
    }
  }

  Future<void> _plantCropLocal(String uid, int x, int y, String cropId, int cost) async {
    try {
      print('=== PLANT CROP LOCAL DEBUG ===');
      print('UID: $uid');
      print('Position: ($x, $y)');
      print('Crop ID: $cropId');
      print('Cost: $cost');
      
      await _fs.runTransaction((transaction) async {
        print('Starting transaction...');
        
        // 사용자 포인트 확인 및 차감 + 정원 데이터 업데이트 (한 문서에서 처리)
        final userDocRef = _fs.collection('users').doc(uid);
        print('Getting user document: users/$uid');
        final userDoc = await transaction.get(userDocRef);
        
        if (!userDoc.exists) {
          print('ERROR: User document does not exist');
          throw Exception('사용자 정보를 찾을 수 없습니다');
        }
        
        final userData = userDoc.data()!;
        final currentPoints = userData['totalPoints'] ?? 0;
        print('Current user points: $currentPoints');
        print('Required cost: $cost');
        
        if (currentPoints < cost) {
          print('ERROR: Insufficient points');
          throw Exception('포인트가 부족합니다. (필요: ${cost}P, 보유: ${currentPoints}P)');
        }
        
        print('Points sufficient, processing garden data...');
        
        // 기존 정원 데이터 가져오기 (user 문서 내부에서)
        Map<String, dynamic> gardenData = Map<String, dynamic>.from(userData['garden'] ?? {
          'size': 3,
          'tiles': {},
        });
        
        print('Garden data retrieved from user document');
        
        // 타일 업데이트
        final tiles = Map<String, dynamic>.from(gardenData['tiles'] ?? {});
        final tileKey = '$x,$y';
        print('Updating tile: $tileKey');
        
        tiles[tileKey] = {
          'stage': 1, // planted
          'cropId': cropId,
          'plantedAt': FieldValue.serverTimestamp(),
        };
        
        gardenData['tiles'] = tiles;
        gardenData['updatedAt'] = FieldValue.serverTimestamp();
        
        print('Updating user document with new points and garden data...');
        // 포인트 차감과 정원 데이트를 한 번에 업데이트
        transaction.update(userDocRef, {
          'totalPoints': currentPoints - cost,
          'garden': gardenData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('User document updated successfully');
      });
      
      print('Transaction completed successfully');
      print('=== PLANT CROP LOCAL SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== PLANT CROP LOCAL ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('================================');
      rethrow;
    }
  }

  Future<void> progressCrop(int x, int y) async {
    try {
      // Cloud Function을 통한 작물 성장
      await _func.httpsCallable('progressCrop').call({'x': x, 'y': y});
      print('Crop progressed successfully at ($x, $y)');
    } catch (e) {
      print('Error progressing crop: $e');
      throw Exception('작물 성장에 실패했습니다: $e');
    }
  }

  Future<void> progressCropWithPoints(int x, int y, int cost) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 로컬에서 직접 처리
      await _progressCropLocal(user.uid, x, y, cost);
      
      print('Crop progressed locally at ($x, $y) with cost $cost');
    } catch (e) {
      print('Error progressing crop locally: $e');
      // 로컬 처리 실패 시 원래 방식 시도
      try {
        await _func.httpsCallable('progressCrop').call({'x': x, 'y': y});
        await addPoints(-cost);
        print('Crop progressed via Cloud Function');
      } catch (cloudError) {
        print('Cloud Function also failed: $cloudError');
        throw Exception('작물 성장에 실패했습니다: $cloudError');
      }
    }
  }

  Future<void> _progressCropLocal(String uid, int x, int y, int cost) async {
    await _fs.runTransaction((transaction) async {
      // 사용자 포인트 확인 및 차감 + 정원 데이터 업데이트 (한 문서에서 처리)
      final userDocRef = _fs.collection('users').doc(uid);
      final userDoc = await transaction.get(userDocRef);
      
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }
      
      final userData = userDoc.data()!;
      final currentPoints = userData['totalPoints'] ?? 0;
      
      if (currentPoints < cost) {
        throw Exception('포인트가 부족합니다. (필요: ${cost}P, 보유: ${currentPoints}P)');
      }
      
      // 기존 정원 데이터 가져오기 (user 문서 내부에서)
      Map<String, dynamic> gardenData = Map<String, dynamic>.from(userData['garden'] ?? {
        'size': 3,
        'tiles': {},
      });
      
      final tiles = Map<String, dynamic>.from(gardenData['tiles'] ?? {});
      final tileKey = '$x,$y';
      
      if (!tiles.containsKey(tileKey)) {
        throw Exception('해당 위치에 작물이 없습니다');
      }
      
      final tileData = Map<String, dynamic>.from(tiles[tileKey]);
      final currentStage = tileData['stage'] ?? 0;
      
      // 다음 단계로 성장
      tileData['stage'] = currentStage + 1;
      tileData['updatedAt'] = FieldValue.serverTimestamp();
      
      tiles[tileKey] = tileData;
      gardenData['tiles'] = tiles;
      gardenData['updatedAt'] = FieldValue.serverTimestamp();
      
      // 포인트 차감과 정원 데이터를 한 번에 업데이트
      transaction.update(userDocRef, {
        'totalPoints': currentPoints - cost,
        'garden': gardenData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> harvestCrop(int x, int y) async {
    try {
      // Cloud Function을 통한 작물 수확
      await _func.httpsCallable('harvestCrop').call({'x': x, 'y': y});
      print('Crop harvested successfully at ($x, $y)');
    } catch (e) {
      print('Error harvesting crop: $e');
      throw Exception('작물 수확에 실패했습니다: $e');
    }
  }

  Future<int> harvestCropWithPoints(int x, int y, int reward) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 로컬에서 직접 처리
      await _harvestCropLocal(user.uid, x, y, reward);
      
      print('Crop harvested locally at ($x, $y) with reward $reward');
      return reward; // 획득한 포인트 반환
    } catch (e) {
      print('Error harvesting crop locally: $e');
      // 로컬 처리 실패 시 원래 방식 시도
      try {
        await _func.httpsCallable('harvestCrop').call({'x': x, 'y': y});
        await addPoints(reward);
        print('Crop harvested via Cloud Function');
        return reward; // 획득한 포인트 반환
      } catch (cloudError) {
        print('Cloud Function also failed: $cloudError');
        throw Exception('작물 수확에 실패했습니다: $cloudError');
      }
    }
  }

  Future<void> _harvestCropLocal(String uid, int x, int y, int reward) async {
    await _fs.runTransaction((transaction) async {
      // 사용자 포인트 지급 + 정원 데이터 업데이트 (한 문서에서 처리)
      final userDocRef = _fs.collection('users').doc(uid);
      final userDoc = await transaction.get(userDocRef);
      
      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }
      
      final userData = userDoc.data()!;
      final currentPoints = userData['totalPoints'] ?? 0;
      
      // 기존 정원 데이터 가져오기 (user 문서 내부에서)
      Map<String, dynamic> gardenData = Map<String, dynamic>.from(userData['garden'] ?? {
        'size': 3,
        'tiles': {},
      });
      
      final tiles = Map<String, dynamic>.from(gardenData['tiles'] ?? {});
      final tileKey = '$x,$y';
      
      // 작물 제거 (빈 타일로 변경)
      tiles[tileKey] = {
        'stage': 0, // empty
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      gardenData['tiles'] = tiles;
      gardenData['updatedAt'] = FieldValue.serverTimestamp();
      
      // 포인트 지급과 정원 데이터를 한 번에 업데이트
      transaction.update(userDocRef, {
        'totalPoints': currentPoints + reward,
        'garden': gardenData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addPoints(int amount) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 클라이언트에서 직접 Firestore 업데이트
      await _addPointsLocal(user.uid, amount);
      
      print('Points added successfully: $amount points to user ${user.uid}');
    } catch (e) {
      print('Error adding points locally: $e');
      // 로컬 업데이트 실패 시 Cloud Function 시도
      try {
        await _func.httpsCallable('addPoints').call({'amount': amount});
        print('Points added via Cloud Function: $amount');
      } catch (cloudError) {
        print('Cloud Function also failed: $cloudError');
        throw Exception('포인트 지급 처리 중 오류가 발생했습니다');
      }
    }
  }

  Future<void> _addPointsLocal(String uid, int amount) async {
    // 사용자 문서 참조
    final userDocRef = _fs.collection('users').doc(uid);
    
    // 트랜잭션으로 안전하게 포인트 업데이트
    await _fs.runTransaction((transaction) async {
      final userDoc = await transaction.get(userDocRef);
      
      if (!userDoc.exists) {
        // 사용자 문서가 없으면 생성
        final userData = {
          'uid': uid,
          'email': _auth.currentUser?.email,
          'displayName': _auth.currentUser?.displayName,
          'photoURL': _auth.currentUser?.photoURL,
          'totalPoints': amount,
          'eduPoints': amount > 0 ? amount : 0, // 양수일 때만 교육 포인트로 추가
          'jobPoints': 0,
          'completedLessons': amount > 0 ? 1 : 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(userDocRef, userData);
      } else {
        // 기존 사용자 포인트 업데이트
        final currentData = userDoc.data()!;
        final currentTotal = currentData['totalPoints'] ?? 0;
        final currentEdu = currentData['eduPoints'] ?? 0;
        final currentLessons = currentData['completedLessons'] ?? 0;
        
        final updates = <String, dynamic>{
          'totalPoints': currentTotal + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // 양수일 때만 교육 포인트와 완료 레슨 수 증가
        if (amount > 0) {
          updates['eduPoints'] = currentEdu + amount;
          updates['completedLessons'] = currentLessons + 1;
        }
        
        transaction.update(userDocRef, updates);
      }
    });
  }

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

  /*──────────────────── League Gardens ────────────────────*/
  /// Get all league members' gardens
  Future<List<Map<String, dynamic>>> getLeagueMembersGardens() async {
    try {
      // Get current user's league
      final myLeagueData = await myLeague();
      final leagueId = myLeagueData['leagueId'];
      
      if (leagueId == null) {
        print('User not in any league');
        return [];
      }
      
      print('Getting gardens for league: $leagueId');
      
      // Get all league members
      final membersSnapshot = await _fs
          .collection('leagues')
          .doc(leagueId)
          .collection('members')
          .orderBy('point', descending: true)
          .get();
      
      final List<Map<String, dynamic>> memberGardens = [];
      
      for (final memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        final memberUid = memberDoc.id;
        
        try {
          // Get member's garden data
          final userDoc = await _fs.collection('users').doc(memberUid).get();
          
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final gardenData = userData['garden'];
            
            if (gardenData != null) {
              // Process garden data
              Map<String, dynamic> processedGarden = Map<String, dynamic>.from(gardenData);
              
              // Process tiles if they exist
              final rawTiles = processedGarden['tiles'];
              if (rawTiles != null) {
                final tiles = <String, dynamic>{};
                if (rawTiles is Map) {
                  rawTiles.forEach((key, value) {
                    if (value is Map) {
                      tiles[key.toString()] = Map<String, dynamic>.from(value);
                    }
                  });
                  processedGarden['tiles'] = tiles;
                }
              }
              
              // Add member info to garden data
              processedGarden['memberInfo'] = {
                'uid': memberUid,
                'displayName': memberData['displayName'] ?? memberData['name'] ?? 'Unknown Player',
                'points': memberData['point'] ?? 0,
                'totalPoints': userData['totalPoints'] ?? 0,
              };
              
              processedGarden['size'] = processedGarden['size'] ?? 3;
              
              memberGardens.add(processedGarden);
              print('Added garden for ${memberData['displayName']} (${memberData['point']} points)');
            } else {
              // Create default garden for member without garden data
              memberGardens.add({
                'size': 3,
                'tiles': {},
                'memberInfo': {
                  'uid': memberUid,
                  'displayName': memberData['displayName'] ?? memberData['name'] ?? 'Unknown Player',
                  'points': memberData['point'] ?? 0,
                  'totalPoints': userData['totalPoints'] ?? 0,
                },
              });
            }
          }
        } catch (e) {
          print('Error getting garden for member $memberUid: $e');
          // Add empty garden for failed cases
          memberGardens.add({
            'size': 3,
            'tiles': {},
            'memberInfo': {
              'uid': memberUid,
              'displayName': memberData['displayName'] ?? memberData['name'] ?? 'Unknown Player',
              'points': memberData['point'] ?? 0,
              'totalPoints': 0,
            },
          });
        }
      }
      
      print('Retrieved ${memberGardens.length} member gardens');
      return memberGardens;
      
    } catch (e) {
      print('Error getting league members gardens: $e');
      return [];
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

  /*──────────────────── 펀딩 관련 기능 ────────────────────*/
  /// 포인트로 펀딩하기
  Future<void> fundWithPoints(String projectId, int points) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      print('=== FUNDING WITH POINTS DEBUG ===');
      print('User UID: ${user.uid}');
      print('Project ID: $projectId');
      print('Points to fund: $points');

      // 클라이언트에서 직접 처리
      await _fundWithPointsLocal(user.uid, projectId, points);
      
      print('Funding completed successfully: $points points to project $projectId');
    } catch (e) {
      print('Error funding with points: $e');
      throw Exception('펀딩 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _fundWithPointsLocal(String uid, String projectId, int points) async {
    try {
      print('=== FUND WITH POINTS LOCAL DEBUG ===');
      print('UID: $uid');
      print('Project ID: $projectId');
      print('Points: $points');
      
      // 사용자 포인트 차감을 별도 트랜잭션으로 처리
      await _fs.runTransaction((transaction) async {
        print('Starting user points transaction...');
        
        // 사용자 포인트 확인 및 차감
        final userDocRef = _fs.collection('users').doc(uid);
        print('Getting user document: users/$uid');
        final userDoc = await transaction.get(userDocRef);
        
        if (!userDoc.exists) {
          print('ERROR: User document does not exist');
          throw Exception('사용자 정보를 찾을 수 없습니다');
        }
        
        final userData = userDoc.data()!;
        final currentPoints = userData['totalPoints'] ?? 0;
        print('Current user points: $currentPoints');
        print('Required points: $points');
        
        if (currentPoints < points) {
          print('ERROR: Insufficient points');
          throw Exception('포인트가 부족합니다. (필요: ${points}P, 보유: ${currentPoints}P)');
        }
        
        print('Points sufficient, processing funding...');
        
        // 사용자 포인트 차감
        transaction.update(userDocRef, {
          'totalPoints': currentPoints - points,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('User points updated successfully');
      });
      
      // 펀딩 기록 저장 (별도 처리)
      await _fs.collection('fundings').add({
        'userId': uid,
        'projectId': projectId,
        'points': points,
        'fundedAt': FieldValue.serverTimestamp(),
      });
      print('Funding record created successfully');
      
      // 프로젝트 모금액 업데이트 (별도 트랜잭션)
      await _updateProjectAmount(projectId, points);
      
      print('Transaction completed successfully');
      print('=== FUND WITH POINTS LOCAL SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== FUND WITH POINTS LOCAL ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=====================================');
      rethrow;
    }
  }

  /// 프로젝트 모금액 업데이트
  Future<void> _updateProjectAmount(String projectId, int points) async {
    try {
      print('=== UPDATING PROJECT AMOUNT ===');
      print('Project ID: $projectId');
      print('Points to add: $points');
      
      await _fs.runTransaction((transaction) async {
        final projectDocRef = _fs.collection('fundingProjects').doc(projectId);
        final projectDoc = await transaction.get(projectDocRef);
        
        if (projectDoc.exists) {
          final projectData = projectDoc.data()!;
          final currentAmount = (projectData['currentAmount'] ?? 0).toDouble();
          final newAmount = currentAmount + points;
          
          transaction.update(projectDocRef, {
            'currentAmount': newAmount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Project currentAmount updated: $currentAmount -> $newAmount');
        } else {
          print('Project document does not exist, creating with current funding...');
          transaction.set(projectDocRef, {
            'title': 'Fund Project $projectId',
            'description': 'Environmental protection project',
            'targetAmount': 1000.0,
            'currentAmount': points.toDouble(),
            'daysLeft': 30,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'creatorUid': 'system',
            'creatorName': 'System',
          });
          print('New project created with currentAmount: $points');
        }
      });
      
      print('Project amount update completed successfully');
    } catch (e) {
      print('Error updating project amount: $e');
      // 프로젝트 업데이트 실패해도 사용자 포인트는 이미 차감되었으므로 로그만 남김
    }
  }

  /// 펀딩 프로젝트 목록 조회
  Future<List<Map<String, dynamic>>> getFundingProjects() async {
    try {
      print('=== GETTING FUNDING PROJECTS ===');
      
      // Firestore에서 직접 프로젝트 조회
      final projectsSnapshot = await _fs.collection('fundingProjects').get();
      
      List<Map<String, dynamic>> projects = [];
      
      for (final doc in projectsSnapshot.docs) {
        final data = doc.data();
        projects.add({
          'id': doc.id,
          'title': data['title'] ?? 'Unknown Project',
          'description': data['description'] ?? '',
          'targetAmount': (data['targetAmount'] ?? 1000).toDouble(),
          'currentAmount': (data['currentAmount'] ?? 0).toDouble(),
          'daysLeft': data['daysLeft'] ?? 30,
          'imageUrl': data['imageUrl'],
          'createdAt': data['createdAt']?.millisecondsSinceEpoch ?? 
                      DateTime.now().millisecondsSinceEpoch,
          'creatorUid': data['creatorUid'] ?? 'unknown',
          'creatorName': data['creatorName'] ?? 'Anonymous',
        });
      }
      
      print('Found ${projects.length} funding projects in Firestore');
      
      // Firestore에 프로젝트가 없으면 기본 프로젝트들 생성
      if (projects.isEmpty) {
        print('No projects found, creating default projects...');
        await _createDefaultProjects();
        
        // 다시 조회
        final newSnapshot = await _fs.collection('fundingProjects').get();
        projects = [];
        for (final doc in newSnapshot.docs) {
          final data = doc.data();
          projects.add({
            'id': doc.id,
            'title': data['title'] ?? 'Unknown Project',
            'description': data['description'] ?? '',
            'targetAmount': (data['targetAmount'] ?? 1000).toDouble(),
            'currentAmount': (data['currentAmount'] ?? 0).toDouble(),
            'daysLeft': data['daysLeft'] ?? 30,
            'imageUrl': data['imageUrl'],
            'createdAt': data['createdAt']?.millisecondsSinceEpoch ?? 
                        DateTime.now().millisecondsSinceEpoch,
            'creatorUid': data['creatorUid'] ?? 'unknown',
            'creatorName': data['creatorName'] ?? 'Anonymous',
          });
        }
      }
      
      print('Returning ${projects.length} funding projects');
      return projects;
    } catch (e) {
      print('Error getting funding projects: $e');
      throw Exception('펀딩 프로젝트를 불러올 수 없습니다: $e');
    }
  }

  /*──────────────────── 교육 및 퀴즈 관련 기능 ────────────────────*/
  
  /// 교육 완료 상태 확인
  Future<bool> isLessonCompleted(int lessonId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _fs
          .collection('users')
          .doc(user.uid)
          .collection('lessonCompletions')
          .doc(lessonId.toString())
          .get();

      return doc.exists && (doc.data()?['isCompleted'] ?? false);
    } catch (e) {
      print('Error checking lesson completion: $e');
      return false;
    }
  }

  /// 교육의 퀴즈 목록 가져오기
  Future<List<Map<String, dynamic>>> getLessonQuizzes(int lessonId) async {
    try {
      // 실제로는 Firestore에서 가져와야 하지만, 여기서는 더미 데이터 사용
      await Future.delayed(const Duration(milliseconds: 500));
      
      return _getQuizzesByLessonId(lessonId);
    } catch (e) {
      print('Error getting lesson quizzes: $e');
      throw Exception('퀴즈를 불러올 수 없습니다: $e');
    }
  }

  /// 퀴즈 답안 제출 및 채점
  Future<Map<String, dynamic>> submitQuizAnswer({
    required int lessonId,
    required int quizId,
    required int selectedAnswer,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 이미 완료한 교육인지 확인
      final isCompleted = await isLessonCompleted(lessonId);
      if (isCompleted) {
        return {
          'isCorrect': false,
          'pointsEarned': 0,
          'explanation': '이미 완료한 교육입니다.',
          'alreadyCompleted': true,
        };
      }

      // 퀴즈 정답 확인
      final quizzes = await getLessonQuizzes(lessonId);
      final quiz = quizzes.firstWhere(
        (q) => q['id'] == quizId,
        orElse: () => throw Exception('퀴즈를 찾을 수 없습니다'),
      );

      final correctAnswer = quiz['correctAnswerIndex'] as int;
      final isCorrect = selectedAnswer == correctAnswer;
      final pointsEarned = isCorrect ? (quiz['points'] as int? ?? 10) : 0;

      // 퀴즈 결과 저장
      await _saveQuizResult(user.uid, lessonId, quizId, selectedAnswer, isCorrect, pointsEarned);

      // 포인트 지급 (정답인 경우)
      if (isCorrect && pointsEarned > 0) {
        await _addPointsToUser(user.uid, pointsEarned);
      }

      return {
        'isCorrect': isCorrect,
        'pointsEarned': pointsEarned,
        'explanation': quiz['explanation'] ?? '',
        'correctAnswer': correctAnswer,
        'alreadyCompleted': false,
      };
    } catch (e) {
      print('Error submitting quiz answer: $e');
      throw Exception('퀴즈 답안 제출에 실패했습니다: $e');
    }
  }

  /// 교육 완료 처리
  Future<void> completeLessonWithQuizzes({
    required int lessonId,
    required List<Map<String, dynamic>> quizResults,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 이미 완료한 교육인지 확인
      final isAlreadyCompleted = await isLessonCompleted(lessonId);
      if (isAlreadyCompleted) {
        print('Lesson $lessonId already completed');
        return;
      }

      final totalPoints = quizResults
          .where((result) => result['isCorrect'] == true)
          .fold<int>(0, (sum, result) => sum + (result['pointsEarned'] as int? ?? 0));

      // 교육 완료 상태 저장
      await _fs
          .collection('users')
          .doc(user.uid)
          .collection('lessonCompletions')
          .doc(lessonId.toString())
          .set({
        'lessonId': lessonId,
        'isCompleted': true,
        'totalPoints': totalPoints,
        'quizResults': quizResults,
        'completedAt': FieldValue.serverTimestamp(),
      });

      print('Lesson $lessonId completed with $totalPoints points');
    } catch (e) {
      print('Error completing lesson: $e');
      throw Exception('교육 완료 처리에 실패했습니다: $e');
    }
  }

  /// 퀴즈 결과 저장 (내부 메서드)
  Future<void> _saveQuizResult(
    String uid,
    int lessonId,
    int quizId,
    int selectedAnswer,
    bool isCorrect,
    int pointsEarned,
  ) async {
    await _fs
        .collection('users')
        .doc(uid)
        .collection('quizResults')
        .add({
      'lessonId': lessonId,
      'quizId': quizId,
      'selectedAnswerIndex': selectedAnswer,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 사용자에게 포인트 추가 (내부 메서드)
  Future<void> _addPointsToUser(String uid, int points) async {
    await _fs.runTransaction((transaction) async {
      final userDocRef = _fs.collection('users').doc(uid);
      final userDoc = await transaction.get(userDocRef);
      
      if (userDoc.exists) {
        final currentPoints = userDoc.data()?['totalPoints'] ?? 0;
        transaction.update(userDocRef, {
          'totalPoints': currentPoints + points,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 레슨별 퀴즈 더미 데이터 생성
  List<Map<String, dynamic>> _getQuizzesByLessonId(int lessonId) {
    // 레슨별 퀴즈 데이터
    final quizData = {
      1: [ // 기후 변화의 이해
        {
          'id': 1,
          'question': '지구온난화의 주요 원인은 무엇인가요?',
          'options': [
            {'text': '태양의 활동 증가', 'isCorrect': false},
            {'text': '온실가스 배출 증가', 'isCorrect': true},
            {'text': '화산 폭발', 'isCorrect': false},
            {'text': '바다의 염분 농도 변화', 'isCorrect': false},
          ],
          'correctAnswerIndex': 1,
          'explanation': '온실가스(CO2, 메탄 등)의 배출 증가가 지구온난화의 주요 원인입니다.',
          'points': 10,
        },
        {
          'id': 2,
          'question': '가장 강력한 온실가스는 무엇인가요?',
          'options': [
            {'text': '이산화탄소(CO2)', 'isCorrect': false},
            {'text': '메탄(CH4)', 'isCorrect': false},
            {'text': '아산화질소(N2O)', 'isCorrect': false},
            {'text': '불화가스류', 'isCorrect': true},
          ],
          'correctAnswerIndex': 3,
          'explanation': '불화가스류는 CO2보다 수천 배 강력한 온실효과를 가집니다.',
          'points': 15,
        },
      ],
      2: [ // 재생에너지 기초
        {
          'id': 3,
          'question': '재생에너지가 아닌 것은?',
          'options': [
            {'text': '태양광 에너지', 'isCorrect': false},
            {'text': '풍력 에너지', 'isCorrect': false},
            {'text': '천연가스', 'isCorrect': true},
            {'text': '수력 에너지', 'isCorrect': false},
          ],
          'correctAnswerIndex': 2,
          'explanation': '천연가스는 화석연료로 재생에너지가 아닙니다.',
          'points': 10,
        },
      ],
      3: [ // 물 절약 방법
        {
          'id': 4,
          'question': '가정에서 물을 가장 많이 사용하는 곳은?',
          'options': [
            {'text': '화장실', 'isCorrect': true},
            {'text': '주방', 'isCorrect': false},
            {'text': '세탁실', 'isCorrect': false},
            {'text': '정원', 'isCorrect': false},
          ],
          'correctAnswerIndex': 0,
          'explanation': '가정에서 물 사용량의 약 30%가 화장실에서 사용됩니다.',
          'points': 10,
        },
      ],
    };

    return quizData[lessonId] ?? [];
  }

  /// 기본 펀딩 프로젝트들 생성
  Future<void> _createDefaultProjects() async {
    final defaultProjects = [
      {
        'title': 'Clean Ocean Initiative',
        'description': 'Support ocean cleanup and marine life protection efforts.',
        'targetAmount': 1000.0,
        'currentAmount': 750.0,
        'daysLeft': 15,
        'creatorUid': 'system',
        'creatorName': 'Environmental Guardian',
      },
      {
        'title': 'Urban Green Spaces',
        'description': 'Create more green spaces in urban areas for better air quality.',
        'targetAmount': 500.0,
        'currentAmount': 300.0,
        'daysLeft': 8,
        'creatorUid': 'system',
        'creatorName': 'Green City',
      },
      {
        'title': 'Solar Energy for Schools',
        'description': 'Install solar panels in schools to promote renewable energy education.',
        'targetAmount': 2000.0,
        'currentAmount': 1200.0,
        'daysLeft': 25,
        'creatorUid': 'system',
        'creatorName': 'GreenTech',
      },
    ];

    final batch = _fs.batch();
    
    for (final project in defaultProjects) {
      final docRef = _fs.collection('fundingProjects').doc();
      batch.set(docRef, {
        ...project,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    print('Default funding projects created');
  }

  /// 펀딩 프로젝트 생성
  Future<void> createFundingProject({
    required String title,
    required String description,
    required double targetAmount,
    required int durationDays,
    String? imageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // Cloud Function 호출 (실제 구현 시)
      await _func.httpsCallable('createFundingProject').call({
        'title': title,
        'description': description,
        'targetAmount': targetAmount,
        'durationDays': durationDays,
        'imageUrl': imageUrl,
      });
      
      print('Funding project created: $title');
    } catch (e) {
      print('Error creating funding project: $e');
      throw Exception('펀딩 프로젝트 생성 중 오류가 발생했습니다: $e');
    }
  }
}