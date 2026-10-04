/// Nhịp chi của một ngân sách: nên chi mỗi ngày, còn bao nhiêu ngày, và đang
/// nhanh hay chậm so với thời gian đã trôi.
///
/// Vì sao cần: "Còn 2.900.000đ" không nói gì về việc con số ấy phải kéo dài
/// bao lâu. Mọi app cùng loại (Money Lover, MISA, Spendee) đều quy nó ra
/// "nên chi/ngày". Phép chia này sai âm thầm ở tháng ngắn và năm nhuận, nên
/// test phủ cả hai.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';

import 'nhip_chi_mau.dart';

void main() {
  BudgetEntity nganSach({
    required DateTime start,
    double amount = 3000000,
    double spent = 0,
    String? timeRecurrence = BudgetRecurrence.month,
    DateTime? endDate,
    bool recurrence = true,
  }) {
    return BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'c1',
      amount: amount,
      spent: spent,
      startDate: start,
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      updatedAt: start,
    );
  }

  group('số ngày', () {
    test('tháng 30 ngày, giữa kỳ: còn lại đếm cả ngày hôm nay', () {
      final b = nganSach(start: DateTime(2026, 9, 1), spent: 1000000);
      final pace = budgetPaceOf(b, DateTime(2026, 9, 15, 12));

      expect(pace.daysTotal, 30);
      expect(
        pace.daysLeft,
        16,
        reason: '15/9 trưa tới 1/10 là 15,5 ngày → làm tròn LÊN thành 16, vì '
            'hôm nay vẫn còn nửa ngày để tiêu. Làm tròn xuống là mất một ngày.',
      );
      expect(
        pace.suggestedPerDay,
        closeTo(125000, 0.01),
        reason: 'Còn 2.000.000 chia đều cho 16 ngày.',
      );
    });

    test('tháng Hai năm nhuận có 29 ngày', () {
      final b = nganSach(start: DateTime(2028, 2, 1));
      expect(budgetPaceOf(b, DateTime(2028, 2, 1)).daysTotal, 29);
    });

    test('tháng Hai năm thường có 28 ngày', () {
      final b = nganSach(start: DateTime(2027, 2, 1));
      expect(budgetPaceOf(b, DateTime(2027, 2, 1)).daysTotal, 28);
    });

    test('ngân sách bắt đầu ngày 31 bị kẹp về cuối tháng Hai', () {
      final b = nganSach(start: DateTime(2026, 1, 31));
      final pace = budgetPaceOf(b, DateTime(2026, 2, 10));
      expect(
        pace.daysTotal,
        28,
        reason: '31/1 → 28/2: `advancePeriod` kẹp ngày 31 về ngày cuối tháng, '
            'nhịp chi phải dùng đúng kỳ ấy chứ không tự tính 30 hay 31.',
      );
    });

    test('chu kỳ tuần có 7 ngày', () {
      final b = nganSach(
        start: DateTime(2026, 9, 7),
        timeRecurrence: BudgetRecurrence.week,
      );
      expect(budgetPaceOf(b, DateTime(2026, 9, 9)).daysTotal, 7);
    });

    test('"Ngày cụ thể" dùng ngày kết thúc người dùng đặt', () {
      final b = nganSach(
        start: DateTime(2026, 9, 1),
        timeRecurrence: null,
        endDate: DateTime(2026, 9, 11),
        recurrence: false,
      );
      expect(budgetPaceOf(b, DateTime(2026, 9, 1)).daysTotal, 10);
    });

    test('ngày cuối kỳ vẫn còn 1 ngày, không phải 0', () {
      final b = nganSach(start: DateTime(2026, 9, 1));
      expect(
        budgetPaceOf(b, DateTime(2026, 9, 30, 23)).daysLeft,
        1,
        reason: 'Chia cho 0 ngày là vô cực; người dùng vẫn còn hôm nay.',
      );
    });

    test('đã hết hạn thì còn 0 ngày và không gợi ý gì', () {
      final b = nganSach(
        start: DateTime(2026, 9, 1),
        recurrence: false,
        spent: 500000,
      );
      final pace = budgetPaceOf(b, DateTime(2026, 10, 5));
      expect(pace.daysLeft, 0);
      expect(pace.suggestedPerDay, 0);
    });
  });

  group('nên chi mỗi ngày', () {
    test('đã vượt hạn mức thì gợi ý 0, không âm', () {
      final b = nganSach(start: DateTime(2026, 9, 1), spent: 3500000);
      expect(budgetPaceOf(b, DateTime(2026, 9, 10)).suggestedPerDay, 0);
    });
  });

  group('nhịp chi', () {
    test('tiêu đúng tỉ lệ thời gian đã trôi là đúng nhịp', () {
      // Nửa kỳ, nửa hạn mức.
      final b = nganSach(start: DateTime(2026, 9, 1), spent: 1500000);
      expect(
        budgetPaceOf(b, DateTime(2026, 9, 16)).status,
        BudgetPaceStatus.onTrack,
      );
    });

    test('tiêu nhiều hơn hẳn thời gian đã trôi là nhanh', () {
      final b = nganSach(start: DateTime(2026, 9, 1), spent: 2100000);
      final pace = budgetPaceOf(b, DateTime(2026, 9, 10));
      expect(pace.status, BudgetPaceStatus.fast);
      expect(
        pace.expectedSpent,
        closeTo(900000, 1),
        reason: '9 ngày trên 30 → đáng lẽ mới tiêu 30% = 900.000.',
      );
    });

    test('tiêu ít hơn hẳn thời gian đã trôi là chậm', () {
      final b = nganSach(start: DateTime(2026, 9, 1), spent: 200000);
      expect(
        budgetPaceOf(b, DateTime(2026, 9, 25)).status,
        BudgetPaceStatus.slow,
      );
    });

    test('ngân sách chưa tới ngày bắt đầu không chia cho 0', () {
      final b = nganSach(start: DateTime(2026, 10, 1));
      final pace = budgetPaceOf(b, DateTime(2026, 9, 20));
      expect(pace.daysTotal, 0);
      expect(pace.daysLeft, 0);
      expect(pace.suggestedPerDay, 0);
      expect(pace.status, BudgetPaceStatus.onTrack);
    });
  });

  group('nhịp riêng (dự án C việc hai)', () {
    // Nhà ở 5.000.000, đã chi 4.200.000 lúc trưa 06/11 (spec mục 1.2 / 3.3).
    final nhaO = nganSach(
        start: DateTime(2026, 8, 1), amount: 5000000, spent: 4200000);

    test('⭐ không nhịp → từng con số y như trước (giả định chi đều)', () {
      final p = budgetPaceOf(nhaO, mocMau);
      expect(p.theoNhipRieng, isFalse);
      expect(p.phanThoiGian, closeTo(5.5 / 30, 1e-9));
      expect(p.expectedSpent, closeTo(5000000 * 5.5 / 30, 1e-6));
      expect(p.status, BudgetPaceStatus.fast,
          reason: 'Đây là báo động oan hôm nay: tiền nhà trả ngày 1 nên 84 % '
              'vào ngày 6 là bình thường.');
    });

    test('⭐ có nhịp: đáng lẽ đã chi = hạn mức × phần mọi khi; chip theo nhịp → đúng nhịp',
        () {
      final p = budgetPaceOf(nhaO, mocMau, nhipChi: nhipNhaO());
      expect(p.theoNhipRieng, isTrue);
      expect(p.expectedSpent, closeTo(5000000 * 4000000 / 4600000, 1e-6));
      expect(p.status, BudgetPaceStatus.onTrack,
          reason: '0,84 so với 0,8696 — lệch 3 điểm, trong biên ±5.');
    });

    test('nhịp KHÔNG đổi số ngày, nên chi mỗi ngày, phần thời gian', () {
      final a = budgetPaceOf(nhaO, mocMau);
      final b = budgetPaceOf(nhaO, mocMau, nhipChi: nhipNhaO());
      expect(b.daysTotal, a.daysTotal);
      expect(b.daysLeft, a.daysLeft);
      expect(b.suggestedPerDay, a.suggestedPerDay);
      expect(b.phanThoiGian, a.phanThoiGian);
    });

    test('chi nhanh hơn mọi khi vẫn là nhanh — Ăn uống 70 % ngày 6', () {
      final anUong = nganSach(
          start: DateTime(2026, 8, 1), amount: 3000000, spent: 2100000);
      expect(budgetPaceOf(anUong, mocMau, nhipChi: nhipAnUong()).status,
          BudgetPaceStatus.fast);
    });

    test('kỳ rỗng (chưa tới ngày bắt đầu) → empty kể cả khi có nhịp', () {
      final chuaToi = nganSach(start: DateTime(2026, 12, 1));
      final p = budgetPaceOf(chuaToi, mocMau, nhipChi: nhipNhaO());
      expect(p.daysTotal, 0);
      expect(p.theoNhipRieng, isFalse);
    });
  });
}
