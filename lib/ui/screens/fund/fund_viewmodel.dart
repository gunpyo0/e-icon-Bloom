// lib/ui/screens/fund/fund_viewmodel.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/eco_backend.dart';

// 펀딩 프로젝트 모델
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

  factory FundingProject.fromMap(Map<String, dynamic> data, String id) {
    return FundingProject(
      id: id,
      title: data['title'] ?? 'No title',
      description: data['description'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0).toDouble(),
      daysLeft: data['daysLeft'] ?? 0,
      imageUrl: data['imageUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? 'Anonymous',
    );
  }

  double get progressPercentage => 
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;
}

// 필터 타입
enum FilterType {
  sort,
  newFunds,
  search,
}

// 정렬 타입
enum SortType {
  progressDesc, // 진행률 높은순
  progressAsc,  // 진행률 낮은순
  amountDesc,   // 모금액 높은순
  amountAsc,    // 모금액 낮은순
  newest,       // 최신순
  oldest,       // 오래된순
  daysLeftAsc,  // 마감 임박순
  daysLeftDesc, // 마감 여유순
}

// 선택된 필터 Provider
final selectedFilterProvider = StateProvider<FilterType>((ref) => FilterType.sort);

// 선택된 정렬 Provider
final selectedSortProvider = StateProvider<SortType>((ref) => SortType.progressDesc);

// 검색어 Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// 펀딩 프로젝트 목록 ViewModel
class FundViewModel extends AsyncNotifier<List<FundingProject>> {
  @override
  Future<List<FundingProject>> build() async {
    return await _loadFundingProjects();
  }

  Future<List<FundingProject>> _loadFundingProjects() async {
    try {
      // 임시 데이터 (실제로는 EcoBackend를 통해 가져와야 함)
      // Firebase Functions에 getFundingProjects 함수가 있다고 가정
      
      // final result = await EcoBackend.instance
      //     .getFundingProjects(); // 이 함수는 실제 구현 필요
      
      // 임시 더미 데이터
      await Future.delayed(const Duration(seconds: 1)); // 로딩 시뮬레이션
      
      return [
        FundingProject(
          id: '1',
          title: 'Fund 1',
          description: 'First funding project for environmental protection.',
          targetAmount: 1000000,
          currentAmount: 750000,
          daysLeft: 15,
          imageUrl: null,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          creatorUid: 'user1',
          creatorName: 'Environmental Guardian',
        ),
        FundingProject(
          id: '2',
          title: 'Fund 2',
          description: 'Funding for recycling project.',
          targetAmount: 500000,
          currentAmount: 300000,
          daysLeft: 8,
          imageUrl: null,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          creatorUid: 'user2',
          creatorName: 'Recycling King',
        ),
        FundingProject(
          id: '3',
          title: 'Fund 3',
          description: 'Project for eco-friendly product development.',
          targetAmount: 2000000,
          currentAmount: 1200000,
          daysLeft: 25,
          imageUrl: null,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          creatorUid: 'user3',
          creatorName: 'GreenTech',
        ),
      ];
    } catch (e) {
      throw Exception('Failed to load funding projects: $e');
    }
  }

  // 펀딩 프로젝트 생성
  Future<void> createFundingProject({
    required String title,
    required String description,
    required double targetAmount,
    required int durationDays,
    String? imageUrl,
  }) async {
    try {
      // 실제 구현시 Firebase Functions 호출
      // await EcoBackend.instance.createFundingProject({
      //   'title': title,
      //   'description': description,
      //   'targetAmount': targetAmount,
      //   'durationDays': durationDays,
      //   'imageUrl': imageUrl,
      // });
      
      // 성공 후 목록 새로고침
      await refresh();
    } catch (e) {
      throw Exception('Failed to create funding project: $e');
    }
  }

  // 펀딩 참여
  Future<void> fundProject(String projectId, double amount) async {
    try {
      // 실제 구현시 Firebase Functions 호출
      // await EcoBackend.instance.fundProject({
      //   'projectId': projectId,
      //   'amount': amount,
      // });
      
      // 성공 후 목록 새로고침
      await refresh();
    } catch (e) {
      throw Exception('Failed to participate in funding: $e');
    }
  }

  // 새로고침
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadFundingProjects());
  }

  // 필터링된 프로젝트 목록
  List<FundingProject> getFilteredProjects(FilterType filter, String searchQuery) {
    final projects = state.value ?? [];
    
    List<FundingProject> filtered = projects;
    
    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((project) =>
          project.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          project.description.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    
    // 정렬
    switch (filter) {
      case FilterType.sort:
        // 진행률 순으로 정렬
        filtered.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
        break;
      case FilterType.newFunds:
        // 생성일 순으로 정렬
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case FilterType.search:
        // 검색 관련성 순 (여기서는 단순히 이름순)
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    
    return filtered;
  }

  // 정렬된 프로젝트 목록
  List<FundingProject> getSortedProjects(SortType sortType, String searchQuery) {
    final projects = state.value ?? [];
    
    List<FundingProject> filtered = projects;
    
    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((project) =>
          project.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          project.description.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    
    // 정렬
    switch (sortType) {
      case SortType.progressDesc:
        // 진행률 높은순
        filtered.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
        break;
      case SortType.progressAsc:
        // 진행률 낮은순
        filtered.sort((a, b) => a.progressPercentage.compareTo(b.progressPercentage));
        break;
      case SortType.amountDesc:
        // 모금액 높은순
        filtered.sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
        break;
      case SortType.amountAsc:
        // 모금액 낮은순
        filtered.sort((a, b) => a.currentAmount.compareTo(b.currentAmount));
        break;
      case SortType.newest:
        // 최신순
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortType.oldest:
        // 오래된순
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortType.daysLeftAsc:
        // 마감 임박순
        filtered.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
        break;
      case SortType.daysLeftDesc:
        // 마감 여유순
        filtered.sort((a, b) => b.daysLeft.compareTo(a.daysLeft));
        break;
    }
    
    return filtered;
  }
}

// Provider
final fundViewModelProvider = AsyncNotifierProvider<FundViewModel, List<FundingProject>>(
  () => FundViewModel(),
);

// 필터링된 펀딩 프로젝트 목록 Provider (기존 방식)
final filteredFundingProjectsProvider = Provider<List<FundingProject>>((ref) {
  final projects = ref.watch(fundViewModelProvider);
  final filter = ref.watch(selectedFilterProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  
  return projects.when(
    data: (data) => ref.read(fundViewModelProvider.notifier)
        .getFilteredProjects(filter, searchQuery),
    loading: () => [],
    error: (_, __) => [],
  );
});

// 정렬된 펀딩 프로젝트 목록 Provider (새로운 방식)
final sortedFundingProjectsProvider = Provider<List<FundingProject>>((ref) {
  final projects = ref.watch(fundViewModelProvider);
  final sortType = ref.watch(selectedSortProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  
  return projects.when(
    data: (data) => ref.read(fundViewModelProvider.notifier)
        .getSortedProjects(sortType, searchQuery),
    loading: () => [],
    error: (_, __) => [],
  );
});

// 특정 펀딩 프로젝트 상세 정보 Provider
final fundingProjectDetailProvider = FutureProvider.family<FundingProject?, String>((ref, projectId) async {
  final projects = await ref.watch(fundViewModelProvider.future);
  try {
    return projects.firstWhere((project) => project.id == projectId);
  } catch (e) {
    return null;
  }
});