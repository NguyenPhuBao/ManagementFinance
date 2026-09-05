import 'package:flutter/material.dart';

/// Icon khi tên không nhận ra được (hoặc null/rỗng).
const IconData kCategoryIconFallback = Icons.category_outlined;

/// Đổi tên icon lưu trong cột `categories.icon` thành [IconData].
///
/// Đây là **định nghĩa duy nhất** của phép đổi này. Trước 2026-09-06 nó bị chép
/// tay ở ba nơi (`category_page`, `category_add_page`, `budget_visuals`) với ba
/// bộ tên khác nhau — và cả ba chỉ hiểu tên Material, trong khi seed **backend**
/// (`prisma/seed.js`) dùng tên ngữ nghĩa (`food`, `transport`, `bill`, `lend`…)
/// nên sau khi pull, phần lớn danh mục mặc định rơi về icon mặc định ở mọi màn.
/// Hai cột dưới đây cố ý đặt cạnh nhau: tên Material bên trái, tên backend bên
/// phải, cùng một hình.
IconData categoryIconFor(String? icon) => switch (icon) {
      'restaurant' || 'food' => Icons.restaurant,
      'directions_car' || 'transport' => Icons.directions_car,
      'shopping_bag' || 'shopping' => Icons.shopping_bag,
      'receipt_long' || 'receipt' || 'bill' => Icons.receipt_long,
      'home' => Icons.home,
      'local_hospital' || 'health' => Icons.local_hospital,
      'favorite' => Icons.favorite,
      'school' || 'education' => Icons.school,
      'sports_esports' || 'entertain' => Icons.sports_esports,
      'movie' => Icons.movie,
      'work' => Icons.work,
      'payments' || 'salary' => Icons.payments,
      'card_giftcard' || 'bonus' => Icons.card_giftcard,
      'trending_up' || 'invest' => Icons.trending_up,
      'person_add' || 'lend' => Icons.person_add,
      'person_remove' || 'borrow' => Icons.person_remove,
      'payment' => Icons.payment,
      'attach_money' => Icons.attach_money,
      'savings' => Icons.savings,
      'laptop' => Icons.laptop,
      'calendar_month' => Icons.calendar_month,
      'more_horiz' => Icons.more_horiz,
      _ => kCategoryIconFallback,
    };

/// Mã màu `#RRGGBB` (có hoặc không có `#`) → [Color]. Chuỗi hỏng hay null thì
/// trả [fallback] chứ không ném lỗi: một danh mục có màu sai không được làm
/// trắng cả trang.
Color categoryColorFrom(
  String? hex, {
  Color fallback = const Color(0xFF10B981),
}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final normalized = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.parse('FF$normalized', radix: 16));
  } catch (_) {
    return fallback;
  }
}
