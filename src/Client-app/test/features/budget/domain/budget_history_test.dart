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
    DateTime? nextTimeRecurrence,
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
      nextTimeRecurrence: nextTimeRecurrence,
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

  test('các kỳ liền nhau: `to` kỳ trước bằng `from` kỳ sau — và đúng NGÀY', () {
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
    // Chỉ kiểm "liền nhau" thì lưới trôi về ngày 28 vẫn xanh (G66): mọi kỳ
    // vẫn khít nhau, chỉ là khít nhau ở sai ngày.
    expect(ky.map((k) => k.from).toList(), [
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 31),
    ]);
    expect(ky.last.to, DateTime(2026, 6, 30));
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

  group('kyDaDongTruoc — kỳ đã đóng cho phép học nhịp chi (dự án C)', () {
    test('⭐ lùi cả về TRƯỚC ngày bắt đầu, cũ trước mới sau, không gồm kỳ hiện tại', () {
      final b = nganSach(start: DateTime(2026, 10, 1));
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 11, 6, 12), mocDauTien: DateTime(2026, 8, 1), toiDa: 6);
      expect(ky, [
        (from: DateTime(2026, 8, 1), to: DateTime(2026, 9, 1)),
        (from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
        (from: DateTime(2026, 10, 1), to: DateTime(2026, 11, 1)),
      ], reason: 'Ngân sách tạo 01/10 nhưng danh mục đã có giao dịch từ 01/08 — học được ngay '
          '(spec quyết định 4). Kỳ 11 đang chạy, không bao giờ là mẫu.');
    });

    test('kỳ bắt đầu TRƯỚC giao dịch đầu tiên bị bỏ — thiếu dữ liệu, không phải "không chi"', () {
      final b = nganSach(start: DateTime(2026, 10, 1));
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 11, 6, 12), mocDauTien: DateTime(2026, 8, 2), toiDa: 6);
      expect(ky.map((k) => k.from), [DateTime(2026, 9, 1), DateTime(2026, 10, 1)]);
    });

    test('tối đa toiDa kỳ, lấy các kỳ GẦN nhất', () {
      final b = nganSach(start: DateTime(2026, 10, 1));
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 11, 6, 12), mocDauTien: DateTime(2025, 1, 1), toiDa: 6);
      expect(ky.length, 6);
      expect(ky.first.from, DateTime(2026, 5, 1));
      expect(ky.last.to, DateTime(2026, 11, 1));
    });

    test('⭐ sau ngày bắt đầu trùng khít recentPeriods (trừ kỳ hiện tại) — hai phép cắt không lệch', () {
      final b = nganSach(start: DateTime(2026, 1, 1));
      final now = DateTime(2026, 9, 15);
      final ky = kyDaDongTruoc(b, now: now, mocDauTien: DateTime(2025, 1, 1), toiDa: 6);
      expect(ky, recentPeriods(b, count: 7, now: now).sublist(0, 6));
    });

    test('⭐ ngân sách bắt đầu ngày 31: kỳ đã đóng sau kỳ đầu trùng recentPeriods — CÙNG lưới mocKy (canh G66)', () {
      final b = nganSach(start: DateTime(2026, 1, 31));
      final now = DateTime(2026, 6, 10);
      final ky = kyDaDongTruoc(b, now: now, mocDauTien: DateTime(2026, 2, 1), toiDa: 6);
      final lichSu = recentPeriods(b, count: 6, now: now);
      // Kỳ đầu [31/1, …) bắt đầu trước giao dịch đầu tiên; mọi kỳ đã đóng sau nó phải trùng.
      expect(ky, lichSu.sublist(1, lichSu.length - 1),
          reason: 'Sửa lưới ở currentPeriod mà kyDaDongTruoc không theo thì ca này đỏ.');
      expect(ky.map((k) => k.from),
          [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
    });

    test('"Ngày cụ thể" → rỗng (không có lưới để lùi)', () {
      final b = nganSach(
          start: DateTime(2026, 9, 1), timeRecurrence: null, endDate: DateTime(2026, 12, 1));
      expect(kyDaDongTruoc(b, now: DateTime(2026, 11, 6), mocDauTien: DateTime(2025, 1, 1), toiDa: 6), isEmpty);
    });

    test('chưa có giao dịch nào (mocDauTien null) → rỗng', () {
      final b = nganSach(start: DateTime(2026, 9, 1));
      expect(kyDaDongTruoc(b, now: DateTime(2026, 11, 6), mocDauTien: null, toiDa: 6), isEmpty);
    });

    test('kỳ đầu (chưa qua mốc neo) lùi về các kỳ trước ngày bắt đầu', () {
      final b = nganSach(start: DateTime(2026, 9, 1));
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 9, 15), mocDauTien: DateTime(2026, 7, 1), toiDa: 6);
      expect(ky.map((k) => k.from), [DateTime(2026, 7, 1), DateTime(2026, 8, 1)]);
    });

    test('chu kỳ tuần: kỳ 7 ngày liền nhau', () {
      final b = nganSach(start: DateTime(2026, 9, 7), timeRecurrence: BudgetRecurrence.week);
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 10, 1), mocDauTien: DateTime(2026, 9, 1), toiDa: 6);
      expect(ky.map((k) => k.from),
          [DateTime(2026, 9, 7), DateTime(2026, 9, 14), DateTime(2026, 9, 21)],
          reason: 'Kỳ 31/08 bắt đầu trước giao dịch đầu tiên 01/09 nên bị bỏ; kỳ 28/09 đang chạy.');
      for (final k in ky) {
        expect(k.to.difference(k.from).inDays, 7);
      }
    });

    test('chu kỳ quý và năm', () {
      final quy = nganSach(start: DateTime(2026, 1, 1), timeRecurrence: BudgetRecurrence.quarter);
      final kq = kyDaDongTruoc(quy,
          now: DateTime(2026, 10, 15), mocDauTien: DateTime(2025, 1, 1), toiDa: 6);
      expect(kq.length, 6);
      expect(kq.first, (from: DateTime(2025, 4, 1), to: DateTime(2025, 7, 1)));
      expect(kq.last, (from: DateTime(2026, 7, 1), to: DateTime(2026, 10, 1)));

      final nam = nganSach(start: DateTime(2026, 1, 1), timeRecurrence: BudgetRecurrence.year);
      final kn = kyDaDongTruoc(nam,
          now: DateTime(2026, 5, 1), mocDauTien: DateTime(2023, 3, 1), toiDa: 6);
      expect(kn.map((k) => k.from), [DateTime(2024, 1, 1), DateTime(2025, 1, 1)],
          reason: 'Kỳ 2023 bắt đầu trước giao dịch đầu tiên (01/03/2023) nên bị bỏ.');
    });

    test('tháng Hai: năm nhuận 29 ngày, năm thường 28, 2100 KHÔNG nhuận', () {
      final b = nganSach(start: DateTime(2028, 3, 1));
      final ky = kyDaDongTruoc(b,
          now: DateTime(2028, 3, 10), mocDauTien: DateTime(2027, 1, 1), toiDa: 14);
      Duration doDai(DateTime from) => ky.firstWhere((k) => k.from == from).to.difference(from);
      expect(doDai(DateTime(2028, 2, 1)).inDays, 29);
      expect(doDai(DateTime(2027, 2, 1)).inDays, 28);

      final theKy = nganSach(start: DateTime(2100, 3, 1));
      final k2100 = kyDaDongTruoc(theKy,
          now: DateTime(2100, 3, 10), mocDauTien: DateTime(2099, 12, 1), toiDa: 6);
      expect(k2100.last, (from: DateTime(2100, 2, 1), to: DateTime(2100, 3, 1)));
      expect(k2100.last.to.difference(k2100.last.from).inDays, 28);
    });

    test('nextTimeRecurrence khác chuẩn (hàng kéo về): lưới theo mốc neo, không theo ngày bắt đầu', () {
      final b = nganSach(
        start: DateTime(2026, 9, 15),
        nextTimeRecurrence: DateTime(2026, 10, 1),
      );
      final ky = kyDaDongTruoc(b,
          now: DateTime(2026, 11, 10), mocDauTien: DateTime(2026, 8, 1), toiDa: 6);
      expect(ky.map((k) => k.from),
          [DateTime(2026, 8, 1), DateTime(2026, 9, 1), DateTime(2026, 10, 1)]);
    });
  });
}
