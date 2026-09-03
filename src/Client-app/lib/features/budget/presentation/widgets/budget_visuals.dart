import 'package:flutter/material.dart';

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
/// `category_page.dart` có một bản riêng viết trước file này. Cố ý **không**
/// sửa file đó trong lần thay đổi này để giữ phạm vi ở feature ngân sách; nếu
/// sau này dọn thì gộp cả hai về đây.
IconData budgetIconFor(String? icon) => switch (icon) {
      'restaurant' => Icons.restaurant,
      'directions_car' => Icons.directions_car,
      'shopping_bag' => Icons.shopping_bag,
      'receipt_long' || 'receipt' => Icons.receipt_long,
      'home' => Icons.home,
      'work' => Icons.work,
      'favorite' => Icons.favorite,
      'school' => Icons.school,
      'savings' => Icons.savings,
      _ => Icons.category_outlined,
    };

/// Mã màu dạng `#RRGGBB` → [Color]. Chuỗi hỏng thì trả [fallback] chứ không ném
/// lỗi: một danh mục có màu sai không được làm trắng cả trang.
Color budgetColorFrom(String? hex, {Color fallback = const Color(0xFF1A1A19)}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final normalized = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.parse('FF$normalized', radix: 16));
  } catch (_) {
    return fallback;
  }
}
