import 'package:flutter/material.dart';
import 'package:bloom/data/services/eco_backend.dart';

class RankingWidget extends StatefulWidget {
  final bool showAsModal;
  final String? title;
  final Color? primaryColor;
  final VoidCallback? onRefresh;

  const RankingWidget({
    super.key,
    this.showAsModal = true,
    this.title,
    this.primaryColor,
    this.onRefresh,
  });

  @override
  State<RankingWidget> createState() => _RankingWidgetState();
}

class _RankingWidgetState extends State<RankingWidget> {
  Map<String, dynamic>? _myLeague;
  List<Map<String, dynamic>> _leagueRanking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLeague();
  }

  Color get primaryColor => widget.primaryColor ?? Colors.green;

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
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
    
    // 리그 랭킹 새로고침
    if (_myLeague != null && _myLeague!['leagueId'] != null) {
      _listenToLeagueRanking(_myLeague!['leagueId']);
    } else {
      _loadMyLeague();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsModal) {
      return _buildModalContent();
    } else {
      return _buildInlineContent();
    }
  }

  Widget _buildModalContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildRankingList()),
        ],
      ),
    );
  }

  Widget _buildInlineContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 300, child: _buildRankingList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: widget.showAsModal ? Radius.zero : const Radius.circular(12),
          bottomRight: widget.showAsModal ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.eco,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title ?? 'Ranking',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            GestureDetector(
              onTap: _refreshRanking,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return Container(
      padding: const EdgeInsets.all(20),
      child: RefreshIndicator(
        onRefresh: () async {
          _refreshRanking();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.builder(
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
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEmpty 
                    ? Colors.grey[100]
                    : isCurrentUser 
                        ? Colors.blue[50] 
                        : isTopThree 
                            ? primaryColor.withOpacity(0.1) 
                            : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEmpty
                      ? Colors.grey[300]!
                      : isCurrentUser 
                          ? Colors.blue[300]!
                          : isTopThree 
                              ? primaryColor.withOpacity(0.3) 
                              : Colors.grey[200]!,
                  width: isCurrentUser ? 3 : 1,
                  style: isEmpty ? BorderStyle.none : BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
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
                  if (!isEmpty)
                    Flexible(
                      child: Text(
                        '${member['point'] ?? 0}p',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.blue[600] : primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPromoteLine() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
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

// 드래그 핸들 위젯 (garden에서 사용)
class RankingDragHandle extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final Color? primaryColor;

  const RankingDragHandle({
    super.key,
    required this.onTap,
    this.title = 'Ranking',
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Colors.green;
    
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dy < -10) {
          onTap();
        }
      },
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.leaderboard,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}