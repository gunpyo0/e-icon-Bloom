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
      color: Colors.green[50],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: grouped.entries.map((e) => _ThemeSection(metaList: e.value, color: e.value.first.themeColor)).toList(growable: false),
      ),
    );
  }
}

/*──────────────────── Theme 섹션 ────────────────────*/
class _ThemeSection extends ConsumerWidget {
  final List<LessonMeta> metaList; final Color color;
  const _ThemeSection({required this.metaList, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = metaList.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(top: true),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), child: const Text('Learn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(first.themeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(first.themeDesc, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ])),
          ]),
        ),
        // Lesson list
        Container(
          decoration: _cardDeco(),
          child: Column(children: [
            for (var i = 0; i < metaList.length; i++) ...[
              _LessonTile(meta: metaList[i], themeColor: color),
              if (i < metaList.length - 1) Divider(height: 1, color: Colors.grey[200]),
            ],
          ]),
        ),
      ]),
    );
  }

  BoxDecoration _cardDeco({bool top = false}) => BoxDecoration(
    color: Colors.white,
    borderRadius: top
        ? const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
        : const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
  );
}

/*──────────────────── Lesson 타일 ────────────────────*/
class _LessonTile extends ConsumerWidget {
  final LessonMeta meta; final Color themeColor;
  const _LessonTile({required this.meta, required this.themeColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progAsync = ref.watch(progressProvider(meta.id));

    return progAsync.when(
      loading: () => _tile(context, ref, LessonStatus.available, 0, false),
      error: (_, __) => _tile(context, ref, LessonStatus.available, 0, false),
      data: (p) {
        final done = p['isLessonDone'] == true && p['quizDone'] == true;
        final nextStep = (p['highestStep'] ?? -1) + 1;
        final status = done ? LessonStatus.completed : LessonStatus.available;
        return _tile(context, ref, status, nextStep, done);
      },
    );
  }

  Widget _tile(BuildContext ctx, WidgetRef ref, LessonStatus status, int nextStep, bool done) {
    Color c; IconData icon; String label;
    switch (status) {
      case LessonStatus.completed:
        c = Colors.green; icon = Icons.check_circle; label = 'Completed'; break;
      case LessonStatus.available:
        c = themeColor; icon = nextStep > 0 ? Icons.play_circle : Icons.play_arrow; label = nextStep > 0 ? 'Continue • Step $nextStep' : 'Start'; break;
      case LessonStatus.locked:
        c = Colors.grey; icon = Icons.lock; label = 'Locked'; break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: themeColor.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: Icon(meta.themeIcon, color: themeColor, size: 24)),
      title: Text(meta.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      subtitle: Text('Step ${meta.totalSteps}  |  Quiz 3', style: TextStyle(color: Colors.grey[600])),
      trailing: _pill(c, icon, label),
      onTap: () async {
        await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => LessonDetailScreen(lessonId: int.parse(meta.id), lessonTitle: meta.title, initialStep: done ? 0 : nextStep)));
        if (ctx.mounted) {
          // 디테일에서 돌아오면 해당 레슨 진행 + 전체 목록 새로고침
          ref.invalidate(progressProvider(meta.id));
          ref.invalidate(lessonsProvider);
        }
      },
    );
  }

  Widget _pill(Color c, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(16)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
    ]),
  );
}
