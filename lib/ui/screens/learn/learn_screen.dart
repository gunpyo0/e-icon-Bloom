import 'package:flutter/material.dart';

enum LessonStatus { locked, available, completed }

class Lesson {
  final int id;
  final String title;
  final LessonStatus status;
  final int progress; // 0-100
  
  Lesson({
    required this.id,
    required this.title,
    required this.status,
    this.progress = 0,
  });
}

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lessons = _generateLessons();
    
    return Container(
      color: Colors.green[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildLessonPath(context, lessons),
      ),
    );
  }


  Widget _buildLessonPath(BuildContext context, List<Lesson> lessons) {
    return Stack(
      children: [
        // 배경 패턴 (물결 무늬)
        Positioned.fill(
          child: CustomPaint(
            painter: WavePatternPainter(),
          ),
        ),
        // 레슨들
        Column(
          children: [
            for (int i = 0; i < lessons.length; i++)
              _buildLessonNode(context, lessons[i], i),
          ],
        ),
      ],
    );
  }

  Widget _buildLessonNode(BuildContext context, Lesson lesson, int index) {
    // 이미지와 같은 위치 패턴: 중앙, 좌측, 우측 번갈아가며
    late Alignment alignment;
    late EdgeInsets margin;
    
    switch (index % 3) {
      case 0:
        alignment = Alignment.center;
        margin = const EdgeInsets.symmetric(vertical: 30);
        break;
      case 1:
        alignment = Alignment.centerLeft;
        margin = const EdgeInsets.only(left: 60, top: 20, bottom: 20);
        break;
      case 2:
        alignment = Alignment.centerRight;
        margin = const EdgeInsets.only(right: 60, top: 20, bottom: 20);
        break;
    }
    
    return Container(
      width: double.infinity,
      margin: margin,
      child: Align(
        alignment: alignment,
        child: _buildLessonCircle(context, lesson),
      ),
    );
  }

  Widget _buildLessonCircle(BuildContext context, Lesson lesson) {
    Color circleColor;
    Color iconColor;
    
    switch (lesson.status) {
      case LessonStatus.locked:
        circleColor = Colors.grey[300]!;
        iconColor = Colors.grey[600]!;
        break;
      case LessonStatus.available:
        circleColor = Colors.green[400]!;
        iconColor = Colors.white;
        break;
      case LessonStatus.completed:
        circleColor = Colors.orange[400]!;
        iconColor = Colors.white;
        break;
    }
    
    return GestureDetector(
      onTap: lesson.status != LessonStatus.locked 
        ? () => _onLessonTap(context, lesson)
        : null,
      child: Container(
        width: 80,
        height: 80,
        child: CustomPaint(
          painter: IsometricButtonPainter(
            topColor: circleColor,
            sideColor: circleColor.withOpacity(0.7),
            borderColor: Colors.white,
          ),
          child: Center(
            child: Text(
              '${lesson.id}',
              style: TextStyle(
                color: iconColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }


  List<Lesson> _generateLessons() {
    return [
      Lesson(id: 1, title: "Plant", status: LessonStatus.completed),
      Lesson(id: 2, title: "Watering", status: LessonStatus.completed),
      Lesson(id: 3, title: "Sunlight", status: LessonStatus.available, progress: 60),
      Lesson(id: 4, title: "Soil", status: LessonStatus.available),
      Lesson(id: 5, title: "Growth", status: LessonStatus.locked),
      Lesson(id: 6, title: "Harvest", status: LessonStatus.locked),
      Lesson(id: 7, title: "Seeds", status: LessonStatus.locked),
    ];
  }

  void _onLessonTap(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lesson ${lesson.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lesson.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting ${lesson.title} lesson!')),
              );
            },
            child: Text(lesson.status == LessonStatus.completed ? 'Review' : 'Start'),
          ),
        ],
      ),
    );
  }
}

class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 물결 무늬 그리기
    for (int i = 0; i < 10; i++) {
      final path = Path();
      final y = size.height * 0.7 + (i * 15);
      
      path.moveTo(0, y);
      
      for (double x = 0; x <= size.width; x += 20) {
        path.lineTo(x, y + (i % 2 == 0 ? 5 : -5));
        path.lineTo(x + 10, y);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IsometricButtonPainter extends CustomPainter {
  final Color topColor;
  final Color sideColor;
  final Color borderColor;

  IsometricButtonPainter({
    required this.topColor,
    required this.sideColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final centerY = height / 2;
    final radius = width * 0.35;
    final depth = 8.0;
    
    // 하단면 (그림자 효과) - 아래쪽에 원형
    final bottomRect = Rect.fromCenter(
      center: Offset(centerX, centerY + depth),
      width: radius * 2,
      height: radius * 2,
    );
    
    paint.color = sideColor.withOpacity(0.6);
    canvas.drawOval(bottomRect, paint);
    
    // 상단면 (메인 원형)
    final topRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: radius * 2,
      height: radius * 2,
    );
    
    paint.color = topColor;
    canvas.drawOval(topRect, paint);
    
    // 테두리
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = borderColor;
    canvas.drawOval(topRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}