import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart';
import '../../data/models/budget_entity.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {
  const BudgetInitial();
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  final List<BudgetView> budgets;

  /// Tổng hạn mức của mọi ngân sách đang chạy.
  final double totalAmount;

  /// Tổng đã chi, tính từ bảng giao dịch.
  final double totalSpent;

  const BudgetLoaded({
    required this.budgets,
    required this.totalAmount,
    required this.totalSpent,
  });

  double get totalRemaining => totalAmount - totalSpent;

  /// Cắt trần ở 1.0 để thanh tiến trình không tràn khung khi tiêu vượt.
  double get percentSpent {
    if (totalAmount <= 0) return 0.0;
    final ratio = totalSpent / totalAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  bool get isEmpty => budgets.isEmpty;

  @override
  List<Object?> get props => [budgets, totalAmount, totalSpent];
}

/// Trang cấu hình đã có đủ thứ cần để dựng form.
///
/// Gộp danh mục và ngân sách đang sửa vào **một** state thay vì hai: form chỉ
/// dựng được khi có cả hai, tách ra sẽ đẻ thêm một trạng thái trung gian mà
/// giao diện phải xử lý mà không mang lại gì.
class BudgetEditorReady extends BudgetState {
  final List<Category> categories;

  /// null = đang tạo mới.
  final BudgetEntity? editing;

  const BudgetEditorReady({required this.categories, this.editing});

  bool get isCreating => editing == null;

  @override
  List<Object?> get props => [categories, editing?.id, editing?.updatedAt];
}

/// Đã ghi xong một thay đổi. Mang theo lời nhắn để giao diện hiện snackbar.
class BudgetSaved extends BudgetState {
  final String message;

  const BudgetSaved(this.message);

  @override
  List<Object?> get props => [message];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
