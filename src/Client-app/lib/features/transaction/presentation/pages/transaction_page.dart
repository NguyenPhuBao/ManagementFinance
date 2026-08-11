import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

class TransactionPage extends StatefulWidget {
  final int idaccount;

  const TransactionPage({
    super.key,
    this.idaccount = 1,
  });

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late DateTime _selectedMonthDate;

  @override
  void initState() {
    super.initState();
    _selectedMonthDate = DateTime.now();
  }

  void _changeMonth(int deltaYears, int deltaMonths, BuildContext blocContext) {
    setState(() {
      _selectedMonthDate = DateTime(
        _selectedMonthDate.year + deltaYears,
        _selectedMonthDate.month + deltaMonths,
        1,
      );
    });
    blocContext.read<TransactionBloc>().add(
          FilterMonthEvent(
            year: _selectedMonthDate.year,
            month: _selectedMonthDate.month,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionBloc>(
      create: (context) => sl<TransactionBloc>()
        ..add(LoadTransactionsEvent(idaccount: widget.idaccount)),
      child: Builder(
        builder: (blocContext) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Sổ giao dịch',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                final result = await context.push('/add');
                if (result == true && blocContext.mounted) {
                  blocContext.read<TransactionBloc>().add(
                        FilterMonthEvent(
                          year: _selectedMonthDate.year,
                          month: _selectedMonthDate.month,
                        ),
                      );
                }
              },
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _buildMonthSelector(blocContext),
                  Expanded(
                    child: BlocBuilder<TransactionBloc, TransactionState>(
                      builder: (context, state) {
                        if (state is TransactionLoadingState) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (state is TransactionLoadedState) {
                          final txs = state.monthlyTransactions;

                          return Column(
                            children: [
                              _buildMonthlySummaryCard(
                                totalIncome: state.totalIncome,
                                totalExpense: state.totalExpense,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: txs.isEmpty
                                    ? _buildEmptyState()
                                    : _buildGroupedTransactionList(txs, blocContext),
                              ),
                            ],
                          );
                        }

                        if (state is TransactionErrorState) {
                          return Center(
                            child: Text(
                              'Lỗi: ${state.message}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext blocContext) {
    final monthStr = DateFormat('MM/yyyy').format(_selectedMonthDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => _changeMonth(0, -1, blocContext),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tháng $monthStr',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () => _changeMonth(0, 1, blocContext),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard({
    required double totalIncome,
    required double totalExpense,
  }) {
    final net = totalIncome - totalExpense;
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryColumn('Thu nhập', '+${formatter.format(totalIncome)}đ', AppColors.income),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _buildSummaryColumn('Chi tiêu', '-${formatter.format(totalExpense)}đ', AppColors.error),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _buildSummaryColumn(
            'Thu net',
            '${net >= 0 ? '+' : ''}${formatter.format(net)}đ',
            net >= 0 ? AppColors.income : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 40,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có giao dịch nào trong tháng này',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn nút (+) để thêm giao dịch mới',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactionList(
    List<TransactionEntity> transactions,
    BuildContext blocContext,
  ) {
    // Group transactions by Date (YYYY-MM-DD)
    final Map<String, List<TransactionEntity>> grouped = {};
    for (final tx in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final formatter = NumberFormat('#,###', 'vi_VN');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateStr = sortedDates[dateIndex];
        final dayTxs = grouped[dateStr]!;
        final dateObj = DateTime.parse(dateStr);
        final formattedDateHeader = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(dateObj);

        // Day net balance calculation
        double dayNet = 0;
        for (final t in dayTxs) {
          if (t.type == 'thu') dayNet += t.amount;
          if (t.type == 'chi') dayNet -= t.amount;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Day Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDateHeader,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${dayNet >= 0 ? '+' : ''}${formatter.format(dayNet)}đ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: dayNet >= 0 ? AppColors.income : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              // Day Items
              ...dayTxs.map((tx) {
                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    blocContext.read<TransactionBloc>().add(
                          DeleteTransactionEvent(tx),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa giao dịch')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.surfaceContainer,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tx.type == 'chi'
                                ? Icons.arrow_downward
                                : (tx.type == 'thu' ? Icons.arrow_upward : Icons.swap_horiz),
                            color: tx.type == 'chi'
                                ? AppColors.error
                                : (tx.type == 'thu' ? AppColors.income : AppColors.primary),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.note.isNotEmpty ? tx.note : (tx.type == 'chi' ? 'Khoản chi' : 'Khoản thu'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ví: ${tx.walletId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${tx.type == 'chi' ? '-' : (tx.type == 'thu' ? '+' : '')}${formatter.format(tx.amount)}đ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tx.type == 'chi'
                                ? AppColors.error
                                : (tx.type == 'thu' ? AppColors.income : AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
