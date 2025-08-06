// learn_screen.dart – Learn 페이지 (자동 새로고침 & 풀투리프레시)
// =============================================================
// 🔸 앱이 포그라운드로 돌아오거나 탭 전환 시 invalidate
// 🔸 디테일 화면에서 돌아오면 해당 레슨/프로바이더만 새로고침
// 🔸 RefreshIndicator 로 당겨서 새로고침도 지원

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/models/lesson_models.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'lesson_detail_screen.dart';

enum LessonStatus { locked, available, completed }

/*──────────────────────── Providers ────────────────────────*/
final lessonsProvider = FutureProvider.autoDispose<List<LessonMeta>>( (ref) => EcoBackend.instance.listLessons());
final progressProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, lessonId) => EcoBackend.instance.lessonProgress(lessonId));
final isDoneProvider = FutureProvider.family<bool, String>((ref, lessonId) async {
  final p = await EcoBackend.instance.lessonProgress(lessonId);
  return p['isLessonDone'] == true && p['quizDone'] == true;
});
/*────────────────────────────────────────────────────────────*/

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLessons();
    }
  }

  /*──────────────── helpers ───────────────*/
  Future<void> _refreshLessons() async {
    ref.invalidate(lessonsProvider);
  }

  /*──────────────── UI ───────────────*/
  @override
  Widget build(BuildContext context) {
    final asyncLessons = ref.watch(lessonsProvider);

    return asyncLessons.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (lessons) => RefreshIndicator(
        onRefresh: _refreshLessons,
        child: _body(context, lessons),
      ),
    );
  }

  Widget _body(BuildContext ctx, List<LessonMeta> lessons) {
    final filtered = lessons.where((l) {
      final okId = int.tryParse(l.id) != null && int.parse(l.id) > 0;
      final okTitle = l.title.trim().isNotEmpty;
      return okId && okTitle;
    }).toList();

    final grouped = <String, List<LessonMeta>>{};
    for (final l in filtered) {
      grouped.putIfAbsent(l.themeId, () => []).add(l);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromRGBO(244, 234, 225, 1),
            const Color.fromRGBO(230, 220, 200, 1),
            const Color.fromRGBO(220, 210, 190, 1),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ...grouped.entries.map((entry) {
              final lessonList = entry.value;
              final biomeWidgets = <Widget>[];
              
              for (int i = 0; i < lessonList.length; i += 3) {
                final biomeIndex = i ~/ 3;
                final biomeLessons = lessonList.skip(i).take(3).toList();
                
                // 바이옴 전환 표시 (첫 번째가 아닌 경우)
                if (i > 0) {
                  biomeWidgets.add(_BiomeTransition(
                    color: lessonList.first.themeColor,
                    fromBiomeIndex: biomeIndex - 1,
                    toBiomeIndex: biomeIndex,
                  ));
                }

                // 바이옴 섹션
                biomeWidgets.add(_PathLessonSection(
                  metaList: biomeLessons,
                  color: lessonList.first.themeColor,
                  biomeIndex: biomeIndex,
                ));
              }
              
              return Column(children: biomeWidgets);
            }).toList(),
          ],
        ),
      ),
    );
  }
}


/*──────────────────── Path Lesson 섹션 ────────────────────*/
class _PathLessonSection extends ConsumerWidget {
  final List<LessonMeta> metaList; 
  final Color color;
  final int biomeIndex;
  
  const _PathLessonSection({
    required this.metaList, 
    required this.color,
    required this.biomeIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Stack(
        children: [
          // 전체 화면 바이옴 배경
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _getBiomeGradient(),
              ),
              child: Stack(
                children: _getBiomeDecorations(),
              ),
            ),
          ),
          // 레슨 노드들
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _buildPathLayout(context, ref),
          ),
        ],
      ),
    );
  }

  LinearGradient _getBiomeGradient() {
    switch (biomeIndex % 4) {
      case 0: // 숲 바이옴
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[50]!,
            Colors.green[100]!.withOpacity(0.3),
            Colors.green[50]!,
          ],
        );
      case 1: // 사막 바이옴
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.orange[50]!,
            Colors.orange[100]!.withOpacity(0.3),
            Colors.yellow[50]!,
          ],
        );
      case 2: // 바다 바이옴
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.blue[100]!.withOpacity(0.3),
            Colors.lightBlue[50]!,
          ],
        );
      case 3: // 산 바이옴
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.grey[100]!.withOpacity(0.3),
            Colors.blueGrey[50]!,
          ],
        );
      default:
        return LinearGradient(
          colors: [
            Colors.white,
            color.withOpacity(0.1),
          ],
        );
    }
  }

  List<Widget> _getBiomeDecorations() {
    switch (biomeIndex % 4) {
      case 0: // 숲 바이옴 - 전체 화면에 자연스럽게 배치
        return [
          Positioned(
            top: 20,
            right: 30,
            child: Icon(Icons.local_florist, color: Colors.green[300]!.withOpacity(0.3), size: 32),
          ),
          Positioned(
            top: 80,
            left: 40,
            child: Icon(Icons.eco, color: Colors.green[400]!.withOpacity(0.2), size: 24),
          ),
          Positioned(
            bottom: 60,
            right: 60,
            child: Icon(Icons.park, color: Colors.green[500]!.withOpacity(0.25), size: 28),
          ),
          Positioned(
            bottom: 20,
            left: 50,
            child: Icon(Icons.grass, color: Colors.green[600]!.withOpacity(0.2), size: 20),
          ),
        ];
      case 1: // 사막 바이옴 - 햇빛과 선인장들
        return [
          Positioned(
            top: 15,
            right: 25,
            child: Icon(Icons.wb_sunny, color: Colors.orange[300]!.withOpacity(0.4), size: 40),
          ),
          Positioned(
            top: 70,
            left: 30,
            child: Icon(Icons.wb_sunny_outlined, color: Colors.yellow[400]!.withOpacity(0.3), size: 24),
          ),
          Positioned(
            bottom: 40,
            right: 40,
            child: Icon(Icons.brightness_7, color: Colors.orange[400]!.withOpacity(0.3), size: 26),
          ),
        ];
      case 2: // 바다 바이옴 - 물결과 물방울들
        return [
          Positioned(
            top: 20,
            left: 20,
            child: Icon(Icons.waves, color: Colors.blue[300]!.withOpacity(0.3), size: 30),
          ),
          Positioned(
            top: 60,
            right: 50,
            child: Icon(Icons.water_drop, color: Colors.blue[400]!.withOpacity(0.25), size: 22),
          ),
          Positioned(
            bottom: 50,
            left: 60,
            child: Icon(Icons.water, color: Colors.lightBlue[400]!.withOpacity(0.3), size: 28),
          ),
          Positioned(
            bottom: 20,
            right: 30,
            child: Icon(Icons.bubble_chart, color: Colors.blue[300]!.withOpacity(0.2), size: 18),
          ),
        ];
      case 3: // 산 바이옴 - 산과 구름들
        return [
          Positioned(
            top: 10,
            left: 30,
            child: Icon(Icons.terrain, color: Colors.grey[400]!.withOpacity(0.3), size: 35),
          ),
          Positioned(
            top: 50,
            right: 40,
            child: Icon(Icons.cloud, color: Colors.grey[300]!.withOpacity(0.25), size: 28),
          ),
          Positioned(
            bottom: 30,
            left: 45,
            child: Icon(Icons.landscape, color: Colors.blueGrey[400]!.withOpacity(0.3), size: 32),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildPathLayout(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final nodes = <Widget>[];
        
        for (int i = 0; i < metaList.length; i++) {
          final lesson = metaList[i];
          
          // 더 다양한 패턴으로 배치
          double leftMargin;
          double rightMargin;
          
          switch (i % 4) {
            case 0: // 왼쪽
              leftMargin = width * 0.05;
              rightMargin = width * 0.45;
              break;
            case 1: // 중앙 오른쪽
              leftMargin = width * 0.35;
              rightMargin = width * 0.15;
              break;
            case 2: // 오른쪽
              leftMargin = width * 0.45;
              rightMargin = width * 0.05;
              break;
            case 3: // 중앙 왼쪽
              leftMargin = width * 0.15;
              rightMargin = width * 0.35;
              break;
            default:
              leftMargin = width * 0.1;
              rightMargin = width * 0.4;
          }
          
          nodes.add(
            Container(
              margin: EdgeInsets.only(
                bottom: i == metaList.length - 1 ? 0 : 30,
                left: leftMargin,
                right: rightMargin,
              ),
              child: _PathLessonNode(
                meta: lesson, 
                themeColor: color,
                isLeft: i % 2 == 0,
                nodeIndex: i,
              ),
            ),
          );
          
        }
        
        return Column(children: nodes);
      },
    );
  }

}

/*──────────────────── 바이옴 전환 ────────────────────*/
class _BiomeTransition extends StatelessWidget {
  final Color color;
  final int fromBiomeIndex;
  final int toBiomeIndex;

  const _BiomeTransition({
    required this.color,
    required this.fromBiomeIndex,
    required this.toBiomeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        children: [
          // 게임 스타일 절단선
          CustomPaint(
            size: const Size(double.infinity, 40),
            painter: _BiomeTransitionPainter(
              color: color,
              fromBiome: fromBiomeIndex,
              toBiome: toBiomeIndex,
            ),
          ),

          const SizedBox(height: 8),

          // 바이옴 변경 알림
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getBiomeColor(fromBiomeIndex).withOpacity(0.8),
                  _getBiomeColor(toBiomeIndex).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getBiomeIcon(fromBiomeIndex), color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Icon(_getBiomeIcon(toBiomeIndex), color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_getBiomeName(toBiomeIndex)} Zone',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBiomeColor(int biomeIndex) {
    switch (biomeIndex % 4) {
      case 0: return Colors.green;
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.grey;
      default: return color;
    }
  }

  IconData _getBiomeIcon(int biomeIndex) {
    switch (biomeIndex % 4) {
      case 0: return Icons.local_florist;
      case 1: return Icons.wb_sunny;
      case 2: return Icons.waves;
      case 3: return Icons.terrain;
      default: return Icons.eco;
    }
  }

  String _getBiomeName(int biomeIndex) {
    switch (biomeIndex % 4) {
      case 0: return 'Forest';
      case 1: return 'Desert';
      case 2: return 'Ocean';
      case 3: return 'Mountain';
      default: return 'Nature';
    }
  }
}

/*──────────────────── 바이옴 전환 페인터 ────────────────────*/
class _BiomeTransitionPainter extends CustomPainter {
  final Color color;
  final int fromBiome;
  final int toBiome;

  _BiomeTransitionPainter({
    required this.color,
    required this.fromBiome,
    required this.toBiome,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 게임 스타일 테어(tear) 효과
    _drawTearEffect(canvas, size);

    // 양쪽에 크리스털 같은 효과
    _drawCrystalEffects(canvas, size);
  }

  void _drawTearEffect(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 3;

    // 불규칙한 테어 라인
    final tearPath = Path();
    final centerY = size.height * 0.5;

    tearPath.moveTo(0, centerY);

    // 불규칙한 찢어진 선 만들기
    final segments = 15;
    for (int i = 1; i <= segments; i++) {
      final x = (size.width / segments) * i;
      final randomOffset = (i % 3 == 0) ? 8 : (i % 2 == 0) ? -6 : 4;
      final y = centerY + randomOffset + (i % 4 == 0 ? -3 : 2);

      if (i % 2 == 0) {
        tearPath.quadraticBezierTo(
          x - 10, y + randomOffset * 0.5,
          x, y
        );
      } else {
        tearPath.lineTo(x, y);
      }
    }

    // 상단 영역 (이전 바이옴)
    final topPath = Path();
    topPath.moveTo(0, 0);
    topPath.lineTo(size.width, 0);
    topPath.addPath(tearPath, Offset.zero);
    topPath.lineTo(0, centerY);
    topPath.close();

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        _getBiomeColor(fromBiome).withOpacity(0.4),
        _getBiomeColor(fromBiome).withOpacity(0.1),
        Colors.white.withOpacity(0.1),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));

    canvas.drawPath(topPath, paint);

    // 하단 영역 (새 바이옴)
    final bottomPath = Path();
    bottomPath.addPath(tearPath, Offset.zero);
    bottomPath.lineTo(size.width, size.height);
    bottomPath.lineTo(0, size.height);
    bottomPath.close();

    paint.shader = LinearGradient(
      begin: Alignment.center,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.1),
        _getBiomeColor(toBiome).withOpacity(0.1),
        _getBiomeColor(toBiome).withOpacity(0.4),
      ],
    ).createShader(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));

    canvas.drawPath(bottomPath, paint);

    // 테어 라인에 글로우 효과
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(tearPath, glowPaint);
  }

  void _drawCrystalEffects(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.6);

    // 왼쪽 크리스털
    _drawCrystal(canvas, const Offset(20, 0), size.height * 0.5, paint);

    // 오른쪽 크리스털
    _drawCrystal(canvas, Offset(size.width - 30, 0), size.height * 0.5, paint);

    // 중앙 작은 크리스털들
    for (int i = 0; i < 3; i++) {
      final x = size.width * 0.3 + (i * size.width * 0.2);
      _drawSmallCrystal(canvas, Offset(x, size.height * 0.5), paint);
    }
  }

  void _drawCrystal(Canvas canvas, Offset center, double centerY, Paint paint) {
    final crystalPath = Path();
    final size = 12.0;

    // 다이아몬드 형태
    crystalPath.moveTo(center.dx, centerY - size);
    crystalPath.lineTo(center.dx + size * 0.6, centerY);
    crystalPath.lineTo(center.dx, centerY + size);
    crystalPath.lineTo(center.dx - size * 0.6, centerY);
    crystalPath.close();

    canvas.drawPath(crystalPath, paint);

    // 내부 반짝임
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.9);

    final innerPath = Path();
    innerPath.moveTo(center.dx, centerY - size * 0.5);
    innerPath.lineTo(center.dx + size * 0.2, centerY);
    innerPath.lineTo(center.dx, centerY + size * 0.5);
    innerPath.lineTo(center.dx - size * 0.2, centerY);
    innerPath.close();

    canvas.drawPath(innerPath, innerPaint);
  }

  void _drawSmallCrystal(Canvas canvas, Offset center, Paint paint) {
    final size = 6.0;
    final path = Path();

    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.5, center.dy);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.5, center.dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  Color _getBiomeColor(int biomeIndex) {
    switch (biomeIndex % 4) {
      case 0: return Colors.green;
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.grey;
      default: return color;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/*──────────────────── Path Lesson 노드 ────────────────────*/
class _PathLessonNode extends ConsumerWidget {
  final LessonMeta meta;
  final Color themeColor;
  final bool isLeft;
  final int nodeIndex;

  const _PathLessonNode({
    required this.meta,
    required this.themeColor,
    required this.isLeft,
    required this.nodeIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progAsync = ref.watch(progressProvider(meta.id));

    return progAsync.when(
      loading: () => _buildNode(context, ref, LessonStatus.available, 0, false),
      error: (_, __) => _buildNode(context, ref, LessonStatus.available, 0, false),
      data: (p) {
        final done = p['isLessonDone'] == true && p['quizDone'] == true;
        final nextStep = (p['highestStep'] ?? -1) + 1;
        final status = done ? LessonStatus.completed : LessonStatus.available;
        return _buildNode(context, ref, status, nextStep, done);
      },
    );
  }

  Widget _buildNode(BuildContext context, WidgetRef ref, LessonStatus status, int nextStep, bool done) {
    Color nodeColor;
    IconData nodeIcon;
    String statusLabel;
    
    switch (status) {
      case LessonStatus.completed:
        nodeColor = Colors.green;
        nodeIcon = Icons.check_circle;
        statusLabel = 'Completed';
        break;
      case LessonStatus.available:
        nodeColor = themeColor;
        nodeIcon = nextStep > 0 ? Icons.play_circle : Icons.play_arrow;
        statusLabel = nextStep > 0 ? 'Continue' : 'Start';
        break;
      case LessonStatus.locked:
        nodeColor = Colors.grey;
        nodeIcon = Icons.lock;
        statusLabel = 'Locked';
        break;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonDetailScreen(
              lessonId: int.parse(meta.id),
              lessonTitle: meta.title,
              initialStep: done ? 0 : nextStep
            )
          )
        );
        if (context.mounted) {
          ref.invalidate(progressProvider(meta.id));
          ref.invalidate(lessonsProvider);
        }
      },
      child: Container(
        width: 140,
        child: Column(
          children: [
            // Game-style node with 3D effect
            Container(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bottom shadow layer for 3D effect
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getShadowColor(status, nodeColor),
                      ),
                    ),
                  ),
                  // Main button layer
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _getGradient(status, nodeColor),
                        border: Border.all(
                          color: _getBorderColor(status, nodeColor),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: nodeColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          nodeIcon,
                          color: status == LessonStatus.completed ? Colors.white : 
                                 status == LessonStatus.locked ? Colors.grey[600] : Colors.white,
                          size: 36,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Shine effect for available lessons
                  if (status == LessonStatus.available)
                    Positioned(
                      top: 8,
                      left: 20,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Lesson title with game font style
            Text(
              meta.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.brown[800],
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Game-style status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    nodeColor.withOpacity(0.8),
                    nodeColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: nodeColor.withOpacity(0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: nodeColor.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for game-style effects
  Color _getShadowColor(LessonStatus status, Color nodeColor) {
    switch (status) {
      case LessonStatus.completed:
        return Colors.green[800] ?? Colors.green;
      case LessonStatus.available:
        return nodeColor.withOpacity(0.6);
      case LessonStatus.locked:
        return Colors.grey[600] ?? Colors.grey;
    }
  }

  LinearGradient _getGradient(LessonStatus status, Color nodeColor) {
    switch (status) {
      case LessonStatus.completed:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[400] ?? Colors.green.shade400,
            Colors.green[600] ?? Colors.green.shade600,
          ],
        );
      case LessonStatus.available:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            nodeColor.withOpacity(0.9),
            nodeColor,
          ],
        );
      case LessonStatus.locked:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300] ?? Colors.grey.shade300,
            Colors.grey[500] ?? Colors.grey.shade500,
          ],
        );
    }
  }

  Color _getBorderColor(LessonStatus status, Color nodeColor) {
    switch (status) {
      case LessonStatus.completed:
        return Colors.green[700] ?? Colors.green.shade700;
      case LessonStatus.available:
        return nodeColor.withOpacity(0.8);
      case LessonStatus.locked:
        return Colors.grey[400] ?? Colors.grey.shade400;
    }
  }
}

