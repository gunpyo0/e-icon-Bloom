import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  Map<String, dynamic>? _myLeague;
  List<Map<String, dynamic>> _leagueRanking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLeague();
  }

  Future<void> _initializeLeague() async {
    try {
      setState(() => _isLoading = true);
      
      // 자동 리그 참여 확인
      await EcoBackend.instance.ensureUserInLeague();
      
      // 내 리그 정보 로드
      await _loadMyLeague();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyLeague() async {
    try {
      final league = await EcoBackend.instance.myLeague();
      setState(() {
        _myLeague = league;
      });
      
      if (league['leagueId'] != null) {
        _listenToLeagueRanking(league['leagueId']);
      }
    } catch (e) {
      print('Failed to load league: $e');
      // 리그 정보 로드 실패 시 다시 자동 참여 시도
      await EcoBackend.instance.ensureUserInLeague();
      try {
        final league = await EcoBackend.instance.myLeague();
        setState(() {
          _myLeague = league;
        });
        if (league['leagueId'] != null) {
          _listenToLeagueRanking(league['leagueId']);
        }
      } catch (retryError) {
        print('Retry failed: $retryError');
      }
    }
  }

  void _listenToLeagueRanking(String leagueId) {
    EcoBackend.instance.leagueMembers(leagueId).listen(
      (snapshot) {
        final ranking = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        // 포인트 기준으로 내림차순 정렬
        ranking.sort((a, b) => (b['point'] ?? 0).compareTo(a['point'] ?? 0));
        
        setState(() {
          _leagueRanking = ranking;
        });
      },
      onError: (error) {
        print('Error listening to league ranking: $error');
      },
    );
  }

  Future<void> _refreshRanking() async {
    // 리그 랭킹 새로고침
    if (_myLeague != null && _myLeague!['leagueId'] != null) {
      _listenToLeagueRanking(_myLeague!['leagueId']);
    } else {
      _loadMyLeague();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text(
          'Ranking',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _refreshRanking,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildRankingContent(),
    );
  }

  Widget _buildRankingContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading ranking...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 7명으로 고정, 빈 자리 채우기
    final List<Map<String, dynamic>> fullRanking = [];
    
    // 유효한 멤버들 추가 (최대 7명)
    final validMembers = _leagueRanking.toList();
    for (int i = 0; i < validMembers.length && i < 7; i++) {
      fullRanking.add(validMembers[i]);
    }
    
    // 빈 자리 채우기 (7명까지)
    for (int i = validMembers.length; i < 7; i++) {
      fullRanking.add({
        'id': 'empty_$i',
        'displayName': '빈 자리',
        'point': 0,
        'isEmpty': true,
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshRanking();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildLeagueInfo(),
            const SizedBox(height: 20),
            _buildRankingList(fullRanking),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.leaderboard,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'League Ranking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_myLeague != null) ...[
            const SizedBox(height: 12),

            Text(
              'Members: ${_leagueRanking.length}/7',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> fullRanking) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Ranking Board',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // 랭킹 리스트
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8, // 7명 + PROMOTE 선 1개
            itemBuilder: (context, index) {
              // PROMOTE 선을 3등 뒤에 표시
              if (index == 3) {
                return _buildPromoteLine();
              }
              
              // 인덱스 조정 (PROMOTE 선 때문에)
              final rankingIndex = index > 3 ? index - 1 : index;
              if (rankingIndex >= 7) return Container();
              
              final member = fullRanking[rankingIndex];
              final rank = rankingIndex + 1;
              final isCurrentUser = member['id'] == EcoBackend.instance.uidOrEmpty;
              final isEmpty = member['isEmpty'] == true;
              final isTopThree = rank <= 3 && !isEmpty;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEmpty 
                      ? Colors.grey[100]
                      : isCurrentUser 
                          ? Colors.blue[50] 
                          : isTopThree 
                              ? Colors.green[50] 
                              : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEmpty
                        ? Colors.grey[300]!
                        : isCurrentUser 
                            ? Colors.blue[300]!
                            : isTopThree 
                                ? Colors.green[300]!
                                : Colors.grey[200]!,
                    width: isCurrentUser ? 3 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 순위 배지
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? Colors.grey[300]
                            : isCurrentUser 
                                ? Colors.blue[600]
                                : rank == 1 && !isEmpty
                                    ? Colors.amber[600]
                                    : rank == 2 && !isEmpty
                                        ? Colors.grey[400]
                                        : rank == 3 && !isEmpty
                                            ? Colors.brown[400]
                                            : Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isEmpty
                            ? Icon(
                                Icons.person_add_outlined,
                                color: Colors.grey[500],
                                size: 20,
                              )
                            : Text(
                                '$rank',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // 아바타
                    CircleAvatar(
                      backgroundColor: isEmpty 
                          ? Colors.grey[200] 
                          : isCurrentUser 
                              ? Colors.blue[100] 
                              : Colors.grey[300],
                      child: isEmpty
                          ? Icon(
                              Icons.person_outline,
                              color: Colors.grey[400],
                            )
                          : Text(
                              (member['displayName'] ?? member['name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: isCurrentUser ? Colors.blue[700] : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    
                    // 사용자 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['displayName'] ?? member['name'] ?? 'User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isEmpty 
                                  ? Colors.grey[400]
                                  : isCurrentUser 
                                      ? Colors.blue[700] 
                                      : Colors.black,
                              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (isCurrentUser && !isEmpty)
                            Text(
                              'You',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // 포인트
                    if (!isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blue[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${member['point'] ?? 0}p',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCurrentUser ? Colors.blue[700] : Colors.green[700],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPromoteLine() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[300]!,
                    Colors.orange[500]!,
                    Colors.orange[300]!,
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[500],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'PROMOTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[300]!,
                    Colors.orange[500]!,
                    Colors.orange[300]!,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}