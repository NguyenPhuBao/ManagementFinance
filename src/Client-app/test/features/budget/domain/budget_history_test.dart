/// Các kỳ đã qua của một ngân sách lặp — nguồn của biểu đồ lịch sử.
///
/// Vì sao cần: tab "Đã hết hạn" chỉ giữ ngân sách đã chết; ngân sách lặp hàng
/// tháng thì không có chỗ nào cho thấy tháng trước tiêu bao nhiêu. Việc cắt kỳ
/// phải khớp **từng mốc** với `currentPeriod`, nếu không một giao dịch có thể
/// rơi vào hai kỳ hoặc không kỳ nào — sai âm thầm.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';

void main() {
  BudgetEntity nganSach({
    required DateTime start,
    String? timeRecurrence = BudgetRecurrence.month,
    DateTime? endDate,
    bool recurrence = true,
  }) {
    return BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'c1',
      amount: 1000000,
      startDate: start,
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      updatedAt: start,
    );
  }

  test('trả tối đa [count] kỳ, cũ trước mới sau, kỳ cuối là kỳ hiện tại', () {
    final b = nganSach(start: DateTime(2026, 1, 1));
    final ky = recentPeriods(b, count: 6, now: DateTime(2026, 9, 15));

    expect(ky.length, 6);
    expect(ky.first.from, DateTime(2026, 4, 1));
    expect(ky.first.to, DateTime(2026, 5, 1));
    expect(ky.last.from, DateTime(2026, 9, 1));
    expect(ky.last.to, DateTime(2026, 10, 1));
  });

  test('không lùi quá ngày bắt đầu', () {
    final b = nganSach(start: DateTime(2026, 7, 1));
    final ky = recentPeriods(b, count: 6, now: DateTime(2026, 9, 15));

    expect(
      ky.map((k) => k.from).toList(),
      [DateTime(2026, 7, 1), DateTime(2026, 8, 1), DateTime(2026, 9, 1)],
      reason: 'Trước tháng 7 ngân sách chưa tồn tại; vẽ cột 0 cho những tháng '
          'ấy là bịa ra lịch sử.',
    );
  });

  test('các kỳ liền nhau: `to` kỳ trước bằng `from` kỳ sau', () {
    // Ngày 31 là chỗ hay hở: `advancePeriod` kẹp về 28/2 rồi nhảy tiếp.
    final b = nganSach(start: DateTime(2026, 1, 31));
    final ky = recentPeriods(b, count: 6, now: DateTime(2026, 6, 10));

    for (var i = 1; i < ky.length; i++) {
      expect(
        ky[i].from,
        ky[i - 1].to,
        reason: 'Hở hoặc chồng giữa hai kỳ là có giao dịch bị đếm 0 hoặc 2 '
            'lần.',
      );
    }
  });

  test('kỳ cuối trùng khớp với currentPeriod', () {
    final b = nganSach(start: DateTime(2026, 1, 31));
    final now = DateTime(2026, 6, 10);
    final ky = recentPeriods(b, count: 6, now: now);
    final hienTai = b.currentPeriod(now);

    expect(ky.last.from, hienTai.from);
    expect(ky.last.to, hienTai.to);
  });

  test('tháng Hai năm nhuận là một kỳ 29 ngày', () {
    final b = nganSach(start: DateTime(2028, 1, 1));
    final ky = recentPeriods(b, count: 3, now: DateTime(2028, 3, 15));

    final thangHai = ky[1];
    expect(thangHai.from, DateTime(2028, 2, 1));
    expect(thangHai.to, DateTime(2028, 3, 1));
    expect(thangHai.to.difference(thangHai.from).inDays, 29);
  });

  test('"Ngày cụ thể" chỉ có đúng một kỳ', () {
    final b = nganSach(
      start: DateTime(2026, 9, 1),
      timeRecurrence: null,
      endDate: DateTime(2026, 9, 20),
      recurrence: false,
    );
    final ky = recentPeriods(b, count: 6, now: DateTime(2026, 9, 10));

    expect(ky.length, 1);
    expect(ky.single.from, DateTime(2026, 9, 1));
    expect(ky.single.to, DateTime(2026, 9, 20));
  });

  test('ngân sách hết hạn dừng ở kỳ cuối, không trôi theo đồng hồ', () {
    final b = nganSach(
      start: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 6, 1),
    );
    final ky = recentPeriods(b, count: 6, now: DateTime(2026, 9, 15));

    expect(ky.length, 3);
    expect(ky.last.to, DateTime(2026, 6, 1));
  });

  test('chưa tới ngày bắt đầu thì không có kỳ nào', () {
    final b = nganSach(start: DateTime(2026, 10, 1));
    expect(recentPeriods(b, count: 6, now: DateTime(2026, 9, 15)), isEmpty);
  });
}
