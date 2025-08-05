import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/data/models/lesson_models.dart';
import 'lesson_detail_screen.dart';

enum LessonStatus { locked, available, completed }

/// ───────── Provider – 레슨 목록 ─────────
final lessonsProvider = FutureProvider<List<LessonMeta>>((ref) async {
  return EcoBackend.instance.listLessons();
});

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLessons = ref.watch(lessonsProvider);

    return asyncLessons.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error  : (e, st) => Center(child: Text('Error: $e')),
      data   : (lessons) => _buildBody(context, lessons),
    );
  }

  Widget _buildBody(BuildContext ctx, List<LessonMeta> lessons) {
    /// themeId → LessonMeta 리스트로 그룹화
    final Map<String, List<LessonMeta>> grouped = {};
    for (final l in lessons) {
      grouped.putIfAbsent(l.themeId, () => []).add(l);
    }

    return Container(
      color: Colors.green[50],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: grouped.entries.map((e) {
          final first = e.value.first;
          return _ThemeSection(metaList: e.value, color: first.themeColor);
        }).toList(),
      ),
    );
  }
}

/// ───────── Theme 섹션 위젯 ─────────
class _ThemeSection extends ConsumerWidget {
  final List<LessonMeta> metaList;
  final Color color;

  const _ThemeSection({required this.metaList, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeTitle = metaList.first.themeTitle;
    final themeDesc  = metaList.first.themeDesc;
    final themeIcon  = metaList.first.themeIcon;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(top: true),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(themeIcon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(themeTitle,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(themeDesc,
                          style:
                          TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // lesson list
          Container(
            decoration: _cardDeco(),
            child: Column(
              children: metaList.map((m) {
                final idx = metaList.indexOf(m);
                final isLast = idx == metaList.length - 1;
                return Column(
                  children: [
                    _LessonTile(meta: m, themeColor: color),
                    if (!isLast) Divider(height: 1, color: Colors.grey[200]),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco({bool top = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: top
          ? const BorderRadius.only(
          topLeft: Radius.circular(12), topRight: Radius.circular(12))
          : const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

/// ───────── Lesson 타일 ─────────
class _LessonTile extends ConsumerWidget {
  final LessonMeta meta;
  final Color themeColor;

  const _LessonTile({required this.meta, required this.themeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 완료 여부 실시간 확인
    final completedAsync =
    ref.watch(_completedProvider(meta.id)); // provider below

    return completedAsync.when(
      loading: () => _tile(context, LessonStatus.available, false),
      error  : (_, __) => _tile(context, LessonStatus.available, false),
      data   : (done)  =>
          _tile(context, done ? LessonStatus.completed : LessonStatus.available,
              done),
    );
  }

  Widget _tile(BuildContext ctx, LessonStatus status, bool done) {
    Color c; IconData icon; String label;
    switch (status) {
      case LessonStatus.available:
        c = themeColor; icon = Icons.play_circle; label = 'Learn';
        break;
      case LessonStatus.completed:
        c = Colors.green; icon = Icons.check_circle; label = 'Completed';
        break;
      case LessonStatus.locked:
        c = Colors.grey; icon = Icons.lock; label = 'Locked';
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: c.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(meta.themeIcon, color: c, size: 24),
      ),
      title: Text(meta.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      subtitle: Text('Step ${meta.totalSteps}  |  Quiz 3',
          style: TextStyle(color: Colors.grey[600])),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: c.withOpacity(.1), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: c)),
        ]),
      ),
      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          lessonId: int.parse(meta.id),
          lessonTitle: meta.title,
        ),
      )),
    );
  }
}

/// ─── per-lesson completed cache (FutureProvider.family) ───
final _completedProvider =
FutureProvider.family<bool, String>((ref, lessonId) async {
  return EcoBackend.instance.isLessonCompleted(lessonId);
});
