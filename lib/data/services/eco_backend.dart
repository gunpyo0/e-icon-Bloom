// lib/services/eco_backend.dart
//  Flutter 3.16.x  /  Firebase SDK  November 2025

import 'dart:io';
import 'package:bloom/data/models/fund.dart';
import 'package:bloom/data/models/lesson_models.dart';
import 'package:bloom/data/models/quiz.dart';
import 'package:bloom/data/services/backend_providers.dart';
import 'package:bloom/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  Future<UserCredential> signIn(String displayName, String email, String pw) async {
    try {
      // 사용자 생성
      final UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);

      final String uid = cred.user!.uid;

      // Firebase Auth 사용자 정보 업데이트 (displayName 설정)
      await cred.user!.updateDisplayName(displayName);
      await cred.user!.reload(); // 사용자 정보 새로고침

      // Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'totalPoints': 0,
        'eduPoints': 0,
        'jobPoints': 0,
        'completedLessons': 0,
        'completedLessonIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('User created successfully with displayName: $displayName');
      return cred;
    } catch (e) {
      // 에러 로깅 또는 처리
      print('Error signing in: $e');
      rethrow; // 또는 원하는 방식으로 에러 처리
    }
  }



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
      // 현재 사용자 디버그
      await debugCurrentUser();

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      print('=== MY PROFILE DEBUG START ===');
      print('Requesting profile for UID: ${user.uid}');
      print('User email: ${user.email}');

      // 현재 사용자의 Firestore 문서만 조회
      final userDoc = await _fs.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        print('Found Firestore document for current user');
        print('Document UID: ${userDoc.id}');
        print('Document email: ${userData['email']}');
        print('Document displayName: ${userData['displayName']}');

        // 보안 검증: Firestore 문서의 이메일과 Firebase Auth 이메일이 일치하는지 확인
        if (userData['email'] != user.email) {
          print('Email mismatch detected, updating Firestore document');
          print('Firebase Auth email: ${user.email}');
          print('Firestore document email: ${userData['email']}');

          // Firestore 문서의 이메일을 Firebase Auth의 이메일로 업데이트
          await _fs.collection('users').doc(user.uid).update({
            'email': user.email,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('Updated Firestore document email to: ${user.email}');
          userData['email'] = user.email; // 로컬 데이터도 업데이트
        }

        // displayName 처리
        String displayName = userData['displayName'] ??
                            user.displayName ??
                            user.email?.split('@')[0] ??
                            'User';

        print('Final displayName: $displayName');
        print('=== MY PROFILE DEBUG END ===');

        return {
          'uid': user.uid,
          'email': user.email,
          'displayName': displayName,
          'firestoreDisplayName': userData['displayName'],  // 디버그용
          'firebaseDisplayName': user.displayName,          // 디버그용
          'photoURL': user.photoURL ?? userData['photoURL'],
          'totalPoints': userData['totalPoints'] ?? 0,
          'eduPoints': userData['eduPoints'] ?? 0,
          'jobPoints': userData['jobPoints'] ?? 0,
          'completedLessons': userData['completedLessons'] ?? 0,
          'completedLessonIds': userData['completedLessonIds'] ?? [],
        };
      } else {
        print('No Firestore document found for current user');
        // Firestore 문서가 없으면 기본값으로 생성
        final basicProfile = {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'firestoreDisplayName': null,
          'firebaseDisplayName': user.displayName,
          'photoURL': user.photoURL,
          'totalPoints': 0,
          'eduPoints': 0,
          'jobPoints': 0,
          'completedLessons': 0,
          'completedLessonIds': [],
        };

        // 기본 프로필을 Firestore에 저장
        await _fs.collection('users').doc(user.uid).set({
          'displayName': basicProfile['displayName'],
          'email': user.email,
          'totalPoints': 0,
          'eduPoints': 0,
          'jobPoints': 0,
          'completedLessons': 0,
          'completedLessonIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return basicProfile;
      }
    } catch (e) {
      print('Error in myProfile: $e');
      throw Exception('프로필을 불러올 수 없습니다: $e');
    }
  }

  Future<Map<String, dynamic>> myLeague() async {
    return (await _func.httpsCallable('getMyLeague').call()).data;
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
        // 포인트 차감과 정원 데이터를 한 번에 업데이트
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

    // 리그 멤버 포인트도 함께 업데이트
    await _updateLeagueMemberPoints(uid, amount);
  }

  /// 리그 멤버의 포인트 업데이트
  Future<void> _updateLeagueMemberPoints(String uid, int amount) async {
    try {
      // 사용자의 리그 정보 가져오기
      final myLeagueData = await myLeague();
      final leagueId = myLeagueData['leagueId'];

      if (leagueId == null) {
        print('User not in any league, skipping league point update');
        return;
      }

      // 리그 멤버 문서 참조
      final memberDocRef = _fs.collection('leagues').doc(leagueId).collection('members').doc(uid);

      // 현재 사용자 문서에서 최신 포인트 가져오기
      final userDoc = await _fs.collection('users').doc(uid).get();
      final totalPoints = userDoc.data()?['totalPoints'] ?? 0;

      // 리그 멤버 포인트 업데이트
      await memberDocRef.update({
        'point': totalPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ League member points updated: $totalPoints for user $uid in league $leagueId');
    } catch (e) {
      print('⚠️ Failed to update league member points: $e');
      // 리그 포인트 업데이트 실패는 치명적이지 않으므로 에러를 던지지 않음
    }
  }

  /// 현재 사용자의 리그 포인트를 수동으로 동기화
  Future<void> syncMyLeaguePoints() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No current user, skipping league sync');
        return;
      }

      print('🔄 Syncing league points for current user...');
      await _updateLeagueMemberPoints(user.uid, 0); // amount는 실제로 사용되지 않음
    } catch (e) {
      print('⚠️ Failed to sync league points: $e');
    }
  }

  /*──────────────────────── Posts ────────────────────────────*/
  /// ① 새 글 생성 → Storage 업로드 경로 반환
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

  /// ② 특정 포스트 가져오기 (allPosts에서 찾기)
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    final allPosts = await this.allPosts();
    try {
      return allPosts.firstWhere((post) => post['id'] == postId);
    } catch (e) {
      return null; // 포스트를 찾지 못한 경우
    }
  }

  /// ③ 투표
  Future<void> votePost(String postId, int score) =>
      _func.httpsCallable('votePost').call({'postId': postId, 'score': score});

  /// ④ 피드
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

      // 사용자를 리그 멤버로 추가 (Firestore에서 displayName 가져오기)
      String displayName = 'User';
      try {
        final userDoc = await _fs.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          displayName = userData['displayName'] ??
                       currentUser?.displayName ??
                       currentUser?.email?.split('@')[0] ??
                       'User';
        } else {
          displayName = currentUser?.displayName ??
                       currentUser?.email?.split('@')[0] ??
                       'User';
        }
      } catch (e) {
        print('Error getting displayName from Firestore: $e');
        displayName = currentUser?.displayName ??
                     currentUser?.email?.split('@')[0] ??
                     'User';
      }
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
      print('=== FIXING LEAGUE MEMBER DISPLAY NAMES ===');

      // 모든 리그에서 displayName이 "null"인 멤버들 찾고 수정
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
          final currentDisplayName = memberData['displayName'];

          print('Member $uid has displayName: "$currentDisplayName"');

          // displayName이 "null" 문자열이거나 null인 경우 수정
          if (currentDisplayName == null ||
              currentDisplayName.toString() == 'null' ||
              currentDisplayName.toString().trim().isEmpty) {

            try {
              print('Fixing displayName for user: $uid');

              // 해당 사용자의 프로필에서 올바른 displayName 가져오기
              final userDoc = await _fs.collection('users').doc(uid).get();
              String correctDisplayName = 'User';

              if (userDoc.exists) {
                final userData = userDoc.data()!;
                correctDisplayName = userData['displayName'] ??
                                   userData['email']?.split('@')[0] ??
                                   'User ${uid.substring(0, 8)}';
                print('Found correct displayName in user profile: $correctDisplayName');
              } else {
                // user 문서가 없으면 Firebase Auth에서 가져오기 시도
                if (uid == currentUser?.uid) {
                  correctDisplayName = currentUser?.displayName ??
                                     currentUser?.email?.split('@')[0] ??
                                     'User ${uid.substring(0, 8)}';
                  print('Got displayName from Firebase Auth: $correctDisplayName');
                } else {
                  correctDisplayName = 'User ${uid.substring(0, 8)}';
                  print('Using fallback displayName: $correctDisplayName');
                }
              }

              // 리그 멤버 문서 업데이트
              await _fs
                  .collection('leagues')
                  .doc(leagueId)
                  .collection('members')
                  .doc(uid)
                  .update({
                'displayName': correctDisplayName,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              print('Successfully updated displayName for $uid: "$correctDisplayName"');

            } catch (e) {
              print('Failed to fix displayName for user $uid: $e');
            }
          }
        }
      }

      print('=== DISPLAY NAME FIX COMPLETED ===');

    } catch (e) {
      print('Error during display name fix: $e');
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

  /*──────────────────── Firebase Auth 상태 디버깅 ────────────────────*/
  Future<void> debugCurrentUser() async {
    final user = _auth.currentUser;
    print('=== FIREBASE AUTH DEBUG ===');
    if (user == null) {
      print('ERROR: No current user signed in!');
      return;
    }

    print('Current User Info:');
    print('  UID: ${user.uid}');
    print('  Email: ${user.email}');
    print('  DisplayName: ${user.displayName}');
    print('  EmailVerified: ${user.emailVerified}');
    print('  IsAnonymous: ${user.isAnonymous}');
    print('  PhotoURL: ${user.photoURL}');
    print('  CreationTime: ${user.metadata.creationTime}');
    print('  LastSignInTime: ${user.metadata.lastSignInTime}');

    // Firestore 문서도 확인
    try {
      final userDoc = await _fs.collection('users').doc(user.uid).get();
      print('Firestore Document:');
      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('  Document ID: ${userDoc.id}');
        print('  DisplayName: ${data['displayName']}');
        print('  Email: ${data['email']}');
        print('  TotalPoints: ${data['totalPoints']}');
        print('  CreatedAt: ${data['createdAt']}');
      } else {
        print('  ERROR: No Firestore document found for this user!');
      }
    } catch (e) {
      print('  ERROR reading Firestore: $e');
    }
    print('==========================');
  }

  /*──────────────────── 기존 사용자 displayName 수정 ────────────────────*/
  Future<void> updateCurrentUserDisplayName(String newDisplayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      print('=== UPDATING USER DISPLAY NAME ===');
      print('Current UID: ${user.uid}');
      print('New displayName: $newDisplayName');

      // 1. Firebase Auth 업데이트
      await user.updateDisplayName(newDisplayName);
      await user.reload();
      print('Firebase Auth displayName updated');

      // 2. Firestore 업데이트
      await _fs.collection('users').doc(user.uid).update({
        'displayName': newDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Firestore displayName updated');

      // 3. 리그 멤버 정보도 업데이트
      try {
        final myLeagueData = await myLeague();
        final leagueId = myLeagueData['leagueId'];
        if (leagueId != null) {
          await _fs.collection('leagues').doc(leagueId).collection('members').doc(user.uid).update({
            'displayName': newDisplayName,
          });
          print('League member displayName updated');
        }
      } catch (e) {
        print('Warning: Could not update league member name: $e');
      }

      print('=== UPDATE COMPLETED ===');
    } catch (e) {
      print('Error updating displayName: $e');
      throw Exception('이름 업데이트에 실패했습니다: $e');
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
  /// 모든 리그 멤버 정원 한번에 가져오기 – Cloud Function 버전
      // _auth

  /// 리그 멤버들의 정원 정보를 Cloud Function에서 받아서
  /// Unity 가 이해할 형태(Map 3×3 tiles)로 변환해 반환한다.
  Future<List<Map<String, dynamic>>> getLeagueMembersGardens() async {
    try {
      /* 1) 내 UID 확보 -------------------------------------------------- */
      final uid = _auth.currentUser?.uid;
      debugPrint('[getLeagueMembersGardens] myUid = $uid');
      if (uid == null) return [];

      /* 2) CF 호출 ------------------------------------------------------ */
      final res = await _func
          .httpsCallable('getLeagueMembersGardens')
          .call({'uid': uid});
      debugPrint('[getLeagueMembersGardens] raw CF res = ${res.data}');

      /* 3) 최상위 data 꺼내기 ------------------------------------------ */
      final Map<String, dynamic> top = Map<String, dynamic>.from(res.data);
      final Map<String, dynamic> data = top['data'] is Map
          ? Map<String, dynamic>.from(top['data'])
          : top; // 'ok' 필드 없이 data 만 올 수도
      debugPrint('[getLeagueMembersGardens] extracted data = $data');

      /* 4) members 배열 파싱 ------------------------------------------- */
      final List<dynamic> membersRaw = data['members'] ?? [];
      debugPrint('[getLeagueMembersGardens] membersRaw.length = ${membersRaw.length}');

      final List<Map<String, dynamic>> memberGardens = [];

      /* 5) 각 멤버 처리 ------------------------------------------------- */
      for (final m in membersRaw.take(9)) {
        final member = Map<String, dynamic>.from(m);
        debugPrint('  ↳ member uid=${member['uid']} name=${member['name']}');

        /* 5-1) garden 추출 */
        final gardenRaw = Map<String, dynamic>.from(member['garden'] ?? {});
        debugPrint('    gardenRaw(size=${gardenRaw['size']} tiles=${gardenRaw['tiles']?.length})');

        /* 5-2) tiles 정규화: List → Map<String,dynamic> */
        if (gardenRaw['tiles'] is List) {
          debugPrint('    tiles is List → Map 변환');
          final tilesList = List.from(gardenRaw['tiles']);
          final tilesMap  = <String, dynamic>{};
          for (var i = 0; i < tilesList.length; i++) {
            final t = Map<String, dynamic>.from(tilesList[i]);
            tilesMap[i.toString()] = t;
          }
          gardenRaw['tiles'] = tilesMap;
        } else if (gardenRaw['tiles'] is Map) {
          debugPrint('    tiles already Map → key/value 정규화');
          final tilesNorm = <String, dynamic>{};
          (gardenRaw['tiles'] as Map).forEach((k, v) {
            if (v is Map) tilesNorm[k.toString()] = Map<String, dynamic>.from(v);
          });
          gardenRaw['tiles'] = tilesNorm;
        } else {
          debugPrint('    tiles field missing → {}');
          gardenRaw['tiles'] = {};
        }

        /* 5-3) memberInfo 삽입 ----------------------------------------- */
        gardenRaw['memberInfo'] = {
          'uid'        : member['uid'],
          'displayName': member['name'] ?? 'Unknown Player',
          'points'     : member['point'] ?? 0,
          'totalPoints': member['totalPoints'] ?? 0,
        };

        gardenRaw['size']  ??= gardenRaw['tiles'].length == 9 ? 3 : 3;
        memberGardens.add(gardenRaw);

        debugPrint('    ✔ processed garden size=${gardenRaw['size']}');
      }

      debugPrint('[getLeagueMembersGardens] ✅ total processed = ${memberGardens.length}');
      return memberGardens;
    } catch (e, st) {
      debugPrint('[getLeagueMembersGardens] ❌ Error: $e\n$st');
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
      return userData['point'] ?? 0;
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
    debugPrint('📡 Calling listFundCampaigns...');
    final res = await _func.httpsCallable('listFundCampaigns').call();

    // 1) res.data 를 일단 List<dynamic> 으로 받고
    final rawList = res.data;
    debugPrint('📋 Got ${rawList?.length ?? 0} campaigns from server');
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
      debugPrint('📦 Campaign raw data: ${map['id']} - bannerPath: "${map['bannerPath']}"');
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
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 1. Cloud Function으로 기부 처리
      await _func
          .httpsCallable('donateToCampaign')
          .call({'campaignId': campaignId, 'amount': amount});

      print('✅ Donation completed via Cloud Function');

      // 2. 로컬에서 포인트 차감 및 리그 동기화
      await _addPointsLocal(user.uid, -amount);
      print('✅ Local points deducted: -$amount');

      // 포인트 변경 알림
    } catch (e) {
      print('❌ Donation failed: $e');
      rethrow;
    }
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

  /*════════════ Lessons helpers ════════════*/

  /// A. 단계 완료 → Cloud Function `completeStep`
  Future<Map<String, dynamic>> nextStep(Stepadder s) async {
    final res = await _func.httpsCallable('completeStep').call(s.toJson());
    final data = Map<String, dynamic>.from(res.data);
                        // 단계 완료 시 포인트 변동 가능
    return data;                                    // {highestStep,isLessonDone,addPoint}
  }

  /// B. 퀴즈 채점  → Cloud Function `answerQuiz`
  Future<Map<String, dynamic>> answerQuiz({
    required String lessonId,
    required String quizId,
    required int    answerIdx,
  }) async {
    final res = await _func.httpsCallable('answerQuiz').call({
      'lessonId' : lessonId,
      'quizId'   : quizId,
      'answerIdx': answerIdx,
    });
    final data = Map<String, dynamic>.from(res.data);
    return data;                                    // {isCorrect,awarded,alreadyAnswered}
  }

  // lib/services/eco_backend.dart
/*════════════ Lessons helpers ════════════*/
  /// C. 진행 현황 1건 읽기 (Firestore 직통)
  Future<Map<String, dynamic>> lessonProgress(String lessonId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _emptyProgress;
    final snap = await _fs.doc('users/$uid/progress/$lessonId').get();
    return snap.exists ? snap.data()! : _emptyProgress;
  }

  static const _emptyProgress = {
    'highestStep': -1,
    'isLessonDone': false,
    'quizDone': false,
  };
/*════════════ 배열-정원(garden.ts) helpers ════════════*/

  /// 배열 기반 정원 조회 (uid 지정 가능, 기본 = 내 uid)
  Future<Map<String, dynamic>> getArrayGarden({String? uid}) async {
    uid ??= _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    final res = await _func.httpsCallable('getGarden').call({'uid': uid});
    return Map<String, dynamic>.from(res.data);
  }

  /// 타일 심기 – index: 0 ~ size²-1
  Future<void> plantTileArray(int index, String cropId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    await _func.httpsCallable('plantTile')
        .call({'uid': uid, 'index': index, 'cropId': cropId});
  }

  /// 타일 업그레이드(성장) – index: 0 ~ size²-1
  Future<void> upgradeTileArray(int index) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    debugPrint("끼얏호우${uid}, ${index}");
    await _func.httpsCallable('upgradeTile')
        .call({'uid': uid, 'index': index});
  }

  /// 타일 제거(환급) – index: 0 ~ size²-1
  Future<void> removeTileArray(int index) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    await _func.httpsCallable('removeTile')
        .call({'uid': uid, 'index': index});
  }

  /// 정원 총 자산(투자 포인트) 계산
  Future<int> getGardenAsset() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    final res = await _func.httpsCallable('getGardenAsset')
        .call({'uid': uid});
    return (res.data as Map)['asset'] as int? ?? 0;
  }

  /// 🔧 (선택) 정원 크기 리사이즈 – league 승급 시 사용
  Future<void> resizeArrayGarden(int newSize) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    await _func.httpsCallable('resizeGarden')
        .call({'uid': uid, 'newSize': newSize});
  }

}