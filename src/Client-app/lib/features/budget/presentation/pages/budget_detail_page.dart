import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../transaction/data/hoa_don_da_xoa_nguon.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../../transaction/domain/transaction_owner.dart';
import '../../../transaction/presentation/bloc/transaction_bloc.dart';
import '../../../transaction/presentation/bloc/transaction_event.dart';
import '../../../transaction/presentation/pages/add_transaction_page.dart';
import '../../../transaction/presentation/widgets/transaction_detail_sheet.dart';
import '../bloc/budget_detail_cubit.dart';
import '../../domain/budget_locking.dart';
import 'budget_detail_view.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

/// Trang chi tiết một ngân sách — `/budget/detail/:id`.
///
/// Chỉ nối cubit với [BudgetDetailView]; bố cục và quy tắc hiển thị nằm ở
/// view, nơi kiểm được bằng widget test không cần DI lẫn router.
///
/// Bấm một giao dịch mở đúng bảng chi tiết của sổ (`TransactionDetailSheet`),
/// và Sửa/Xoá đi cùng đường với sổ qua `TransactionBloc` — không tự viết một
/// đường xoá thứ hai, vì đường của sổ mới biết hoàn ví và chặn khoản thuộc
/// mục tiêu/hoá đơn. Khoản trả hoá đơn kiểu cũ / mồ côi mở khoá có cảnh báo như
/// ở sổ (việc 4c) — trang hỏi `HoaDonDaXoaNguon` trước khi mở bảng.
class BudgetDetailPage extends StatelessWidget {
  final String budgetId;

  const BudgetDetailPage({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider<BudgetDetailCubit>(
          create: (_) => sl<BudgetDetailCubit>()
            ..watch(idaccount: idaccount, budgetId: budgetId),
        ),
        BlocProvider<TransactionBloc>(create: (_) => sl<TransactionBloc>()),
      ],
      child: _BudgetDetailContent(budgetId: budgetId),
    );
  }
}

class _BudgetDetailContent extends StatelessWidget {
  final String budgetId;
  const _BudgetDetailContent({required this.budgetId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BudgetDetailCubit, BudgetDetailState>(
      builder: (context, state) => switch (state) {
        BudgetDetailLoaded() => BudgetDetailView(
            state: state,
            // Cùng quy tắc với tab "Đã hết hạn" — và cùng ngoại lệ G15.
            onEdit: budgetActionsLocked(
                    expired: state.expired, budget: state.view.budget)
                ? null
                : () => context.push('/budget/rules?id=$budgetId'),
            onTapTransaction: (tx) =>
                _showTransaction(context, tx, state.lookup),
          ),
        BudgetDetailError(:final message) => Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.primary),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        BudgetDetailLoading() => const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      },
    );
  }

  Future<void> _showTransaction(
    BuildContext blocContext,
    TransactionEntity tx,
    TransactionLookup lookup,
  ) async {
    // Việc 4c — hỏi TRƯỚC khi mở; cổng chưa đăng ký (test) → khoá như cũ.
    final daXoa = await hoaDonDaXoaCua(
      tx,
      sl.isRegistered<HoaDonDaXoaNguon>() ? sl<HoaDonDaXoaNguon>() : null,
    );
    if (!blocContext.mounted) return;
    await showModalBottomSheet<void>(
      context: blocContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => TransactionDetailSheet(
        transaction: tx,
        lookup: lookup,
        hoaDonDaXoa: daXoa,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          // Trang này theo dõi stream nên tự làm mới sau khi sửa xong; không
          // cần đọc kết quả trả về như sổ.
          blocContext.push(
            '/add',
            extra: EditTransactionArgs(
              transaction: tx,
              category: lookup.category(tx.categoryId),
            ),
          );
        },
        onDelete: () async {
          final ok = await ConfirmDialog.show(
            sheetContext,
            title: 'Xoá giao dịch?',
            message: cauXacNhanXoaGiaoDich(tx, hoaDonDaXoa: daXoa),
          );
          if (!ok || !sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          blocContext.read<TransactionBloc>().add(DeleteTransactionEvent(tx));
          baoNhanh('Đã xóa giao dịch', loai: LoaiThongBao.xong);
        },
      ),
    );
  }
}
