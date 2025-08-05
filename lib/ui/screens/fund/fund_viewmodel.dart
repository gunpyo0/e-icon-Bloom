// lib/ui/screens/fund/fund_viewmodel.dart
import 'package:bloom/data/models/fund.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/*──────────────── UI-friendly 모델 ────────────────*/
class FundingProject {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final int daysLeft;
  final String? imageUrl;
  final DateTime createdAt;
  final String creatorUid;
  final String creatorName;

  FundingProject({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.daysLeft,
    this.imageUrl,
    required this.createdAt,
    required this.creatorUid,
    required this.creatorName,
  });

  factory FundingProject.fromCampaign(FundCampaign c) => FundingProject(
    id: c.id,
    title: c.title,
    description: c.description,
    targetAmount: c.goalAmount.toDouble(),
    currentAmount: c.collectedAmount.toDouble(),
    daysLeft: c.endDate.difference(DateTime.now()).inDays,
    imageUrl: null, // 필요 시 Storage URL 로 변환
    createdAt: c.createdAt ?? DateTime.now(),
    creatorUid: c.createdBy,
    creatorName: c.company.name,
  );

  double get progressPercentage =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount * 100).clamp(0, 100);
}

/*──────────────── 필터 / 정렬 enum ────────────────*/
enum FilterType { sort, newFunds, search }
enum SortType {
  progressDesc, progressAsc,
  amountDesc,  amountAsc,
  newest, oldest,
  daysLeftAsc, daysLeftDesc,
}

/*──────────────── Providers ────────────────*/
final selectedFilterProvider = StateProvider<FilterType>((_) => FilterType.sort);
final selectedSortProvider   = StateProvider<SortType>((_) => SortType.progressDesc);
final searchQueryProvider    = StateProvider<String>((_) => '');

/*──────────────── ViewModel ────────────────*/
class FundViewModel extends AsyncNotifier<List<FundingProject>> {
  @override
  Future<List<FundingProject>> build() => _fetch();

  Future<List<FundingProject>> _fetch() async {
    try {
      final campaigns = await EcoBackend.instance.listCampaigns();
      debugPrint('🔥 campaigns length = ${campaigns.length}');
      return campaigns.map(FundingProject.fromCampaign).toList();
    } catch (e, st) {
      debugPrint('❌ _fetch error: $e\n$st');
      rethrow;
    }
  }

  /*── 새로고침 ─*/
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /*── 기부 참여 ─*/
  Future<void> donate({
    required String campaignId,
    required int amount,
  }) async {
    await EcoBackend.instance.donate(campaignId: campaignId, amount: amount);
    await refresh();
  }

  /*── 필터링 ─*/
  List<FundingProject> getFilteredProjects(FilterType filter, String q) {
    var list = state.value ?? [];

    /* 검색어 */
    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      list = list.where((p) =>
      p.title.toLowerCase().contains(lower) ||
          p.description.toLowerCase().contains(lower)).toList();
    }

    /* 기본 정렬 */
    switch (filter) {
      case FilterType.sort:
        list.sort((a,b) => b.progressPercentage.compareTo(a.progressPercentage));
        break;
      case FilterType.newFunds:
        list.sort((a,b) => b.createdAt.compareTo(a.createdAt));
        break;
      case FilterType.search:
        list.sort((a,b) => a.title.compareTo(b.title));
        break;
    }
    return list;
  }

  /*── 커스텀 정렬 ─*/
  List<FundingProject> getSortedProjects(SortType sort, String q) {
    var list = state.value ?? [];

    /* 검색어 */
    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      list = list.where((p) =>
      p.title.toLowerCase().contains(lower) ||
          p.description.toLowerCase().contains(lower)).toList();
    }

    switch (sort) {
      case SortType.progressDesc:  list.sort((a,b)=>b.progressPercentage.compareTo(a.progressPercentage)); break;
      case SortType.progressAsc:   list.sort((a,b)=>a.progressPercentage.compareTo(b.progressPercentage)); break;
      case SortType.amountDesc:    list.sort((a,b)=>b.currentAmount.compareTo(a.currentAmount));           break;
      case SortType.amountAsc:     list.sort((a,b)=>a.currentAmount.compareTo(b.currentAmount));           break;
      case SortType.newest:        list.sort((a,b)=>b.createdAt.compareTo(a.createdAt));                   break;
      case SortType.oldest:        list.sort((a,b)=>a.createdAt.compareTo(b.createdAt));                   break;
      case SortType.daysLeftAsc:   list.sort((a,b)=>a.daysLeft.compareTo(b.daysLeft));                     break;
      case SortType.daysLeftDesc:  list.sort((a,b)=>b.daysLeft.compareTo(a.daysLeft));                     break;
    }
    return list;
  }
}

/*──────────────── Provider 연결 ────────────────*/
final fundViewModelProvider =
AsyncNotifierProvider<FundViewModel, List<FundingProject>>(
      () => FundViewModel(),
);

final filteredFundingProjectsProvider = Provider<List<FundingProject>>((ref) {
  final vm  = ref.watch(fundViewModelProvider);
  final ft  = ref.watch(selectedFilterProvider);
  final q   = ref.watch(searchQueryProvider);

  return vm.when(
    data: (list) => ref.read(fundViewModelProvider.notifier)
        .getFilteredProjects(ft, q),
    loading: () => [],
    error: (_, __) => [],
  );
});

final sortedFundingProjectsProvider = Provider<List<FundingProject>>((ref) {
  final vm  = ref.watch(fundViewModelProvider);
  final st  = ref.watch(selectedSortProvider);
  final q   = ref.watch(searchQueryProvider);

  return vm.when(
    data: (list) => ref.read(fundViewModelProvider.notifier)
        .getSortedProjects(st, q),
    loading: () => [],
    error: (_, __) => [],
  );
});

final fundingProjectDetailProvider =
FutureProvider.family<FundingProject?, String>((ref, id) async {
  final list = await ref.watch(fundViewModelProvider.future);
  return list.firstWhere((p) => p.id == id);
});
