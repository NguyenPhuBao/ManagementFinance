/// Số học chu kỳ ngân sách: nhảy đúng một kỳ, và kẹp ngày ở tháng ngắn.
///
/// Vì sao cần: trước đây chu kỳ luôn neo vào chính ngày người dùng chọn làm
/// ngày bắt đầu, nên `DateTime(year, month + 1, day)` không bao giờ gặp ngày
/// không tồn tại. Khi cho chọn mốc riêng ("ngày 31 hàng tháng") thì tháng Hai
/// không có ngày đó, và Dart **tràn sang tháng sau** thay vì báo lỗi — kỳ tháng
/// Hai biến mất mà không có exception nào. Đó là lớp lỗi im lặng mà bộ test
/// này canh chừng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/models/budget_period.dart';

void main() {
  group('advancePeriod — nhảy đúng một chu kỳ', () {
    test('tuần: cộng 7 ngày', () {
      expect(
        advancePeriod(DateTime(2026, 9, 4), BudgetRecurrence.week),
        DateTime(2026, 9, 11),
        reason: 'Chu kỳ tuần phải nhảy đúng 7 ngày, không phụ thuộc độ dài '
            'tháng.',
      );
    });

    test('tháng: sang cùng ngày của tháng kế tiếp', () {
      expect(
        advancePeriod(DateTime(2026, 9, 5), BudgetRecurrence.month),
        DateTime(2026, 10, 5),
        reason: 'Mốc "ngày 5 hàng tháng" phải giữ nguyên ngày 5.',
      );
    });

    test('quý: cộng 3 tháng', () {
      expect(
        advancePeriod(DateTime(2026, 1, 5), BudgetRecurrence.quarter),
        DateTime(2026, 4, 5),
        reason: 'Chu kỳ quý neo vào tháng đầu quý: 5/1 → 5/4 → 5/7 → 5/10.',
      );
    });

    test('năm: cộng 1 năm', () {
      expect(
        advancePeriod(DateTime(2026, 3, 5), BudgetRecurrence.year),
        DateTime(2027, 3, 5),
        reason: 'Chu kỳ năm giữ nguyên ngày và tháng.',
      );
    });

    test('tháng ngắn: ngày 31 lùi về ngày cuối tháng, KHÔNG tràn sang tháng sau',
        () {
      expect(
        advancePeriod(DateTime(2026, 1, 31), BudgetRecurrence.month),
        DateTime(2026, 2, 28),
        reason: 'DateTime(2026, 2, 31) trong Dart tràn thành 03/03/2026. Nếu '
            'để tràn thì kỳ tháng Hai biến mất và mọi giao dịch trong tháng đó '
            'rơi ra ngoài mọi kỳ — sai âm thầm, không exception.',
      );
    });

    test('tháng 2 NĂM NHUẬN nhận đủ ngày 29, không bị kẹp xuống 28', () {
      expect(
        advancePeriod(DateTime(2028, 1, 31), BudgetRecurrence.month),
        DateTime(2028, 2, 29),
        reason: '2028 là năm nhuận nên tháng Hai có 29 ngày. Kẹp cứng về 28 sẽ '
            'làm ngân sách chốt sớm một ngày, và khoản chi ghi đúng ngày 29 rơi '
            'ra ngoài mọi kỳ — không test nào khác bắt được, vì hai test tháng '
            'Hai còn lại đều dùng năm thường.',
      );
    });

    test('ngày 29 vào tháng 2 năm nhuận thì giữ nguyên, không phải kẹp', () {
      expect(
        advancePeriod(DateTime(2028, 1, 29), BudgetRecurrence.month),
        DateTime(2028, 2, 29),
        reason: 'Ngày 29 tồn tại trong tháng Hai năm nhuận nên phép kẹp không '
            'được đụng tới nó.',
      );
    });

    test('năm nhuận thế kỷ: 2100 KHÔNG nhuận nên vẫn kẹp về 28', () {
      expect(
        advancePeriod(DateTime(2100, 1, 31), BudgetRecurrence.month),
        DateTime(2100, 2, 28),
        reason: 'Luật nhuận không phải "chia hết cho 4": năm chia hết 100 mà '
            'không chia hết 400 thì KHÔNG nhuận. Tự viết phép tính nhuận rất dễ '
            'sai chỗ này — test cắm mốc để không ai thay lịch của Dart bằng một '
            'công thức tay.',
      );
    });

    test('năm nhuận chia hết 400: 2000 CÓ nhuận', () {
      expect(
        advancePeriod(DateTime(2000, 1, 31), BudgetRecurrence.month),
        DateTime(2000, 2, 29),
        reason: 'Vế còn lại của luật nhuận thế kỷ.',
      );
    });

    test('chu kỳ quý nhảy vào tháng 2 năm nhuận cũng nhận đủ 29', () {
      expect(
        advancePeriod(DateTime(2027, 11, 30), BudgetRecurrence.quarter),
        DateTime(2028, 2, 29),
        reason: 'Nhánh quý dùng chung phép kẹp nhưng đi qua đường tính tháng '
            'khác (+3). Không có test riêng thì một thay đổi ở nhánh đó lọt.',
      );
    });

    test('năm nhuận: ngày 29/2 của năm thường lùi về 28/2', () {
      expect(
        advancePeriod(DateTime(2028, 2, 29), BudgetRecurrence.year),
        DateTime(2029, 2, 28),
        reason: 'DateTime(2029, 2, 29) tràn thành 01/03. Mốc 29/2 chỉ tồn tại '
            'ở năm nhuận nên phải kẹp lại thay vì trượt sang tháng Ba.',
      );
    });

    test('kẹp ngày KHÔNG làm mất mốc gốc ở kỳ sau', () {
      // 31/1 → 28/2 (kẹp) → nếu nhảy tiếp từ 28/2 thì ra 28/3, mất mốc "ngày
      // 31". Phép nhảy phải luôn xuất phát từ mốc gốc, không từ kết quả đã kẹp.
      final kyHai = advancePeriodFrom(
        anchor: DateTime(2026, 1, 31),
        steps: 2,
        timeRecurrence: BudgetRecurrence.month,
      );
      expect(
        kyHai,
        DateTime(2026, 3, 31),
        reason: 'Người đặt "ngày 31 hàng tháng" mong tháng Ba vẫn rơi vào ngày '
            '31. Nhảy dồn từ kết quả đã kẹp sẽ tụt dần về ngày 28 và không bao '
            'giờ quay lại.',
      );
    });
  });
}
