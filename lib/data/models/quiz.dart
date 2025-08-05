// lib/data/models/quiz.dart
import 'package:flutter/material.dart';

class Quiz {
  final String id;
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
    required this.points,
  });
}

class QuizOption {
  final String text;
  final bool isCorrect;   // 서버엔 저장 안 해도 됨 (클라이언트 채점용)

  QuizOption({required this.text, required this.isCorrect});
}

class QuizResult {
  final int quizId;
  final int selectedAnswerIndex;
  final bool isCorrect;
  final int pointsEarned;

  QuizResult({
    required this.quizId,
    required this.selectedAnswerIndex,
    required this.isCorrect,
    required this.pointsEarned,
  });
}
