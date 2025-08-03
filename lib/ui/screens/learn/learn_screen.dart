import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'lesson_detail_screen.dart';

enum LessonStatus { locked, available, completed }

class Lesson {
  final int id;
  final String title;
  final String subtitle;
  final LessonStatus status;
  final int progress; // 0-100
  final String theme;
  final IconData icon;
  
  Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.theme,
    required this.icon,
    this.progress = 0,
  });
}

class LessonTheme {
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final List<Lesson> lessons;
  
  LessonTheme({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.lessons,
  });
}

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  Map<int, bool> completedLessons = {};

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
  }

  Future<void> _loadCompletionStatus() async {
    try {
      // Check completion status for each lesson
      for (int lessonId = 1; lessonId <= 6; lessonId++) {
        final isCompleted = await EcoBackend.instance.isLessonCompleted(lessonId);
        if (mounted) {
          setState(() {
            completedLessons[lessonId] = isCompleted;
          });
        }
      }
    } catch (e) {
      print('Error loading completion status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = _generateThemes();
    
    return Container(
      color: Colors.green[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            ...themes.map((theme) => _buildThemeSection(context, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'SDGs 13: Climate Action',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Learn knowledge and practical methods to respond to climate change',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, LessonTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    theme.icon,
                    color: theme.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lesson buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: theme.lessons.asMap().entries.map((entry) {
                final index = entry.key;
                final lesson = entry.value;
                final isLast = index == theme.lessons.length - 1;
                
                return Column(
                  children: [
                    _buildLessonTile(context, lesson, theme.color),
                    if (!isLast)
                      Divider(height: 1, color: Colors.grey[200]),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTile(BuildContext context, Lesson lesson, Color themeColor) {
    // Check actual completion status
    final isCompleted = completedLessons[lesson.id] ?? false;
    final actualStatus = isCompleted ? LessonStatus.completed : lesson.status;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (actualStatus) {
      case LessonStatus.locked:
        statusColor = Colors.grey[400]!;
        statusIcon = Icons.lock;
        statusText = 'Locked';
        break;
      case LessonStatus.available:
        statusColor = themeColor;
        statusIcon = Icons.play_circle;
        statusText = 'Learn';
        break;
      case LessonStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed (No Points)';
        break;
    }
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          lesson.icon,
          color: statusColor,
          size: 24,
        ),
      ),
      title: Text(
        lesson.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        lesson.subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcon,
              size: 16,
              color: statusColor,
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
      onTap: lesson.status != LessonStatus.locked 
        ? () => _onLessonTap(context, lesson, isCompleted)
        : null,
      enabled: lesson.status != LessonStatus.locked,
    );
  }

  List<LessonTheme> _generateThemes() {
    return [
      LessonTheme(
        title: 'Understanding Climate Change',
        description: 'Learn the scientific principles and impacts of climate change',
        color: Colors.blue,
        icon: Icons.science,
        lessons: [
          Lesson(
            id: 1,
            title: 'Climate Change Science',
            subtitle: 'Understand the causes and mechanisms of climate change',
            status: LessonStatus.available,
            theme: 'Understanding Climate Change',
            icon: Icons.science,
          ),
          Lesson(
            id: 2,
            title: 'Greenhouse Gas Effects',
            subtitle: 'Learn how greenhouse gases affect global warming',
            status: LessonStatus.available,
            theme: 'Understanding Climate Change',
            icon: Icons.cloud,
          ),
          Lesson(
            id: 3,
            title: 'Climate Impact Analysis',
            subtitle: 'Analyze the various impacts of climate change on the environment and society',
            status: LessonStatus.locked,
            theme: 'Understanding Climate Change',
            icon: Icons.analytics,
          ),
        ],
      ),
      LessonTheme(
        title: 'Climate Action Practice',
        description: 'Learn climate action methods that can be practiced in daily life',
        color: Colors.green,
        icon: Icons.eco,
        lessons: [
          Lesson(
            id: 4,
            title: 'Energy Conservation',
            subtitle: 'Practice various methods to save energy at home',
            status: LessonStatus.locked,
            theme: 'Climate Action Practice',
            icon: Icons.energy_savings_leaf,
          ),
          Lesson(
            id: 5,
            title: 'Sustainable Transportation',
            subtitle: 'Create eco-friendly transportation and smart travel plans',
            status: LessonStatus.locked,
            theme: 'Climate Action Practice',
            icon: Icons.directions_bike,
          ),
          Lesson(
            id: 6,
            title: 'Personal Carbon Footprint Management',
            subtitle: 'Learn how to measure and reduce your carbon footprint',
            status: LessonStatus.locked,
            theme: 'Climate Action Practice',
            icon: Icons.eco_outlined,
          ),
        ],
      ),
    ];
  }

  void _onLessonTap(BuildContext context, Lesson lesson, bool isCompleted) async {
    if (isCompleted) {
      // Show notification for completed lessons
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('Already Completed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You have already completed this lesson.'),
              SizedBox(height: 8),
              Text(
                'Retaking completed lessons will not earn additional points.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLesson(context, lesson);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Retake'),
            ),
          ],
        ),
      );
    } else {
      _navigateToLesson(context, lesson);
    }
  }

  void _navigateToLesson(BuildContext context, Lesson lesson) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(
          lessonId: lesson.id,
          lessonTitle: lesson.title,
        ),
      ),
    );
    
    // Update status when learning is completed (reload completion status)
    _loadCompletionStatus();
  }
}

class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw wave pattern
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
    
    // Bottom surface (shadow effect) - circular at bottom
    final bottomRect = Rect.fromCenter(
      center: Offset(centerX, centerY + depth),
      width: radius * 2,
      height: radius * 2,
    );
    
    paint.color = sideColor.withOpacity(0.6);
    canvas.drawOval(bottomRect, paint);
    
    // Top surface (main circular)
    final topRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: radius * 2,
      height: radius * 2,
    );
    
    paint.color = topColor;
    canvas.drawOval(topRect, paint);
    
    // Border
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = borderColor;
    canvas.drawOval(topRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}