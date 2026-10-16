/// Phép chọn ngân sách căng nhất cho Trang chủ và hai gói số Nhận xét (`goi_so_trang_chu`, `goi_so_ngan_sach`).
///
/// Vì sao cần: Stitch màn Home vẽ đúng một ngân sách ("Đã dùng 2.100k / 3.000k · 68%"), nên phép chọn phải có test —
/// chọn sai là trang chủ khoe một ngân sách đang ổn trong khi cái khác vượt. Dời từ `home_budget_card_test.dart`
/// 2026-10-15 cùng hàm (quét 28).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/pick_home_budget.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);

  BudgetView view({
    required String id,
    required double spent,
    double amount = 1000000,
    DateTime? start,
    bool recurrence = true,
    String name = 'Ăn uống',
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: spent,
        startDate: start ?? DateTime(2026, 9, 1),
        recurrence: recurrence,
        updatedAt: now,
      ),
      categoryName: name,
    );
  }

  group('pickHomeBudget', () {
    test('chọn ngân sách có tỉ lệ đã chi cao nhất', () {
      final picked = pickHomeBudget(
        [view(id: 'a', spent: 300000), view(id: 'b', spent: 900000)],
        now,
      );
      expect(picked?.budget.id, 'b');
    });

    test('ngân sách vượt thắng ngân sách gần hết dù số tiền nhỏ hơn', () {
      final picked = pickHomeBudget(
        [
          view(id: 'gan', spent: 950000),
          view(id: 'vuot', amount: 100000, spent: 150000),
        ],
        now,
      );
      expect(picked?.budget.id, 'vuot',
          reason: 'So theo TỈ LỆ, không theo số tiền: 150% căng hơn 95%.');
    });

    test('bỏ qua ngân sách đã hết hạn', () {
      final picked = pickHomeBudget(
        [
          view(id: 'chet', spent: 999999, start: DateTime(2026, 1, 1),
              recurrence: false),
          view(id: 'song', spent: 100000),
        ],
        now,
      );
      expect(picked?.budget.id, 'song',
          reason: 'Trang chủ nói về việc còn tiêu được bao nhiêu; ngân sách '
              'chết không còn gì để tiêu.');
    });

    test('không có ngân sách nào đang chạy thì null', () {
      expect(pickHomeBudget(const [], now), isNull);
      expect(
        pickHomeBudget(
          [view(id: 'chet', spent: 0, start: DateTime(2026, 1, 1),
              recurrence: false)],
          now,
        ),
        isNull,
      );
    });
  });
}
