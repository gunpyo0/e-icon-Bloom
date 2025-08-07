import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/providers/points_provider.dart';

final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // 현재 사용자 상태를 감지하여 사용자가 변경되면 프로필도 새로고침
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser.value == null) {
    throw Exception('로그인이 필요합니다');
  }
  
  return await EcoBackend.instance.myProfile();
});

final leagueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // 현재 사용자 상태를 감지
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser.value == null) {
    throw Exception('로그인이 필요합니다');
  }
  
  return await EcoBackend.instance.myLeague();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final leagueAsync = ref.watch(leagueProvider);
    final pointsAsync = ref.watch(pointsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => context.push('/debug'),
            tooltip: 'Debug Page',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(leagueProvider);
          await ref.read(pointsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileCard(context, profileAsync, leagueAsync),
              const SizedBox(height: 16),
              _buildStatsCard(context, profileAsync),
              const SizedBox(height: 16),
              _buildLeagueCard(context, leagueAsync),
              const SizedBox(height: 16),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> profileAsync,
    AsyncValue<Map<String, dynamic>> leagueAsync,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: profileAsync.when(
                data: (profile) {
                  final photoUrl = profile['photoURL'] as String?;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    return ClipOval(
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, color: Colors.white, size: 40);
                        },
                      ),
                    );
                  }
                  return const Icon(Icons.person, color: Colors.white, size: 40);
                },
                loading: () => const Icon(Icons.person, color: Colors.white, size: 40),
                error: (_, __) => const Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            profileAsync.when(
              data: (profile) => Column(
                children: [
                  Text(
                    profile['displayName'] ?? profile['email'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile['email'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 디버그 정보 표시
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        Text('UID: ${profile['uid'] ?? 'null'}'),
                        Text('Email: ${profile['email'] ?? 'null'}'),
                        Text('Firebase displayName: ${profile['firebaseDisplayName'] ?? 'null'}'),
                        Text('Firestore displayName: ${profile['firestoreDisplayName'] ?? 'null'}'),
                        Text('Final displayName: ${profile['displayName'] ?? 'null'}'),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, ref, child) {
                            return ElevatedButton(
                              onPressed: () => _showUpdateNameDialog(context, ref),
                              child: const Text('이름 수정'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Column(
                children: [
                  Text(
                    'Loading...',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              error: (error, _) => Column(
                children: [
                  const Text(
                    'Profile Load Failed',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.toString(),
                    style: TextStyle(fontSize: 14, color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, AsyncValue<Map<String, dynamic>> profileAsync) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Activities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            profileAsync.when(
              data: (profile) => Column(
                children: [
                  // Real-time points display
                  Consumer(
                    builder: (context, ref, child) {
                      final pointsAsync = ref.watch(pointsProvider);
                      return pointsAsync.when(
                        data: (totalPoints) => _buildStatRow('Total Points', '$totalPoints P'),
                        loading: () => _buildStatRow('Total Points', 'Loading...'),
                        error: (_, __) => _buildStatRow('Total Points', '${profile['totalPoints'] ?? 0} P'),
                      );
                    },
                  )
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Unable to load data',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueCard(BuildContext context, AsyncValue<Map<String, dynamic>> leagueAsync) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'League Membership',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            leagueAsync.when(
              data: (league) {
                // If leagueId exists, participating; if not, not participating
                final hasLeague = league['leagueId'] != null;
                final leagueInfo = league['league'] != null 
                    ? Map<String, dynamic>.from(league['league'] as Map)
                    : null;
                
                if (!hasLeague) {
                  return Column(
                    children: [
                      _buildStatRow('League Name', 'Not Participating'),
                      const SizedBox(height: 12),
                      _buildStatRow('My Rank', '-'),
                      const SizedBox(height: 12),
                      _buildStatRow('Total Participants', '-'),
                    ],
                  );
                }
                
                return Column(
                  children: [
                    _buildStatRow('League Name', 'League S${leagueInfo?['stage'] ?? 1}L${leagueInfo?['index'] ?? 1}'),
                    const SizedBox(height: 12),
                    _buildStatRow('My Rank', '#${league['rank'] ?? 0}'),
                    const SizedBox(height: 12),
                    _buildStatRow('Total Participants', '${leagueInfo?['memberCount'] ?? 0}'),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Unable to load league information',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to settings
            },
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to my garden
            },
            icon: const Icon(Icons.yard),
            label: const Text('View My Garden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await EcoBackend.instance.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateNameDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('새로운 이름을 입력하세요:'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await EcoBackend.instance.updateCurrentUserDisplayName(newName);
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이름이 성공적으로 변경되었습니다')),
                    );
                    // 프로필 새로고침
                    ref.invalidate(profileProvider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('이름 변경 실패: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}