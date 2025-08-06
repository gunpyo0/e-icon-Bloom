import 'package:flutter/material.dart';

/// ───────── Lesson 메타 한 건 ─────────
class LessonMeta {
  final String id;
  final String title;
  final String themeId;
  final String themeTitle;
  final String themeDesc;
  final Color  themeColor;
  final IconData themeIcon;
  final int  totalSteps;
  final int  lessonPoint;
  final int  quizPointPerHit;

  LessonMeta({
    required this.id,
    required this.title,
    required this.themeId,
    required this.themeTitle,
    required this.themeDesc,
    required this.themeColor,
    required this.themeIcon,
    required this.totalSteps,
    required this.lessonPoint,
    required this.quizPointPerHit,
  });

  factory LessonMeta.fromDoc(String id, Map<String, dynamic> j) {
    return LessonMeta(
      id              : id,
      title           : j['title'] ?? '',
      themeId         : j['themeId'] ?? '',
      themeTitle      : j['themeTitle'] ?? '',
      themeDesc       : j['themeDesc'] ?? '',
      themeColor      : _hexToColor(j['themeColor'] ?? '#2196F3'),
      themeIcon       : IconData(j['themeIcon'] ?? 0xe3af, fontFamily: 'MaterialIcons'),
      totalSteps      : j['totalSteps'] ?? 0,
      lessonPoint     : j['lessonPoint'] ?? 0,
      quizPointPerHit : j['quizPointPerHit'] ?? 0,
    );
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class LessonStep {
  final String title;
  final IconData icon;
  final String content;
  final List<String> keyPoints;
  final String? imageUrl;

  LessonStep({
    required this.title,
    required this.icon,
    required this.content,
    required this.keyPoints,
    this.imageUrl,
  });

  /* Firestore → 객체 */
  factory LessonStep.fromDoc(Map<String, dynamic> doc) => LessonStep(
    title     : doc['title']     ?? '',
    icon      : IconsMap[doc['icon']] ?? Icons.book,
    content   : doc['content']   ?? '',
    keyPoints : List<String>.from(doc['keyPoints'] ?? const []),
    imageUrl  : doc['imageUrl'],
  );
}

/// 간단 아이콘 매핑 (필요한 만큼만 등록)
const Map<String, IconData> IconsMap = {
  'science' : Icons.science,
  'cloud'   : Icons.cloud,
  'chart'   : Icons.analytics,
  'energy'  : Icons.energy_savings_leaf,
};

class Stepadder {
  final String lessonId;
  final int    step;           // 0-based

  Stepadder({required this.lessonId, required this.step});

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'step'    : step,
  };
}