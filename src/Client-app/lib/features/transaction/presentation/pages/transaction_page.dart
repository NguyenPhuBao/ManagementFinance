import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/category/category_classify.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/transaction_entity.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_lookup.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transaction_filter_bar.dart';
import '../widgets/transaction_list_row.dart';
import 'add_transaction_page.dart';

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

  /// Điều kiện lọc hiện tại; giữ nguyên khi đổi tháng — người dùng đang xem
  /// "chi ở ví Tiết kiệm" thì lật sang tháng trước vẫn muốn xem đúng thứ đó.
  TransactionFilter _filter = const TransactionFilter();

  // Hai stream tra tên ví/danh mục cho từng dòng. Tạo MỘT lần cho mỗi tài
  // khoản và giữ lại: tạo trong build là mỗi lần đổi tháng lại đăng ký lại,
  // danh sách chớp trắng một nhịp.
  int? _lookupAccount;
  Stream<List<Wallet>>? _wallets;
  Stream<List<Category>>? _categories;

  @override
  void initState() {
    super.initState();
    _selectedMonthDate = DateTime.now();
  }

  void _ensureLookupStreams(int idaccount) {
    if (_lookupAccount == idaccount) return;
    _lookupAccount = idaccount;
    final db = sl<AppDatabase>();
    _wallets = db.walletDao.watchAll(idaccount);
    _categories = db.categoryDao.watchAll(idaccount);
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
    final authState = context.watch<AuthBloc>().state;
    int currentUserId = widget.idaccount;
    if (authState is AuthSuccess && authState.user != null) {
      currentUserId = int.tryParse(authState.user!.id) ?? widget.idaccount;
    }
    _ensureLookupStreams(currentUserId);

    return BlocProvider<TransactionBloc>(
      create: (context) => sl<TransactionBloc>()
        ..add(LoadTransactionsEvent(idaccount: currentUserId)),
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
                          // Bộ lọc chạy trên danh sách tháng đã có trong bloc;
                          // thẻ tổng và danh sách cùng tính trên tập đã lọc để
                          // hai thứ luôn nói cùng một chuyện.
                          final txs = applyTransactionFilter(
                              state.monthlyTransactions, _filter);
                          final summary = summarizeTransactions(txs);

                          return StreamBuilder<List<Wallet>>(
                            stream: _wallets,
                            builder: (_, wallets) =>
                                StreamBuilder<List<Category>>(
                              stream: _categories,
                              builder: (_, categories) {
                                final walletList =
                                    wallets.data ?? const <Wallet>[];
                                final lookup = TransactionLookup(
                                  wallets: walletList,
                                  categories: categories.data ?? const [],
                                );
                                return Column(
                                  children: [
                                    TransactionFilterBar(
                                      filter: _filter,
                                      lookup: lookup,
                                      wallets: walletList,
                                      onChanged: (f) =>
                                          setState(() => _filter = f),
                                      pickCategory: () => context.push<Category>(
                                        '/add/category',
                                        extra: kCategoryClassifies.first,
                                      ),
                                    ),
                                    _buildMonthlySummaryCard(
                                      totalIncome: summary.income,
                                      totalExpense: summary.expense,
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: txs.isEmpty
                                          ? _buildEmptyState(
                                              filtered: _filter.isActive)
                                          : _buildGroupedTransactionList(
                                              txs, blocContext, lookup),
                                    ),
                                  ],
                                );
                              },
                            ),
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

  /// Bảng chi tiết của một dòng: Sửa → mở `/add` ở chế độ sửa rồi tải lại
  /// tháng; Xoá → hỏi xác nhận rồi đi cùng đường với vuốt xoá.
  Future<void> _showDetail(
    BuildContext blocContext,
    TransactionEntity tx,
    TransactionLookup lookup,
  ) async {
    await showModalBottomSheet<void>(
      context: blocContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => TransactionDetailSheet(
        transaction: tx,
        lookup: lookup,
        onEdit: () async {
          Navigator.of(sheetContext).pop();
          final result = await context.push(
            '/add',
            extra: EditTransactionArgs(
              transaction: tx,
              category: lookup.category(tx.categoryId),
            ),
          );
          if (result == true && blocContext.mounted) {
            blocContext.read<TransactionBloc>().add(FilterMonthEvent(
                  year: _selectedMonthDate.year,
                  month: _selectedMonthDate.month,
                ));
          }
        },
        onDelete: () async {
          final ok = await ConfirmDialog.show(
            sheetContext,
            title: 'Xoá giao dịch?',
            message: 'Số dư ví sẽ được hoàn lại. Không hoàn tác được.',
          );
          if (!ok || !sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          blocContext.read<TransactionBloc>().add(DeleteTransactionEvent(tx));
          ScaffoldMessenger.of(blocContext).showSnackBar(
            const SnackBar(content: Text('Đã xóa giao dịch')),
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

  Widget _buildEmptyState({bool filtered = false}) {
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
            child: Icon(
              filtered ? Icons.filter_alt_off_outlined : Icons.receipt_long,
              size: 40,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'Không có giao dịch nào khớp bộ lọc'
                : 'Chưa có giao dịch nào trong tháng này',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Đổi điều kiện hoặc bấm "Xoá lọc"'
                : 'Nhấn nút (+) để thêm giao dịch mới',
            style: const TextStyle(
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
    TransactionLookup lookup,
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
              // Day Items — vuốt xoá; khoản của mục tiêu/hoá đơn bị chặn
              // ngay trong widget (xem `TransactionListRow`).
              ...dayTxs.map((tx) => TransactionListRow(
                    transaction: tx,
                    lookup: lookup,
                    onTap: () => _showDetail(blocContext, tx, lookup),
                    onDelete: () => blocContext.read<TransactionBloc>().add(
                          DeleteTransactionEvent(tx),
                        ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
