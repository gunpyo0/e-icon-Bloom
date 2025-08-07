// lib/ui/screens/fund/fund_viewmodel.dart
import 'package:bloom/data/models/fund.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  factory FundingProject.fromCampaign(FundCampaign c) {
    debugPrint('🖼️ FundingProject.fromCampaign - imageUrl: "${c.imageUrl}", bannerPath: "${c.bannerPath}"');
    
    // imageUrl을 우선 사용, 없으면 bannerPath 사용
    String? finalImageUrl;
    if (c.imageUrl != null && c.imageUrl!.isNotEmpty) {
      finalImageUrl = c.imageUrl;
      debugPrint('✅ Using imageUrl: $finalImageUrl');
    } else if (c.bannerPath.isNotEmpty) {
      finalImageUrl = c.bannerPath;
      debugPrint('⚠️ Fallback to bannerPath: $finalImageUrl');
    } else {
      finalImageUrl = null;
      debugPrint('❌ No image URL available');
    }
    
    return FundingProject(
      id: c.id,
      title: c.title,
      description: c.description,
      targetAmount: c.goalAmount.toDouble(),
      currentAmount: c.collectedAmount.toDouble(),
      daysLeft: c.endDate.difference(DateTime.now()).inDays,
      imageUrl: finalImageUrl,
      createdAt: c.createdAt ?? DateTime.now(),
      creatorUid: c.createdBy,
      creatorName: c.company.name,
    );
  }

  static final Map<String, String> _urlCache = {};
  
  static Future<String?> getImageUrl(String? storagePath) async {
    debugPrint('🔗 getImageUrl called with: "$storagePath"');
    if (storagePath == null || storagePath.isEmpty) {
      debugPrint('❌ storagePath is null or empty');
      return null;
    }
    
    // Check cache first
    if (_urlCache.containsKey(storagePath)) {
      debugPrint('💾 Using cached URL for: $storagePath');
      return _urlCache[storagePath];
    }
    
    try {
      if (storagePath.startsWith('http')) {
        debugPrint('✅ Already a URL: $storagePath');
        _urlCache[storagePath] = storagePath;
        return storagePath;
      }
      
      // Try multiple path patterns
      final possiblePaths = [
        storagePath, // Original path
        'campaigns/$storagePath', // campaigns/ folder
        'banners/$storagePath', // banners/ folder
        'images/$storagePath', // images/ folder
        'fund/$storagePath', // fund/ folder
        'fund-campaigns/$storagePath', // fund-campaigns/ folder
      ];
      
      for (final path in possiblePaths) {
        try {
          debugPrint('📁 Trying Firebase Storage path: $path');
          final ref = FirebaseStorage.instance.ref(path);
          final downloadUrl = await ref.getDownloadURL();
          debugPrint('✅ Got download URL with path "$path": $downloadUrl');
          
          // Cache the result
          _urlCache[storagePath] = downloadUrl;
          return downloadUrl;
        } catch (e) {
          debugPrint('❌ Path "$path" failed: $e');
          continue;
        }
      }
      
      debugPrint('❌ All paths failed for: $storagePath');
      return null;
    } catch (e) {
      debugPrint('❌ Unexpected error for $storagePath: $e');
      return null;
    }
  }

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
      
      // Convert storage paths to download URLs
      final projects = <FundingProject>[];
      for (final campaign in campaigns) {
        final project = FundingProject.fromCampaign(campaign);
        // Pre-fetch image URL if available
        if (project.imageUrl != null && project.imageUrl!.isNotEmpty) {
          debugPrint('🔄 Processing image for project: ${project.title}');
          final downloadUrl = await FundingProject.getImageUrl(project.imageUrl);
          debugPrint('✅ Resolved URL: $downloadUrl');
          final updatedProject = FundingProject(
            id: project.id,
            title: project.title,
            description: project.description,
            targetAmount: project.targetAmount,
            currentAmount: project.currentAmount,
            daysLeft: project.daysLeft,
            imageUrl: downloadUrl, // Use the resolved URL
            createdAt: project.createdAt,
            creatorUid: project.creatorUid,
            creatorName: project.creatorName,
          );
          projects.add(updatedProject);
        } else {
          debugPrint('⚠️ No image URL for project: ${project.title}');
          projects.add(project);
        }
      }
      
      return projects;
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
final fundLoadingProvider = Provider<bool>((ref) {
  final async = ref.watch(fundViewModelProvider);
  return async.maybeWhen(
    loading: () => true,
    orElse: ()  => false,
  );
});