/// Một khoản chi sắp ghi sẽ làm ngân sách của danh mục ấy ra sao.
///
/// Vì sao cần: lựa chọn "Chặn" (`OverSpending = Stop`) tồn tại trên form từ
/// 2026-09-03 nhưng không nơi nào đọc nó — người dùng chọn, bấm Lưu, không có
/// gì khác. Phép tính này là nền cho hộp thoại xác nhận và cho lời báo sau khi
/// lưu, nên nó phải đúng cả ở chế độ sửa (khoản cũ đã nằm trong số đã chi).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_impact.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);

  BudgetView view({
    double amount = 3000000,
    double spent = 1000000,
    String overSpending = BudgetOverSpending.over,
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c1',
        amount: amount,
        spent: spent,
        overSpending: overSpending,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        updatedAt: now,
      ),
      categoryName: 'Ăn uống',
    );
  }

  group('budgetImpactOf', () {
    test('không có ngân sách thì không có tác động', () {
      expect(
        budgetImpactOf(
            view: null, amount: 100, date: now, now: now),
        isNull,
      );
    });

    test('khoản ghi ngoài kỳ hiện tại thì không tính', () {
      final impact = budgetImpactOf(
        view: view(),
        amount: 100,
        date: DateTime(2026, 8, 20),
        now: now,
      );
      expect(impact, isNull,
          reason: 'Khoản ghi lùi ngày sang tháng trước không đụng kỳ đang '
              'chạy; cảnh báo ở đó là sai.');
    });

    test('còn lại sau khi ghi = hạn mức − (đã chi + khoản mới)', () {
      final impact = budgetImpactOf(
        view: view(),
        amount: 500000,
        date: now,
        now: now,
      )!;
      expect(impact.remainingAfter, 1500000);
      expect(impact.exceeds, isFalse);
      expect(impact.exceedsBy, 0);
    });

    test('vượt thì cho biết vượt bao nhiêu', () {
      final impact = budgetImpactOf(
        view: view(spent: 2800000),
        amount: 500000,
        date: now,
        now: now,
      )!;
      expect(impact.exceeds, isTrue);
      expect(impact.exceedsBy, 300000);
    });

    test('sửa khoản cũ: trừ số cũ ra trước khi cộng số mới', () {
      final impact = budgetImpactOf(
        view: view(spent: 2800000),
        amount: 500000,
        previousAmount: 400000,
        date: now,
        now: now,
      )!;
      expect(impact.exceeds, isFalse,
          reason: 'Số đã chi 2,8 triệu ĐÃ gồm 400k của khoản đang sửa. Không '
              'trừ ra là báo vượt oan mỗi lần người dùng sửa một khoản lớn.');
      expect(impact.remainingAfter, 100000);
    });

    test('sắp hết dùng đúng ngưỡng cảnh báo của ngân sách', () {
      final impact = budgetImpactOf(
        view: view(spent: 2500000),
        amount: 300000,
        date: now,
        now: now,
      )!;
      expect(impact.nearLimitAfter, isTrue,
          reason: '2,8/3 = 93% ≥ mốc mặc định 90% của `isNearLimit`.');
    });

    test('requiresConfirmation chỉ khi ngân sách đặt Chặn VÀ khoản làm vượt',
        () {
      BudgetImpact tinh(String mode, double spent) => budgetImpactOf(
            view: view(spent: spent, overSpending: mode),
            amount: 500000,
            date: now,
            now: now,
          )!;

      expect(tinh(BudgetOverSpending.stop, 2800000).requiresConfirmation, isTrue);
      expect(tinh(BudgetOverSpending.stop, 1000000).requiresConfirmation,
          isFalse);
      expect(tinh(BudgetOverSpending.over, 2800000).requiresConfirmation,
          isFalse,
          reason: '"Cảnh báo" nghĩa là ghi luôn rồi báo, không hỏi.');
    });
  });

  group('lời báo', () {
    test('snackbar sau khi lưu: chung chung, không có con số', () {
      final vuot = budgetImpactOf(
          view: view(spent: 2800000), amount: 500000, date: now, now: now)!;
      final sapHet = budgetImpactOf(
          view: view(spent: 2500000), amount: 300000, date: now, now: now)!;
      final binhThuong = budgetImpactOf(
          view: view(), amount: 100, date: now, now: now)!;

      expect(budgetImpactSnackText(vuot), contains('vượt'));
      expect(budgetImpactSnackText(sapHet), contains('sắp hết'));
      expect(budgetImpactSnackText(binhThuong), isNull,
          reason: 'Không có gì đáng nói thì giữ lời nhắn mặc định của form.');
      for (final s in [budgetImpactSnackText(vuot), budgetImpactSnackText(sapHet)]) {
        expect(s, isNot(matches(RegExp(r'\d'))),
            reason: 'Người dùng muốn banner tạm thời tối giản, không nêu số '
                'liệu — con số nằm ở trang ngân sách.');
      }
    });

    test('hộp thoại xác nhận nêu rõ vượt bao nhiêu', () {
      final vuot = budgetImpactOf(
          view: view(spent: 2800000, overSpending: BudgetOverSpending.stop),
          amount: 500000,
          date: now,
          now: now)!;

      final text = budgetImpactDialogText(vuot);
      expect(text, contains('Ăn uống'));
      expect(text, contains('300.000'));
    });
  });
}
