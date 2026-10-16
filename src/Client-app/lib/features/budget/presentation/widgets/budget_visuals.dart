import 'package:flutter/material.dart';

import '../../../category/presentation/widgets/category_visuals.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/budget_health.dart';

/// Thang sức khoẻ ở `domain/budget_health.dart` (dời 2026-10-15); export lại để ba widget đang import tệp này không đổi.
export '../../domain/budget_health.dart';

/// Màu tương ứng của mỗi mức.
Color budgetHealthColour(BudgetHealth health) => switch (health) {
      BudgetHealth.safe => AppColors.income,
      BudgetHealth.caution => AppColors.warning,
      BudgetHealth.critical => AppColors.expense,
      BudgetHealth.over => AppColors.error,
    };

/// Chuyển tên biểu tượng và mã màu do danh mục lưu thành thứ vẽ được.
///
/// Từ 2026-09-06 chỉ uỷ quyền về `features/category/presentation/widgets/category_visuals.dart` — định
/// nghĩa duy nhất, hiểu cả tên Material lẫn tên seed backend (`food`,
/// `bill`…). Giữ hai hàm này để chỗ gọi trong feature ngân sách không đổi.
IconData budgetIconFor(String? icon) => categoryIconFor(icon);

/// Mã màu dạng `#RRGGBB` → [Color]. Chuỗi hỏng thì trả [fallback] chứ không ném
/// lỗi: một danh mục có màu sai không được làm trắng cả trang.
Color budgetColorFrom(String? hex,
        {Color fallback = const Color(0xFF1A1A19)}) =>
    categoryColorFrom(hex, fallback: fallback);
