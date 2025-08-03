class Quiz {
  final int id;
  final String question;
  final List<QuizOption> options;
  final int correctAnswerIndex;
  final String explanation;
  final int points;

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.points = 10,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((option) => QuizOption.fromJson(option))
          .toList() ?? [],
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
      points: json['points'] ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((option) => option.toJson()).toList(),
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'points': points,
    };
  }
}

class QuizOption {
  final String text;
  final bool isCorrect;

  QuizOption({
    required this.text,
    required this.isCorrect,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      text: json['text'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCorrect': isCorrect,
    };
  }
}

class QuizResult {
  final int quizId;
  final int selectedAnswerIndex;
  final bool isCorrect;
  final int pointsEarned;
  final DateTime completedAt;

  QuizResult({
    required this.quizId,
    required this.selectedAnswerIndex,
    required this.isCorrect,
    required this.pointsEarned,
    required this.completedAt,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      quizId: json['quizId'] ?? 0,
      selectedAnswerIndex: json['selectedAnswerIndex'] ?? 0,
      isCorrect: json['isCorrect'] ?? false,
      pointsEarned: json['pointsEarned'] ?? 0,
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        json['completedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'selectedAnswerIndex': selectedAnswerIndex,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'completedAt': completedAt.millisecondsSinceEpoch,
    };
  }
}

// Lesson completion status management
class LessonCompletion {
  final int lessonId;
  final bool isCompleted;
  final int totalPoints;
  final List<QuizResult> quizResults;
  final DateTime? completedAt;

  LessonCompletion({
    required this.lessonId,
    required this.isCompleted,
    required this.totalPoints,
    required this.quizResults,
    this.completedAt,
  });

  factory LessonCompletion.fromJson(Map<String, dynamic> json) {
    return LessonCompletion(
      lessonId: json['lessonId'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      totalPoints: json['totalPoints'] ?? 0,
      quizResults: (json['quizResults'] as List<dynamic>?)
          ?.map((result) => QuizResult.fromJson(result))
          .toList() ?? [],
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'isCompleted': isCompleted,
      'totalPoints': totalPoints,
      'quizResults': quizResults.map((result) => result.toJson()).toList(),
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }
}