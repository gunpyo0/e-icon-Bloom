

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'fund_viewmodel.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:bloom/providers/points_provider.dart';

class FundDetailScreen extends ConsumerWidget {
  final String fundId;

  const FundDetailScreen({
    super.key,
    required this.fundId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundState = ref.watch(fundViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Fund Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [],
      ),
      body: fundState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('An error occurred: $error'),
            ],
          ),
        ),
        data: (projects) {
          final project = projects.firstWhere(
            (p) => p.id == fundId,
            orElse: () => projects.first,
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProjectImage(context, project),
                _buildProjectInfo(context, project),
                _buildProjectDescription(context, project),
                _buildFundingButton(context, project),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectImage(BuildContext context, FundingProject project) {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          project.imageUrl != null && project.imageUrl!.isNotEmpty
            ? Image.network(
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
                        size: 48,
                      ),
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 48,
                ),
              ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  '${project.daysLeft} days left',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectInfo(BuildContext context, FundingProject project) {
    final progressPercentage = (project.currentAmount / project.targetAmount * 100).clamp(0, 100);
    final progressPercentageReal = (project.currentAmount / project.targetAmount * 100);

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Funding Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Amount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${project.currentAmount.toStringAsFixed(0)} Points',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Achievement Rate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progressPercentageReal.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Target Amount: ${project.targetAmount.toStringAsFixed(0)} Points',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDescription(BuildContext context, FundingProject project) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Introduction',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            project.description ?? 'This project started with an innovative idea for environmental protection. Our goal is to create a sustainable future.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundingButton(BuildContext context, FundingProject project) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // Funding participation functionality
            _showFundingDialog(context, project);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Participate in Funding',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showFundingDialog(BuildContext context, FundingProject project) {
    showDialog(
      context: context,
      builder: (context) => _FundingDialog(project: project),
    );
  }
}

class _FundingDialog extends ConsumerStatefulWidget {
  final FundingProject project;

  const _FundingDialog({required this.project});

  @override
  ConsumerState<_FundingDialog> createState() => _FundingDialogState();
}

class _FundingDialogState extends ConsumerState<_FundingDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(pointsProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          const Icon(Icons.monetization_on, color: Colors.green, size: 32),
          const SizedBox(height: 8),
          Text(
            'Fund with Points',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            pointsAsync.when(
              data: (totalPoints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'My Points: ${totalPoints.toString()} P',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Points to Fund',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter points to fund',
                        suffixText: 'P',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick selection buttons
                    Wrap(
                      spacing: 8,
                      children: [100, 500, 1000, totalPoints ~/ 2, totalPoints]
                          .where((amount) => amount > 0 && amount <= totalPoints)
                          .map((amount) => GestureDetector(
                            onTap: () => _amountController.text = amount.toString(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                '${amount}P',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ))
                          .toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Unable to load point information: $error'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () => _handleFunding(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Fund'),
        ),
      ],
    );
  }

  Future<void> _handleFunding(BuildContext context) async {
    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) { 
      _showSnackBar(context, '올바른 포인트 입력해줘!', Colors.red); 
      return; 
    }

    setState(() => _isLoading = true);
    try {
      final totalPoints = ref.read(pointsProvider).value ?? 0;
      if (amount > totalPoints) { 
        _showSnackBar(context, '포인트 부족해 😭', Colors.red); 
        return; 
      }

      print('💰 Starting donation: $amount points');
      
      // 1. 낙관적 포인트 차감 (즉시 UI 업데이트)
      final pointsSuccess = await ref.read(pointsProvider.notifier).subtractPoints(amount);
      if (!pointsSuccess) {
        _showSnackBar(context, '포인트 처리 실패', Colors.red);
        return;
      }

      // 2. 서버에 기부 요청
      await EcoBackend.instance.donate(campaignId: widget.project.id, amount: amount);
      print('✅ Donation completed on server');

      // 3. 펀딩 프로젝트 새로고침 (기부 후 금액 업데이트)
      await ref.read(fundViewModelProvider.notifier).refresh();
      print('✅ Fund projects refreshed');

      // 4. 최종 포인트 동기화 확인
      await ref.read(pointsProvider.notifier).refresh();
      print('✅ Points synchronized');

      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, '$amount P 기부 완료! 고마워 💚', Colors.green);
      }
    } catch (e) {
      print('❌ Donation failed: $e');
      // 실패 시 포인트 다시 새로고침하여 서버 상태와 동기화
      await ref.read(pointsProvider.notifier).refresh();
      if (mounted) _showSnackBar(context, '펀딩 실패: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}