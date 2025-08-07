// lib/ui/screens/fund/fund_screen.dart
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'fund_viewmodel.dart';
import 'package:bloom/providers/points_provider.dart';
class FundScreen extends ConsumerStatefulWidget {
  const FundScreen({super.key});

  @override
  ConsumerState<FundScreen> createState() => _FundScreenState();
}


class _FundScreenState extends ConsumerState<FundScreen>
    with WidgetsBindingObserver {


  /*── 생명주기 등록 ─*/
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 첫 빌드 직후에 바로 refresh
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ref.read(fundViewModelProvider.notifier).refresh();
    });
  }

  /*── 앱이 다시 포커스될 때(refresh) ─*/
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(fundViewModelProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /*──────────────── UI ─────────────────*/
  @override
  Widget build(BuildContext context) {
    final selectedFilter = ref.watch(selectedFilterProvider);
    final isLoading      = ref.watch(fundLoadingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(                                  // ⬅️ ① Stack으로 감싸기
        children: [
          Column(
            children: [
              _buildFilterButtons(context, ref),
              Expanded(
                child: selectedFilter == FilterType.sort
                    ? _buildSortedFundingList(
                    context, ref.watch(sortedFundingProjectsProvider))
                    : selectedFilter == FilterType.search
                    ? _buildSearchResults(
                  context,
                  ref,
                  ref.watch(filteredFundingProjectsProvider),
                )
                    : _buildFilteredFundingList(
                    context, ref.watch(filteredFundingProjectsProvider)),
              ),
            ],
          ),
          if (isLoading)                            // ⬅️ ② 로딩 오버레이
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.75),
                child: const Center(
                  child: SizedBox(
                    height: 60,
                    width: 60,
                    child: CircularProgressIndicator(strokeWidth: 6),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        onPressed: () => context.push('/fund/create'),
        icon: const Icon(Icons.add),
        label: const Text(
          'New Project',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 8,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }


  Widget _buildPointsHeader(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(pointsProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.green.shade200, width: 1),
        ),
      ),
      child: pointsAsync.when(
        data: (totalPoints) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Points',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${totalPoints} P',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Text(
                  'Fund with your points!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Unable to load point information',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(selectedFilterProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _buildFilterButton(
                context, 
                ref,
                'Sort', 
                Icons.sort,
                selectedFilter == FilterType.sort,
                FilterType.sort,
              ),
              const SizedBox(width: 12),
              _buildFilterButton(
                context, 
                ref,
                'Search', 
                Icons.search,
                selectedFilter == FilterType.search,
                FilterType.search,
              ),
            ],
          ),
          // Show search input field only when Search button is selected
          if (selectedFilter == FilterType.search) ...[
            const SizedBox(height: 12),
            _buildSearchInput(context, ref),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
    bool isSelected,
    FilterType filterType,
  ) {
    if (filterType == FilterType.sort) {
      return _buildSortButton(context, ref, label, icon, isSelected);
    }
    
    return GestureDetector(
      onTap: () => ref.read(selectedFilterProvider.notifier).state = filterType,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    final selectedSort = ref.watch(selectedSortProvider);
    
    return PopupMenuButton<SortType>(
      initialValue: selectedSort,
      onSelected: (SortType value) {
        ref.read(selectedSortProvider.notifier).state = value;
        ref.read(selectedFilterProvider.notifier).state = FilterType.sort;
      },
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
        _buildSortMenuItem(SortType.progressDesc, '📈 Progress: High to Low', Icons.trending_up, selectedSort),
        _buildSortMenuItem(SortType.progressAsc, '📉 Progress: Low to High', Icons.trending_down, selectedSort),
        const PopupMenuDivider(),
        _buildSortMenuItem(SortType.amountDesc, '💰 Amount: High to Low', Icons.attach_money, selectedSort),
        _buildSortMenuItem(SortType.amountAsc, '💸 Amount: Low to High', Icons.money_off, selectedSort),
        const PopupMenuDivider(),
        _buildSortMenuItem(SortType.newest, '🆕 Newest First', Icons.new_releases, selectedSort),
        _buildSortMenuItem(SortType.oldest, '📅 Oldest First', Icons.history, selectedSort),
        const PopupMenuDivider(),
        _buildSortMenuItem(SortType.daysLeftAsc, '⏰ Deadline: Urgent First', Icons.schedule, selectedSort),
        _buildSortMenuItem(SortType.daysLeftDesc, '⏳ Deadline: Flexible First', Icons.hourglass_empty, selectedSort),
      ],
    );
  }

  Widget _buildSearchInput(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          ref.read(searchQueryProvider.notifier).state = value;
        },
        decoration: InputDecoration(
          hintText: 'Search funding projects...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 20,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  PopupMenuItem<SortType> _buildSortMenuItem(
    SortType value,
    String text,
    IconData iconData,
    SortType selectedSort,
  ) {
    final isSelected = value == selectedSort;
    
    return PopupMenuItem<SortType>(
      value: value,
      height: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconData,
                size: 18,
                color: isSelected ? Colors.green : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.green : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortedFundingList(BuildContext context, List<FundingProject> projects) {
    if (projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No projects found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _buildFundingCard(context, project);
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, WidgetRef ref, List<FundingProject> projects) {
    final searchQuery = ref.watch(searchQueryProvider);
    
    if (searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Start typing to search projects',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search by title or description',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No results for "$searchQuery"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search results header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${projects.length} result${projects.length != 1 ? 's' : ''} for "$searchQuery"',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 검색 결과 리스트
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildSearchResultCard(context, project, searchQuery);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredFundingList(BuildContext context, List<FundingProject> projects) {
    if (projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No projects found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _buildFundingCard(context, project);
      },
    );
  }

  Widget _buildSearchResultCard(BuildContext context, FundingProject project, String searchQuery) {
    final progressPercentage = (project.currentAmount / project.targetAmount * 100).clamp(0, 100);
    
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/fund/${project.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade100,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로젝트 이미지 (간소화된 버전)
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  project.imageUrl != null && project.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          project.imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.black,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ Image load error: $error for URL: ${project.imageUrl}');
                            return Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.eco,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                  
                  // 프로젝트 제목 오버레이
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: _buildHighlightedText(
                      project.title,
                      searchQuery,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 프로젝트 정보
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 설명 (검색어 하이라이트)
                  _buildHighlightedText(
                    project.description,
                    searchQuery,
                    const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 진행률 바
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressPercentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 금액 및 기간 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${project.currentAmount.toStringAsFixed(0)} Points',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${project.daysLeft} days left',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String searchQuery, TextStyle baseStyle, {int? maxLines}) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    
    while (index != -1) {
      // 매치 이전 텍스트
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }
      
      // 하이라이트된 매치 텍스트
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow.shade200,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + searchQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // 남은 텍스트
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    );
  }


  Widget _buildFundingCard(BuildContext context, FundingProject project) {
    final progressPercentage = (project.currentAmount / project.targetAmount * 100).clamp(0, 100);
    final progressPercentageReal = (project.currentAmount / project.targetAmount * 100);
    
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/fund/${project.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로젝트 이미지
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 프로젝트 이미지 (실제로는 NetworkImage 등 사용)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: project.imageUrl != null && project.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: Image.network(
                            project.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.black,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / 
                                          loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ Image load error: $error for URL: ${project.imageUrl}');
                              return Container(
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.eco,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                  ),
                  
                  // 프로젝트 제목 오버레이
                  Positioned(
                    left: 20,
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        project.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  
                ],
              ),
            ),
            
            // 프로젝트 정보
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 진행률 바
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressPercentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[400]!,
                              Colors.green[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 금액 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${project.currentAmount.toStringAsFixed(0)} Points',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'raised of ${project.targetAmount.toStringAsFixed(0)} goal',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[100]!,
                              Colors.green[200]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${progressPercentageReal.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${project.daysLeft} days left',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // This closing parenthesis was missing
    );
  }
}