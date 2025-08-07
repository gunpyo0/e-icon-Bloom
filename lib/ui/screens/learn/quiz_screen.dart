import 'package:bloom/data/models/quiz.dart';
import 'package:bloom/data/services/backend_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final bool isReviewMode; // 복습 모드 플래그 추가

  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.isReviewMode = false, // 기본값은 false
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<Quiz> quizzes = [];
  int currentQuizIndex = 0;
  int? selectedAnswer;
  bool isLoading = true;
  bool showResult = false;
  bool isAnswered = false;
  List<Map<String, dynamic>> quizResults = [];
  bool isLessonCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    try {
      // 복습 모드가 아닌 경우에만 완료 상태 확인
      if (!widget.isReviewMode) {
        final completed = await EcoBackend.instance
            .isLessonCompleted(widget.lessonId);
        if (completed) {
          setState(() {
            isLessonCompleted = true;
            isLoading = false;
          });
          return;
        }
      }

      final quizList = await EcoBackend.instance
          .getLessonQuizzesFromServer(widget.lessonId.toString());

      setState(() {
        quizzes = quizList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load quiz: $e');
    }
  }

  Future<void> _submitAnswer() async {
    if (selectedAnswer == null) return;

    setState(() {
      isAnswered = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (widget.isReviewMode) {
        // 복습 모드에서는 서버 통신 없이 답변만 표시
        final currentQuiz = quizzes[currentQuizIndex];
        final isCorrect = selectedAnswer == currentQuiz.correctAnswerIndex;
        
        result = {
          'isCorrect': isCorrect,
          'awarded': 0, // 복습 모드에서는 포인트 지급 안함
          'alreadyAnswered': false,
        };
      } else {
        // 일반 모드에서는 서버 통신
        result = await EcoBackend.instance.answerQuiz(
          lessonId : widget.lessonId,
          quizId   : quizzes[currentQuizIndex].id,
          answerIdx: selectedAnswer!,
        );
      }

      quizResults.add({
        'quizId'           : quizzes[currentQuizIndex].id,
        'selectedAnswerIndex': selectedAnswer!,
        'isCorrect'        : result['isCorrect'],
        'pointsEarned'     : result['awarded'],
      });

      if (result['awarded'] is int && result['awarded'] > 0) {
        await ref.refresh(userPointsProvider.future);
      }

      setState(() {
        showResult = true;
      });

    } catch (e) {
      _showErrorDialog('Failed to submit answer: $e');
      setState(() {
        isAnswered = false;
      });
    }
  }

  void _nextQuiz() {
    if (currentQuizIndex < quizzes.length - 1) {
      setState(() {
        currentQuizIndex++;
        selectedAnswer = null;
        showResult = false;
        isAnswered = false;
      });
    } else {
      _completeLesson();
    }
  }

  Future<void> _completeLesson() async {
    try {
      await EcoBackend.instance.completeLessonWithQuizzes(
        lessonId: widget.lessonId,
        quizResults: quizResults,
      );

      // Refresh points
      await ref.refresh(userPointsProvider.future);

      if (mounted) {
        _showCompletionDialog();
      }
    } catch (e) {
      _showErrorDialog('Failed to complete lesson: $e');
    }
  }

  void _showCompletionDialog() {
    final totalPoints = quizResults
        .where((result) => result['isCorrect'] == true)
        .fold<int>(0, (sum, result) => sum + (result['pointsEarned'] as int? ?? 0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              widget.isReviewMode ? Icons.refresh : Icons.celebration, 
              color: widget.isReviewMode ? Colors.blue : Colors.green, 
              size: 48
            ),
            SizedBox(height: 8),
            Text(
              widget.isReviewMode ? '복습 완료!' : 'Lesson Completed!', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isReviewMode 
                ? '${widget.lessonTitle} 복습을 완료했습니다!'
                : 'You have completed ${widget.lessonTitle}!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            if (!widget.isReviewMode) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Total ${totalPoints}P Earned!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close quiz screen
            },
            style: TextButton.styleFrom(
              backgroundColor: widget.isReviewMode ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(widget.isReviewMode ? '완료' : 'Complete'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isReviewMode ? '${widget.lessonTitle} (복습)' : widget.lessonTitle,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.isReviewMode)
              Text(
                '이미 완료된 퀴즈입니다',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.isReviewMode)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '복습',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (isLessonCompleted) {
      return _buildCompletedScreen();
    }

    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No quiz available for this lesson.',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return _buildQuizScreen();
  }

  Widget _buildCompletedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green),
          SizedBox(height: 24),
          Text(
            'This lesson has already been completed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'You cannot earn additional points from completed lessons.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text('Go Back', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    final quiz = quizzes[currentQuizIndex];
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Question ${currentQuizIndex + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  quiz.question,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (showResult) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: quizResults.last['isCorrect'] 
                        ? Colors.green.shade50 
                        : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: quizResults.last['isCorrect'] 
                          ? Colors.green.shade300 
                          : Colors.red.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              quizResults.last['isCorrect'] 
                                ? Icons.check_circle 
                                : Icons.cancel,
                              color: quizResults.last['isCorrect'] 
                                ? Colors.green 
                                : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              quizResults.last['isCorrect'] 
                                ? 'Correct! (+${quizResults.last['pointsEarned']}P)' 
                                : 'Incorrect.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: quizResults.last['isCorrect'] 
                                  ? Colors.green 
                                  : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          quiz.explanation,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 24),

          // Options section
          Expanded(
            child: ListView.builder(
              itemCount: quiz.options.length,
              itemBuilder: (context, index) {
                final option = quiz.options[index];
                final isSelected = selectedAnswer == index;
                final isCorrect = index == quiz.correctAnswerIndex;
                
                Color backgroundColor = Colors.white;
                Color borderColor = Colors.grey.shade300;
                Color textColor = Colors.black87;
                
                if (showResult) {
                  if (isSelected && isCorrect) {
                    backgroundColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    textColor = Colors.green.shade700;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    textColor = Colors.red.shade700;
                  } else if (isCorrect) {
                    backgroundColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    textColor = Colors.green.shade700;
                  }
                } else if (isSelected) {
                  backgroundColor = Colors.green.shade50;
                  borderColor = Colors.green;
                  textColor = Colors.green.shade700;
                }

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isAnswered ? null : () {
                        setState(() {
                          selectedAnswer = index;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? borderColor : Colors.transparent,
                                border: Border.all(color: borderColor, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index), // A, B, C, D
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : borderColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (showResult && isCorrect)
                              Icon(Icons.check, color: Colors.green),
                            if (showResult && isSelected && !isCorrect)
                              Icon(Icons.close, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Button section
          Container(
            width: double.infinity,
            child: showResult
                ? ElevatedButton(
                    onPressed: _nextQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      currentQuizIndex < quizzes.length - 1 ? 'Next Question' : 'Complete Lesson',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  )
                : ElevatedButton(
                    onPressed: selectedAnswer != null && !isAnswered ? _submitAnswer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isAnswered
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Grading...', style: TextStyle(fontSize: 18)),
                            ],
                          )
                        : Text(
                            'Submit Answer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}