import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';
import '../bloc/budget_cubit.dart';
import 'budget_detail_sheet.dart';
import 'budget_tabs_view.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `null` khi chưa có phiên đăng nhập dùng được. Cubit sẽ báo lỗi thay vì
    // đoán một mã tài khoản — xem `core/auth/current_account.dart`.
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<BudgetCubit>(
      create: (_) => sl<BudgetCubit>()..watchBudgets(idaccount),
      child: const _BudgetPageContent(),
    );
  }
}

class _BudgetPageContent extends StatelessWidget {
  const _BudgetPageContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BudgetCubit, BudgetState>(
      // Sau khi tạo/sửa/xoá, cubit phát `BudgetSaved` rồi stream tự đẩy danh
      // sách mới về — chỉ cần hiện lời nhắn, không cần nạp lại tay.
      listenWhen: (_, s) => s is BudgetSaved || s is BudgetError,
      listener: (context, state) {
        final message = switch (state) {
          BudgetSaved(:final message) => message,
          BudgetError(:final message) => message,
          _ => null,
        };
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor:
                state is BudgetError ? AppColors.error : AppColors.primary,
          ));
      },
      buildWhen: (_, s) =>
          s is BudgetLoaded || s is BudgetLoading || s is BudgetError,
      builder: (context, state) => switch (state) {
        BudgetLoaded(isEmpty: true) => const _EmptyScaffold(),
        BudgetLoaded() => BudgetTabsView(
            state: state,
            onCreate: () => _openEditor(context),
            onEdit: (v) => _openEditor(context, id: v.budget.id),
            onDelete: (v) => _confirmDelete(context, v),
            onShowDetail: (v) => _showDetail(context, v),
            onOpenAnalytics: () => context.go('/analytics'),
          ),
        BudgetError(:final message) => _ErrorScaffold(message: message),
        _ => const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      },
    );
  }
}

// ─── Các trạng thái ──────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyScaffold extends StatelessWidget {
  const _EmptyScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings_outlined,
                    size: 64, color: AppColors.outline),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có ngân sách nào',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đặt hạn mức cho một danh mục để biết mình còn tiêu được bao '
                  'nhiêu trong tháng.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _openEditor(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Tạo ngân sách mới',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Điều hướng và hộp thoại ─────────────────────────────────────────────────

void _openEditor(BuildContext context, {String? id}) {
  context.push(id == null ? '/budget/rules' : '/budget/rules?id=$id');
}

Future<bool> _confirmDelete(BuildContext context, BudgetView view) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xoá ngân sách?'),
      content: Text(
        'Hạn mức cho "${view.displayName}" sẽ không còn được theo dõi. '
        'Các giao dịch đã ghi không bị ảnh hưởng.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  await context.read<BudgetCubit>().deleteBudget(view.budget.id);
  return true;
}

/// Mở bảng chi tiết chỉ đọc.
///
/// Dùng bottom sheet chứ không mở thêm một trang: ngân sách hết hạn chỉ cần xem
/// lại con số đã chốt, không có thao tác nào để làm ở đó.
void _showDetail(BuildContext context, BudgetView view) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    // Nội dung cao hơn nửa màn hình thì sheet tự cho kéo lên; bản thân bảng
    // cũng cuộn được nên không bao giờ cắt mất phần cuối.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BudgetDetailSheet(view: view),
  );
}
