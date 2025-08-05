// lib/services/eco_backend.dart
//  Flutter 3.16.x  /  Firebase SDK  November 2025

import 'dart:io';
import 'package:bloom/data/models/fund.dart';
import 'package:bloom/data/models/lesson_models.dart';
import 'package:bloom/data/models/quiz.dart';
import 'package:bloom/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bloom/providers/points_provider.dart';

/// ⚡  EcoBackend  –  Firebase/CloudFunctions wrapper used across the app
///    Access via EcoBackend.instance singleton
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

    // ─── 1) Web ───
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      return await auth.signInWithPopup(provider);
    }

    // ─── 2) Android / iOS ───
    final googleSignIn = GoogleSignIn(
      // ① **웹 클라이언트 ID** 넣어 주면 서버 검증까지 완벽!
      //    FirebaseOptions 안에 이미 있으면 꺼내 쓰기 👇
      clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
      scopes: ['email'],
    );

    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(code: 'canceled', message: '사용자 취소');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // ApiException:10 → 보통 SHA 미매칭 or clientId 불일치
      debugPrint('GoogleSignIn error: ${e.code} / ${e.message}');
      rethrow;
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

      // 포인트 변경 알림
      notifyPointsChanged();
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

      // 포인트 변경 알림
      notifyPointsChanged();
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

      // 포인트 변경 알림
      notifyPointsChanged();

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

      // 포인트 변경 알림
      notifyPointsChanged();
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


  /*──────────────────── 교육 및 퀴즈 관련 기능 ────────────────────*/
  /// 레슨 전체 목록 (메타) 가져오기
  Future<List<LessonMeta>> listLessons() async {
    final snap = await _fs.collection('lessons').get();
    return snap.docs
        .map((d) => LessonMeta.fromDoc(d.id, d.data()))
        .toList();
  }

  /// 특정 레슨의 스텝 목록
  Future<List<LessonStep>> getLessonSteps(String lessonId) async {
    final qs = await _fs
        .collection('lessons')
        .doc(lessonId)
        .collection('steps')
        .orderBy(FieldPath.documentId)
        .get();

    return qs.docs
        .map((d) => LessonStep.fromDoc(d.data()))
        .toList();
  }

  /// 특정 레슨의 퀴즈 목록
  /// 레슨별 퀴즈 (Firestore ‘quiz’ 서브컬렉션)
  Future<List<Quiz>> getLessonQuizzesFromServer(String lessonId) async {
    final qs = await _fs
        .collection('lessons')
        .doc(lessonId)
        .collection('quiz')
        .orderBy(FieldPath.documentId)
        .get();

    return qs.docs.map((d) {
      final j = d.data();
      final correct = j['correct'] ?? 0;
      return Quiz(
        id       : d.id,
        question : j['question'] ?? '',
        options  : List<String>.from(j['options'] ?? []).asMap().entries
            .map((e) => QuizOption(text: e.value, isCorrect: e.key == correct))
            .toList(),
        correctAnswerIndex: correct,
        explanation: j['explanation'] ?? '',
        points     : j['points'] ?? 10,
      );
    }).toList();
  }

  FirebaseFunctions get functions => _func;

  /*──────── 캠페인 단건 조회 ────────*/
  Future<FundCampaign> getCampaign(String campaignId) async {
    final res = await _func
        .httpsCallable('getFundCampaign')
        .call({'campaignId': campaignId});
    return FundCampaign.fromJson(Map<String, dynamic>.from(res.data));
  }

  /*──────── 캠페인 목록 ────────*/
  Future<List<FundCampaign>> listCampaigns() async {
    final res = await _func.httpsCallable('listFundCampaigns').call();

    // 1) res.data 를 일단 List<dynamic> 으로 받고
    final rawList = res.data;
    if (rawList is! List) {
      throw Exception('Unexpected format: listFundCampaigns did not return a List');
    }

    // 2) 요소 하나하나를 Map<String,dynamic> 으로 변환
    return rawList.map<FundCampaign>((element) {
      if (element is! Map) {
        throw Exception('Unexpected element type in campaigns list');
      }
      // Map<Object?,Object?> → Map<String,dynamic>
      final map = Map<String, dynamic>.from(
        element.map((key, value) => MapEntry(key.toString(), value)),
      );
      return FundCampaign.fromJson(map);
    }).toList();
  }

  /*──────── 캠페인 생성 ────────*/
  Future<CreateCampaignResult> createCampaign(
      CreateCampaignParams params) async {
    final res =
    await _func.httpsCallable('createFundCampaign').call(params.toJson());
    return CreateCampaignResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  /*──────── 기부 ────────*/
  Future<void> donate({
    required String campaignId,
    required int amount,
  }) async {
    await _func
        .httpsCallable('donateToCampaign')
        .call({'campaignId': campaignId, 'amount': amount});
  }
  /*══════════════  Lessons & Quiz helpers  ══════════════*/

  /// ① 레슨 완료 여부 확인
  ///    ‣ users/{uid}/progress/{lessonId} 문서에
  ///      { isLessonDone:true , quizDone:true } 둘 다 만족하면 true
  Future<bool> isLessonCompleted(String lessonId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _fs
        .doc('users/$uid/progress/$lessonId')
        .get(const GetOptions(source: Source.server)); // 항상 최신

    if (!snap.exists) return false;
    final d = snap.data()!;
    return (d['isLessonDone'] ?? false) && (d['quizDone'] ?? false);
  }

  /// ② 퀴즈 한 문제 채점 & 포인트 지급
  ///    Cloud Function **answerQuiz** 호출 → Firestore-based 트랜잭션
  ///
  /// 반환 구조
  /// ```json
  /// {
  ///   "isCorrect"       : true,
  ///   "awarded"         : 10,
  ///   "alreadyAnswered" : false
  /// }
  /// ```
  Future<Map<String, dynamic>> submitQuizAnswer({
    required String lessonId,
    required String quizId,
    required int answerIndex,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final res = await _func
        .httpsCallable('answerQuiz')
        .call({
      'lessonId' : lessonId,
      'quizId'   : quizId,
      'answerIdx': answerIndex,
    });

    final data = Map<String, dynamic>.from(res.data);

    // 포인트 프로바이더 등과 연동하고 싶으면 여기서 처리
    if (data['awarded'] is int && data['awarded'] > 0) {
      notifyPointsChanged();
    }

    return data;
  }

  /// ③ 레슨의 모든 퀴즈를 제출한 뒤 호출(선택 사항)
  ///    – 점수 합산·progress 업데이트를 **클라이언트에서** 보장하고 싶을 때 사용
  ///
  /// `quizResults` 형식:
  /// ```dart
  /// [
  ///   {'quizId':'1','isCorrect':true ,'pointsEarned':10},
  ///   {'quizId':'2','isCorrect':false,'pointsEarned':0},
  /// ]
  /// ```
  Future<void> completeLessonWithQuizzes({
    required String lessonId,
    required List<Map<String, dynamic>> quizResults,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    // 이미 완료됐는지 한번 더 확인
    if (await isLessonCompleted(lessonId)) return;

    final totalEarned = quizResults.fold<int>(
        0, (s, r) => s + (r['pointsEarned'] as int? ?? 0));

    final userRef = _fs.doc('users/$uid');
    final progRef = userRef.collection('progress').doc(lessonId);

    await _fs.runTransaction((tx) async {
      tx.set(progRef, {
        'quizDone'    : true,
        'updatedAt'   : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (totalEarned > 0) {
        tx.update(userRef, {
          'point'     : FieldValue.increment(totalEarned),
          'updatedAt' : FieldValue.serverTimestamp(),
        });
      }
    });

    if (totalEarned > 0) notifyPointsChanged();
  }

  Future<List<LessonStep>> fetchLessonSteps(String lessonId) async {
    final qs = await _fs
        .collection('lessons')
        .doc(lessonId)
        .collection('steps')
        .orderBy(FieldPath.documentId)        // 0,1,2…
        .get();

    return qs.docs
        .map((d) => LessonStep.fromDoc(d.data()))
        .toList();
  }

}