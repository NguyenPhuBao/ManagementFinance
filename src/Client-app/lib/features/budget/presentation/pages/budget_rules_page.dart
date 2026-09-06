import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/budget_cubit.dart';
import 'budget_form.dart';

/// Tạo hoặc sửa một ngân sách.
///
/// `?id=<uuid>` trên đường dẫn nghĩa là sửa; không có thì là tạo mới.
///
/// Trang này chỉ nối cubit với [BudgetForm] — toàn bộ ô nhập và phép kiểm nằm ở
/// form, nơi kiểm được bằng widget test mà không phải dựng DI lẫn router.
///
/// ## Vì sao form này khác bản dựng hình trên Stitch
///
/// Bản mockup có ba phần không có chỗ nào để lưu:
/// - **"Tên ngân sách"** — backend không có cột tên (`model budget` trong
///   `schema.prisma`). Danh tính của ngân sách là *danh mục + chu kỳ*.
/// - **"Danh mục áp dụng" nhiều danh mục** — cột `Idcategory` chỉ giữ được
///   MỘT. Từ 2026-09-04 quy tắc còn chặt hơn: mỗi ngân sách thuộc về đúng một
///   danh mục, và mỗi danh mục chỉ có một ngân sách đang chạy.
/// - **"Quy tắc phân bổ 50/30/20"** — không có bảng nào lưu, và nó nói về việc
///   chia *thu nhập* chứ không phải hạn mức của một ngân sách.
///
/// Giữ lại chúng dưới dạng giao diện không lưu được gì sẽ tái lập đúng vấn đề
/// cũ: người dùng bấm Lưu và tưởng đã lưu. Người dùng đã xác nhận lựa chọn này
/// ngày 2026-09-04.
class BudgetRulesPage extends StatelessWidget {
  /// null = tạo mới.
  final String? budgetId;

  const BudgetRulesPage({super.key, this.budgetId});

  @override
  Widget build(BuildContext context) {
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<BudgetCubit>(
      create: (_) =>
          sl<BudgetCubit>()..loadEditor(idaccount, budgetId: budgetId),
      child: _BudgetRulesContent(idaccount: idaccount),
    );
  }
}

class _BudgetRulesContent extends StatelessWidget {
  final int? idaccount;
  const _BudgetRulesContent({required this.idaccount});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BudgetCubit, BudgetState>(
      listenWhen: (_, s) => s is BudgetSaved || s is BudgetError,
      listener: (context, state) {
        if (state is BudgetError) {
          // Ví dụ: danh mục đã có ngân sách đang chạy. Ở lại form để người dùng
          // đổi lựa chọn thay vì đóng trang và mất hết những gì vừa nhập.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ));
          return;
        }
        if (state is! BudgetSaved) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message)));
        context.pop();
      },
      buildWhen: (_, s) =>
          s is BudgetEditorReady || s is BudgetLoading || s is BudgetError,
      builder: (context, state) => switch (state) {
        BudgetEditorReady(:final categories, :final editing) => BudgetForm(
            categories: categories,
            editing: editing,
            onSubmit: (draft) => _submit(context, draft),
          ),
        BudgetError(:final message) => _ErrorScaffold(message: message),
        _ => const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      },
    );
  }

  void _submit(BuildContext context, BudgetDraft draft) {
    final cubit = context.read<BudgetCubit>();
    final state = cubit.state;
    final editing = state is BudgetEditorReady ? state.editing : null;

    if (editing == null) {
      cubit.addBudget(
        idaccount: idaccount,
        amount: draft.amount,
        categoryId: draft.categoryId,
        thresholdWarningAmount: draft.thresholdWarningAmount,
        thresholdWarningPercent: draft.thresholdWarningPercent,
        overSpending: draft.overSpending,
        startDate: draft.startDate,
        endDate: draft.endDate,
        recurrence: draft.recurrence,
        timeRecurrence: draft.timeRecurrence,
        note: draft.note,
      );
      return;
    }

    cubit.updateBudget(editing.copyWith(
      categoryId: () => draft.categoryId,
      amount: draft.amount,
      thresholdWarningAmount: () => draft.thresholdWarningAmount,
      thresholdWarningPercent: () => draft.thresholdWarningPercent,
      overSpending: draft.overSpending,
      startDate: draft.startDate,
      endDate: () => draft.endDate,
      recurrence: draft.recurrence,
      timeRecurrence: () => draft.timeRecurrence,
      note: draft.note,
    ));
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
