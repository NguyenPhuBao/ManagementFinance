import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/budget_pace.dart';

/// Dòng "Nên chi X/ngày · còn N ngày" — dùng chung cho thẻ trong danh sách và
/// trang chi tiết, để hai nơi không bao giờ nói hai kiểu.
///
/// `null` khi không còn ngày nào (hết hạn, hoặc chưa tới ngày bắt đầu): không
/// có gì để chia, và một dòng "còn 0 ngày" chỉ gây hoang mang.
///
/// Các cụm tiền và *"còn N ngày"* dính liền bằng khoảng trắng không ngắt
/// (U+00A0): ở màn hẹp dòng này xuống hai dòng, và chỗ ngắt phải rơi sau `·`
/// chứ không giữa *"còn 25 ⏎ ngày"* (G75, 2026-10-07). Nhìn y hệt dấu cách.
String? budgetPaceLine(BudgetPace pace) {
  if (pace.daysLeft <= 0) return null;
  final ngay = 'còn\u00A0${pace.daysLeft}\u00A0ngày';
  if (pace.suggestedPerDay <= 0) return 'Đã vượt hạn mức · $ngay';
  return 'Nên chi ${CurrencyFormatter.formatLienKhoi(pace.suggestedPerDay)}/ngày · '
      '$ngay';
}

String budgetPaceStatusLabel(BudgetPaceStatus status) => switch (status) {
      BudgetPaceStatus.slow => 'Chậm hơn dự kiến',
      BudgetPaceStatus.onTrack => 'Đúng nhịp',
      BudgetPaceStatus.fast => 'Nhanh hơn dự kiến',
    };

/// Chậm là tốt (xanh), nhanh là đáng để ý (vàng) — không phải đỏ, vì nhanh
/// chưa chắc vượt; vượt đã có màu riêng ở thang bốn màu.
Color budgetPaceStatusColour(BudgetPaceStatus status) => switch (status) {
      BudgetPaceStatus.slow => AppColors.income,
      BudgetPaceStatus.onTrack => AppColors.primary,
      BudgetPaceStatus.fast => AppColors.warning,
    };
