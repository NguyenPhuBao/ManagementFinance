import 'package:flowmoney/core/category/category_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canh chừng điều gì: tên icon của danh mục là chuỗi lưu trong CSDL (seed và
/// backend), còn `IconData` là thứ vẽ được — phép đổi này từng được chép tay ở
/// ba nơi với ba bộ tên khác nhau, nên cùng một danh mục vẽ ba kiểu ở ba màn.
void main() {
  test('mọi tên icon trong bộ seed đều có hình riêng, không rơi về mặc định',
      () {
    const seedIcons = [
      // Seed client (app_database.dart, personal_default_categories.dart):
      // tên Material.
      'restaurant', 'directions_car', 'shopping_bag', 'favorite', 'school',
      'sports_esports', 'home', 'receipt', 'receipt_long', 'local_hospital',
      'card_giftcard', 'trending_up', 'person_add', 'person_remove',
      'more_horiz', 'work', 'payment', 'attach_money', 'movie', 'payments',
      // Seed backend (prisma/seed.js) — đây mới là tên nằm trên server và
      // trên máy thật sau khi pull: tên ngữ nghĩa, không phải tên Material.
      'food', 'transport', 'shopping', 'bill', 'health', 'education',
      'entertain', 'salary', 'bonus', 'invest', 'lend', 'borrow', 'laptop',
    ];
    for (final name in seedIcons) {
      expect(categoryIconFor(name), isNot(kCategoryIconFallback),
          reason: '"$name" là icon của một danh mục seed; rơi về mặc định là '
              'mọi danh mục ấy trông giống nhau trên sổ giao dịch.');
    }
  });

  test('tên backend và tên Material của cùng một ý vẽ cùng một hình', () {
    expect(categoryIconFor('food'), categoryIconFor('restaurant'));
    expect(categoryIconFor('transport'), categoryIconFor('directions_car'));
    expect(categoryIconFor('bill'), categoryIconFor('receipt_long'));
    expect(categoryIconFor('lend'), categoryIconFor('person_add'));
    expect(categoryIconFor('borrow'), categoryIconFor('person_remove'));
  });

  test('tên lạ hoặc null rơi về icon mặc định, không ném lỗi', () {
    expect(categoryIconFor('khong_co'), kCategoryIconFallback);
    expect(categoryIconFor(null), kCategoryIconFallback);
    expect(categoryIconFor(''), kCategoryIconFallback);
  });

  test('mã màu #RRGGBB đọc đúng; chuỗi hỏng thì trả màu dự phòng', () {
    expect(categoryColorFrom('#FF9800'), const Color(0xFFFF9800));
    expect(categoryColorFrom('10B981'), const Color(0xFF10B981));
    expect(categoryColorFrom('xyz', fallback: Colors.black), Colors.black);
    expect(categoryColorFrom(null, fallback: Colors.black), Colors.black);
  });
}
