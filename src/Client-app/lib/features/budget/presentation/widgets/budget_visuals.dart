import 'package:flutter/material.dart';

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
