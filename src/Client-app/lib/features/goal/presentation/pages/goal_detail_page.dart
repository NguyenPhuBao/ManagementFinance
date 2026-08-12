import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';

class GoalDetailPage extends StatefulWidget {
  final String id;
  const GoalDetailPage({super.key, required this.id});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  late final GoalRepository _goalRepository;
  GoalEntity? _goal;
  bool _isLoading = true;

  int _getAccountId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess && authState.user != null) {
      return int.tryParse(authState.user!.id) ?? 1;
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _goalRepository = sl<GoalRepository>();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    setState(() => _isLoading = true);
    final goal = await _goalRepository.getGoalById(widget.id);
    if (mounted) {
      setState(() {
        _goal = goal;
        _isLoading = false;
      });
    }
  }

  void _showDepositDialog() async {
    if (_goal == null) return;
    final db = sl<AppDatabase>();
    final accountId = _getAccountId(context);
    var wallets = await db.walletDao.getAll(accountId);
    if (wallets.isEmpty) {
      wallets = await db.walletDao.getAllNonDeleted();
    }

    if (!mounted) return;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ít nhất 1 ví trước khi gửi tiết kiệm.')),
      );
      return;
    }

    final amountController = TextEditingController();
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    Wallet selectedSourceWallet = wallets.first;
    Wallet? selectedTargetWallet = wallets.length > 1
        ? wallets.firstWhere(
            (w) => (w.type == 'investment' || w.type == 'bank') && w.id != selectedSourceWallet.id,
            orElse: () => wallets.last,
          )
        : wallets.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gửi thêm tiền vào ${_goal!.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Số tiền hiện tại: ${currencyFormatter.format(_goal!.currentAmount)} / ${currencyFormatter.format(_goal!.targetAmount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.income,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nhập số tiền muốn tích lũy thêm (VNĐ)',
                      hintText: 'e.g. 1.000.000',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Chọn ví nguồn thanh toán (Trừ tiền)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Wallet>(
                        value: selectedSourceWallet,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more, color: AppColors.primary),
                        items: wallets.map((w) {
                          return DropdownMenuItem<Wallet>(
                            value: w,
                            child: Text(
                              '${w.name} (Số dư: ${currencyFormatter.format(w.balance)})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedSourceWallet = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '2. Chọn ví mục tiêu / tiết kiệm (Cộng tiền nhận)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Wallet?>(
                        value: selectedTargetWallet,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more, color: AppColors.primary),
                        items: [
                          ...wallets.map((w) {
                            return DropdownMenuItem<Wallet?>(
                              value: w,
                              child: Text(
                                '${w.name} (Số dư: ${currencyFormatter.format(w.balance)})',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() => selectedTargetWallet = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final raw = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
                      final deposit = double.tryParse(raw) ?? 0.0;
                      if (deposit <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                        );
                        return;
                      }

                      await _goalRepository.depositToGoal(
                        goalId: widget.id,
                        goalName: _goal!.name,
                        depositAmount: deposit,
                        walletId: selectedSourceWallet.id,
                        targetWalletId: selectedTargetWallet?.id,
                        idaccount: accountId,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã tích lũy ${currencyFormatter.format(deposit)} vào ví ${selectedTargetWallet?.name ?? 'mục tiêu'}!'),
                          backgroundColor: AppColors.income,
                        ),
                      );
                      _loadGoal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Xác nhận gửi tiết kiệm',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_goal == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Không tìm thấy mục tiêu')),
      );
    }

    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final percentValue = _goal!.targetAmount > 0
        ? (_goal!.currentAmount / _goal!.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (_goal!.targetAmount - _goal!.currentAmount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _goal!.name,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xóa mục tiêu'),
                  content: Text('Bạn có chắc chắn muốn xóa mục tiêu "${_goal!.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _goalRepository.deleteGoal(widget.id);
                        if (!mounted) return;
                        context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCircularProgress(percentValue),
                    const SizedBox(height: 32),
                    _buildAmountInfo(currencyFormatter, remaining),
                    const SizedBox(height: 24),
                    _buildInsightBox(),
                    const SizedBox(height: 32),
                    _buildHistorySection(currencyFormatter),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProgress(double percentValue) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: percentValue,
              strokeWidth: 16,
              color: const Color(0xFF2E6B27),
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentValue * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ĐÃ HOÀN THÀNH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo(NumberFormat currencyFormatter, double remaining) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currencyFormatter.format(_goal!.currentAmount),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -1,
              ),
            ),
            Text(
              ' / ${currencyFormatter.format(_goal!.targetAmount)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            children: [
              const TextSpan(text: 'Còn lại '),
              TextSpan(
                text: currencyFormatter.format(remaining),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' để đạt mục tiêu'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightBox() {
    final formattedDate = DateFormat('MM/yyyy').format(_goal!.targetDate);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC3EBBB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Color(0xFF2E6B27),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HẠN ĐỊNH MỤC TIÊU: THÁNG $formattedDate',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Theo dõi tiến độ tích lũy để đạt được mục tiêu trước hạn chót.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(NumberFormat currencyFormatter) {
    final accountId = _getAccountId(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LỊCH SỬ TÍCH LŨY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E6B27),
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<dynamic>(
          stream: _goalRepository.watchGoalTransactions(accountId, _goal?.name ?? ''),
          builder: (context, snapshot) {
            final txs = (snapshot.data as List<dynamic>?) ?? [];
            if (txs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Chưa có khoản tích lũy nào.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final tx = txs[index];
                final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.date as DateTime);
                final amount = (tx.amount as double);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F5EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.savings_outlined,
                        color: Color(0xFF2E6B27),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.note.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${currencyFormatter.format(amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2E6B27),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _showDepositDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Gửi thêm tiết kiệm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
