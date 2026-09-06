/// Thang bốn màu của ngân sách: xanh lá → vàng → đỏ tươi → đỏ sẫm.
///
/// Vì sao cần: màu là **cách duy nhất** người dùng biết mình sắp vượt hạn mức —
/// không có thông báo đẩy, không có chặn ghi. Một mốc lệch đi thì cảnh báo tới
/// muộn hoặc tới sai, và không có gì trên màn hình cho thấy điều đó.
///
/// Mốc do người dùng chốt ngày 2026-09-04: 70 / 90 / 100.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/widgets/budget_visuals.dart';

void main() {
  BudgetEntity nganSach({required double amount, required double spent}) {
    return BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'c1',
      amount: amount,
      spent: spent,
      startDate: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  group('budgetHealthOf — bốn mức theo tỉ lệ đã tiêu', () {
    test('chưa tiêu đồng nào là an toàn', () {
      expect(budgetHealthOf(nganSach(amount: 1000000, spent: 0)),
          BudgetHealth.safe);
    });

    test('dưới 70% vẫn an toàn', () {
      expect(budgetHealthOf(nganSach(amount: 1000000, spent: 699999)),
          BudgetHealth.safe);
    });

    test('đúng 70% chuyển sang cần chú ý', () {
      expect(
        budgetHealthOf(nganSach(amount: 1000000, spent: 700000)),
        BudgetHealth.caution,
        reason: 'Mốc 70 là biên ĐÓNG: chạm mốc là đổi màu. Để mở thì cảnh báo '
            'tới muộn hơn đúng một đồng so với con số người dùng đọc được.',
      );
    });

    test('dưới 90% vẫn ở mức cần chú ý', () {
      expect(budgetHealthOf(nganSach(amount: 1000000, spent: 899999)),
          BudgetHealth.caution);
    });

    test('đúng 90% chuyển sang nguy cấp', () {
      expect(budgetHealthOf(nganSach(amount: 1000000, spent: 900000)),
          BudgetHealth.critical);
    });

    test('tiêu hết đúng 100% vẫn là nguy cấp, chưa phải vượt', () {
      expect(
        budgetHealthOf(nganSach(amount: 1000000, spent: 1000000)),
        BudgetHealth.critical,
        reason: 'Tiêu vừa đủ hạn mức KHÔNG phải là vượt. Tô đỏ sẫm ở đây là nói '
            'sai với người dùng rằng họ đã tiêu lố.',
      );
    });

    test('quá 100% là đã vượt', () {
      expect(budgetHealthOf(nganSach(amount: 1000000, spent: 1000001)),
          BudgetHealth.over);
    });

    test('hạn mức 0 mà đã tiêu thì tính là vượt, không chia cho 0', () {
      expect(
        budgetHealthOf(nganSach(amount: 0, spent: 50000)),
        BudgetHealth.over,
        reason: 'Hạn mức 0 không tạo được từ form nhưng có thể kéo về từ '
            'backend. Chia cho 0 ra Infinity/NaN, và NaN so sánh với mọi mốc '
            'đều false nên sẽ lặng lẽ rơi vào nhánh "an toàn".',
      );
    });

    test('hạn mức 0 và chưa tiêu gì thì vẫn an toàn', () {
      expect(budgetHealthOf(nganSach(amount: 0, spent: 0)), BudgetHealth.safe);
    });
  });

  group('Màu của từng mức', () {
    test('bốn mức cho ra bốn màu khác nhau', () {
      final mau = BudgetHealth.values.map(budgetHealthColour).toSet();

      expect(
        mau.length,
        4,
        reason: 'Hai mức trùng màu thì người dùng không phân biệt được, và lỗi '
            'kiểu đó không làm test nào khác đỏ lên.',
      );
    });
  });
}
