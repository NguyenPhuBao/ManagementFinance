import 'package:flutter/material.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';

/// Bốn mức sức khoẻ của một ngân sách đang chạy.
///
/// Màu là **cách duy nhất** người dùng biết mình sắp vượt hạn mức: ứng dụng
/// không gửi thông báo đẩy và không chặn ghi giao dịch. Vì vậy các mốc phải nằm
/// đúng một chỗ, có test canh, chứ không rải trong widget.
enum BudgetHealth {
  /// Dưới 70% hạn mức — xanh lá.
  safe,

  /// Từ 70% tới dưới 90% — vàng.
  caution,

  /// Từ 90% tới hết đúng 100% — đỏ tươi.
  critical,

  /// Đã tiêu quá hạn mức — đỏ sẫm.
  over,
}

/// Mốc chuyển màu, do người dùng chốt ngày 2026-09-04. Biên **đóng**: chạm mốc
/// là đổi màu, để cảnh báo khớp với con số phần trăm người dùng đọc được.
const double _cautionAt = 0.70;
const double _criticalAt = 0.90;

/// Xếp một ngân sách vào một trong bốn mức.
BudgetHealth budgetHealthOf(BudgetEntity budget) {
  // Hỏi `isOverBudget` trước khi tính tỉ lệ: hạn mức 0 (không tạo được từ form
  // nhưng kéo về từ backend thì có) cho ra Infinity/NaN, mà NaN so với mọi mốc
  // đều false nên sẽ lặng lẽ rơi vào nhánh "an toàn".
  if (budget.isOverBudget) return BudgetHealth.over;

  final ratio = budget.rawPercentSpent;
  if (ratio >= _criticalAt) return BudgetHealth.critical;
  if (ratio >= _cautionAt) return BudgetHealth.caution;
  return BudgetHealth.safe;
}

/// Màu tương ứng của mỗi mức.
Color budgetHealthColour(BudgetHealth health) => switch (health) {
      BudgetHealth.safe => AppColors.income,
      BudgetHealth.caution => AppColors.warning,
      BudgetHealth.critical => AppColors.expense,
      BudgetHealth.over => AppColors.error,
    };

/// Chuyển tên biểu tượng và mã màu do danh mục lưu thành thứ vẽ được.
///
/// Từ 2026-09-06 chỉ uỷ quyền về `core/category/category_visuals.dart` — định
/// nghĩa duy nhất, hiểu cả tên Material lẫn tên seed backend (`food`,
/// `bill`…). Giữ hai hàm này để chỗ gọi trong feature ngân sách không đổi.
IconData budgetIconFor(String? icon) => categoryIconFor(icon);

/// Mã màu dạng `#RRGGBB` → [Color]. Chuỗi hỏng thì trả [fallback] chứ không ném
/// lỗi: một danh mục có màu sai không được làm trắng cả trang.
Color budgetColorFrom(String? hex, {Color fallback = const Color(0xFF1A1A19)}) =>
    categoryColorFrom(hex, fallback: fallback);
