    import 'package:bloom/data/models/lesson_models.dart';
import 'package:bloom/providers/points_provider.dart';
import 'package:flutter/material.dart';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:bloom/data/services/eco_backend.dart';
    import 'package:bloom/ui/screens/learn/quiz_screen.dart';

    class LessonDetailScreen extends ConsumerStatefulWidget {
      final int lessonId;
      final String lessonTitle;
      final int initialStep;

      const LessonDetailScreen({
        super.key,
        required this.lessonId,
        required this.lessonTitle,
        this.initialStep = 0,

      });

      @override
      ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
    }

    class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
      int _currentStep = 0;
      bool _isCompleted = false;
      bool _isLoadingSteps  = true;
      late List<LessonStep> _lessonSteps;

      @override
      void initState() {
        super.initState();
        _currentStep = widget.initialStep;   // ⭐️ 기본값 세팅
        _loadSteps();
      }

      Future<void> _loadSteps() async {
        try {
            _lessonSteps = await EcoBackend.instance
                .fetchLessonSteps(widget.lessonId.toString());
          } catch (e) {
            debugPrint('Step load error: $e');
          } finally {
            if (mounted) setState(() => _isLoadingSteps = false);
          }
      }

      @override
      Widget build(BuildContext context) {
        if (_isLoadingSteps) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
        return Scaffold(

          backgroundColor: Colors.green.shade50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.lessonTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentStep + 1}/${_lessonSteps.length}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 진행률 바
              _buildProgressBar(),

              // 학습 내용
              Expanded(
                child: _buildLessonContent(),
              ),

              // 하단 버튼들
              _buildBottomButtons(),
            ],
          ),
        );
      }

      Widget _buildProgressBar() {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Learning Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${((_currentStep + 1) / _lessonSteps.length * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentStep + 1) / _lessonSteps.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 6,
              ),
            ],
          ),
        );
      }

      Widget _buildLessonContent() {
        if (_isCompleted) {
          return _buildCompletionScreen();
        }

        final currentLesson = _lessonSteps[_currentStep];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 단계 제목
              Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            currentLesson.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentLesson.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentLesson.content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 이미지 또는 다이어그램 (있는 경우)
              if (currentLesson.imageUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      currentLesson.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // 핵심 포인트
              if (currentLesson.keyPoints.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Key Points',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...currentLesson.keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8, right: 12),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
            ],
          ),
        );
      }

      Widget _buildCompletionScreen() {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Learning Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have completed the ${widget.lessonTitle} lesson.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '+50 Points Earned!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget _buildBottomButtons() {
        return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),

              if (_currentStep > 0) const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isCompleted ? _completeLesson : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isCompleted
                      ? 'Take Quiz'
                      : _currentStep == _lessonSteps.length - 1
                        ? 'Finish Learning'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      void _nextStep() async {
        final stepInfo = await EcoBackend.instance.nextStep(
          Stepadder(lessonId: widget.lessonId.toString(), step: _currentStep),
        );

        if (!mounted) return;
        if (stepInfo['addPoint'] > 0) {
          // 즉시 포인트 반영
          ref.read(pointsProvider.notifier).refresh();
        }

        if (stepInfo['isLessonDone'] == true) {
          setState(() => _isCompleted = true);
        } else {
          setState(() => _currentStep++);
        }
      }

      void _completeLesson() async {
        // 퀴즈 화면으로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              lessonId: widget.lessonId.toString(),
              lessonTitle: widget.lessonTitle,
            ),
          ),
        );
      }


    }
