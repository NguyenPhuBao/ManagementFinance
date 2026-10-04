/// Ngân sách hết hạn: khi nào, và kỳ nào được dùng để chốt số.
///
/// Vì sao cần: trước 2026-09-04 mọi ngân sách tạo từ form đều `recurrence:
/// true` và `endDate: null`, tức lặp vô hạn — **không cái nào hết hạn được**.
/// Tab "Đã hết hạn" vì thế sẽ luôn rỗng nếu ba nhánh dưới đây sai, và nó rỗng
/// một cách hợp lệ về mặt giao diện nên không ai phát hiện ra.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';

void main() {
  final batDau = DateTime(2026, 9, 1);

  BudgetEntity nganSach({
    bool recurrence = true,
    DateTime? endDate,
    DateTime? nextTimeRecurrence,
    String timeRecurrence = BudgetRecurrence.month,
    DateTime? startDate,
  }) {
    return BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'c1',
      amount: 5000000,
      startDate: startDate ?? batDau,
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      nextTimeRecurrence: nextTimeRecurrence,
      updatedAt: batDau,
    );
  }

  group('isExpired', () {
    test('lặp lại và không có ngày kết thúc thì không bao giờ hết hạn', () {
      final b = nganSach(recurrence: true);

      expect(
        b.isExpired(DateTime(2030, 1, 1)),
        isFalse,
        reason: 'Đây là cấu hình mặc định của mọi ngân sách hiện có. Nếu nhánh '
            'này trả về true thì toàn bộ ngân sách của người dùng rơi hết sang '
            'tab "Đã hết hạn" và họ mất quyền sửa/xoá chúng.',
      );
    });

    test('có ngày kết thúc và đã qua ngày đó thì hết hạn', () {
      final b = nganSach(endDate: DateTime(2026, 9, 30));

      expect(b.isExpired(DateTime(2026, 10, 1)), isTrue,
          reason: 'Ngày kết thúc là điều kiện hết hạn ưu tiên cao nhất.');
    });

    test('có ngày kết thúc nhưng chưa tới thì vẫn đang chạy', () {
      final b = nganSach(endDate: DateTime(2026, 9, 30));

      expect(b.isExpired(DateTime(2026, 9, 29)), isFalse);
    });

    test('đúng thời khắc ngày kết thúc đã tính là hết hạn', () {
      final b = nganSach(endDate: DateTime(2026, 9, 30));

      expect(
        b.isExpired(DateTime(2026, 9, 30)),
        isTrue,
        reason: 'Mốc kết thúc là biên MỞ: kỳ chạy tới trước thời khắc đó. Nếu '
            'tính là còn chạy thì ngân sách sống thêm một khoảnh khắc và kỳ kế '
            'tiếp bị lệch.',
      );
    });

    test('tắt lặp lại thì hết hạn ở cuối kỳ đầu tiên', () {
      final b = nganSach(
        recurrence: false,
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      expect(b.isExpired(DateTime(2026, 10, 6)), isTrue,
          reason: 'Anh đã chốt: tắt lặp lại mà bỏ trống ngày kết thúc thì ngân '
              'sách chạy đúng một chu kỳ rồi thôi.');
      expect(b.isExpired(DateTime(2026, 10, 4)), isFalse);
    });

    test('tắt lặp lại và chưa có mốc neo thì suy ra một chu kỳ từ ngày bắt đầu',
        () {
      final b = nganSach(recurrence: false);

      expect(
        b.isExpired(DateTime(2026, 10, 2)),
        isTrue,
        reason: 'Ngân sách cũ hoặc từ backend không có mốc neo. Không có nhánh '
            'dự phòng thì chúng thành bất tử và không bao giờ vào tab hết hạn.',
      );
    });

    test('có cả ngày kết thúc lẫn tắt lặp lại thì lấy mốc đến sớm hơn', () {
      final b = nganSach(
        recurrence: false,
        endDate: DateTime(2026, 9, 20),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      expect(
        b.isExpired(DateTime(2026, 9, 21)),
        isTrue,
        reason: 'Ngày kết thúc 20/9 tới trước cuối kỳ 5/10. Lấy mốc muộn hơn sẽ '
            'cho người dùng tiêu tiếp sau ngày họ tự đặt là hết.',
      );
    });
  });

  group('currentPeriod với mốc neo độc lập', () {
    test('kỳ đầu chạy từ ngày bắt đầu tới mốc neo — kỳ lẻ, ngắn hơn', () {
      final b = nganSach(
        startDate: DateTime(2026, 9, 15),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      final ky = b.currentPeriod(DateTime(2026, 9, 20));

      expect(ky.from, DateTime(2026, 9, 15));
      expect(ky.to, DateTime(2026, 10, 5),
          reason: 'Đây là điểm khác biệt của mốc neo độc lập: kỳ đầu không dài '
              'trọn một tháng.');
    });

    test('kỳ thứ ba nhảy từ mốc neo, không nhảy từ ngày bắt đầu', () {
      final b = nganSach(
        startDate: DateTime(2026, 9, 15),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      final ky = b.currentPeriod(DateTime(2026, 12, 10));

      expect(ky.from, DateTime(2026, 12, 5));
      expect(
        ky.to,
        DateTime(2027, 1, 5),
        reason: 'Nhảy từ ngày bắt đầu 15/9 sẽ ra kỳ 15/12–15/1, lệch 10 ngày so '
            'với mốc người dùng đã chọn. Giao dịch trong 10 ngày đó bị tính vào '
            'nhầm kỳ — sai âm thầm.',
      );
    });

    test('không có mốc neo thì chu kỳ neo vào ngày bắt đầu như trước', () {
      final b = nganSach(startDate: DateTime(2026, 9, 15));

      final ky = b.currentPeriod(DateTime(2026, 9, 20));

      expect(ky.from, DateTime(2026, 9, 15));
      expect(ky.to, DateTime(2026, 10, 15),
          reason: 'Ngân sách cũ không có mốc neo vẫn phải chạy y như cũ.');
    });

    test('ngân sách đã hết hạn chốt ở kỳ cuối, không trôi tiếp theo đồng hồ',
        () {
      final b = nganSach(
        recurrence: false,
        startDate: DateTime(2026, 9, 15),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      final ky = b.currentPeriod(DateTime(2027, 5, 1));

      expect(ky.from, DateTime(2026, 9, 15));
      expect(
        ky.to,
        DateTime(2026, 10, 5),
        reason: 'Tab "Đã hết hạn" hiển thị kết quả đã chốt. Nếu kỳ trôi theo '
            'đồng hồ thì số "đã chi" của một ngân sách chết vẫn tăng mỗi khi '
            'người dùng ghi giao dịch mới.',
      );
    });

    test('ngày kết thúc cắt ngắn kỳ cuối', () {
      final b = nganSach(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 20),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );

      final ky = b.currentPeriod(DateTime(2026, 12, 1));

      expect(ky.from, DateTime(2026, 11, 5));
      expect(
        ky.to,
        DateTime(2026, 11, 20),
        reason: 'Kỳ 5/11–5/12 bị ngày kết thúc 20/11 cắt lại. Không cắt thì '
            'giao dịch sau ngày người dùng đặt là hết vẫn bị tính vào.',
      );
    });

    test('ngân sách đặt cho tương lai vẫn cho khoảng rỗng, không đảo ngược', () {
      final b = nganSach(startDate: DateTime(2026, 12, 1));

      final ky = b.currentPeriod(DateTime(2026, 9, 20));

      expect(ky.to.isBefore(ky.from), isFalse,
          reason: 'Giữ nguyên bảo đảm cũ: khoảng cộng dồn rỗng chứ không quét '
              'ngược về quá khứ.');
    });
  });

  // G66: mốc neo (cuối kỳ đầu) là mốc ĐÃ KẸP — 31/01 + 1 tháng = 28/02. Nhảy
  // các kỳ sau từ nó thì lưới dính hẳn ở ngày 28: 28/03, 28/04… và giao dịch
  // ngày 29–31 của mỗi tháng rơi sang kỳ sau, im lặng.
  group('mocKy — lưới kỳ neo vào ngày bắt đầu, không vào mốc đã kẹp (G66)', () {
    List<DateTime> luoi(BudgetEntity b, int tu, int den) =>
        [for (var s = tu; s <= den; s++) b.mocKy(s)];

    test('⭐ tháng từ 31/01: tháng ngắn kẹp về ngày cuối, tháng sau QUAY LẠI 31', () {
      final b = nganSach(startDate: DateTime(2026, 1, 31));
      expect(luoi(b, 0, 5), [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
        DateTime(2026, 6, 30),
        DateTime(2026, 7, 31),
      ], reason: 'Nhảy từ mốc 28/02 đã kẹp là ra 28/03, 28/04… — người đặt '
          'ngân sách "ngày 31 hằng tháng" mất ba ngày cuối của mọi tháng.');
    });

    test('⭐ currentPeriod của ngân sách ngày 31 đi đúng lưới ấy', () {
      final b = nganSach(startDate: DateTime(2026, 1, 31));
      expect(b.currentPeriod(DateTime(2026, 3, 5)),
          (from: DateTime(2026, 2, 28), to: DateTime(2026, 3, 31)));
      expect(b.currentPeriod(DateTime(2026, 3, 30, 12)),
          (from: DateTime(2026, 2, 28), to: DateTime(2026, 3, 31)),
          reason: 'Khoản chi ngày 30/03 thuộc kỳ tháng 3, không phải kỳ sau.');
      expect(b.currentPeriod(DateTime(2026, 4, 10)),
          (from: DateTime(2026, 3, 31), to: DateTime(2026, 4, 30)));
    });

    test('ngày 30 và 29: tháng Hai năm thường, năm nhuận, năm 2100', () {
      expect(luoi(nganSach(startDate: DateTime(2027, 1, 30)), 0, 2),
          [DateTime(2027, 2, 28), DateTime(2027, 3, 30), DateTime(2027, 4, 30)]);
      expect(luoi(nganSach(startDate: DateTime(2027, 1, 29)), 0, 1),
          [DateTime(2027, 2, 28), DateTime(2027, 3, 29)]);
      expect(luoi(nganSach(startDate: DateTime(2028, 1, 29)), 0, 1),
          [DateTime(2028, 2, 29), DateTime(2028, 3, 29)],
          reason: '2028 nhuận: tháng Hai có ngày 29, không kẹp.');
      expect(luoi(nganSach(startDate: DateTime(2100, 1, 31)), 0, 1),
          [DateTime(2100, 2, 28), DateTime(2100, 3, 31)],
          reason: '2100 chia hết cho 100 mà không cho 400 — KHÔNG nhuận.');
    });

    test('quý từ 30/11: kẹp ở 28/02, các quý sau về lại ngày 30', () {
      final b = nganSach(
        startDate: DateTime(2026, 11, 30),
        timeRecurrence: BudgetRecurrence.quarter,
      );
      expect(luoi(b, 0, 3), [
        DateTime(2027, 2, 28),
        DateTime(2027, 5, 30),
        DateTime(2027, 8, 30),
        DateTime(2027, 11, 30),
      ]);
    });

    test('năm từ 29/02: kẹp 28/02 ba năm thường, về 29/02 ở năm nhuận kế', () {
      final b = nganSach(
        startDate: DateTime(2028, 2, 29),
        timeRecurrence: BudgetRecurrence.year,
      );
      expect(luoi(b, 0, 3), [
        DateTime(2029, 2, 28),
        DateTime(2030, 2, 28),
        DateTime(2031, 2, 28),
        DateTime(2032, 2, 29),
      ]);
    });

    test('s âm lùi về trước ngày bắt đầu trên cùng lưới; mocKy(-1) là ngày bắt đầu',
        () {
      final b = nganSach(startDate: DateTime(2026, 1, 31));
      expect(luoi(b, -3, -1), [
        DateTime(2025, 11, 30),
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 31),
      ]);
    });

    test('tuần: bảy ngày một mốc, như cũ', () {
      final b = nganSach(
        startDate: DateTime(2026, 9, 7),
        timeRecurrence: BudgetRecurrence.week,
      );
      expect(luoi(b, -1, 2), [
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
      ]);
    });

    test('có nextTimeRecurrence: lưới neo vào nó, mocKy(0) đúng là nó', () {
      final b = nganSach(
        startDate: DateTime(2026, 9, 15),
        nextTimeRecurrence: DateTime(2026, 10, 5),
      );
      expect(luoi(b, -1, 2), [
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
        DateTime(2026, 11, 5),
        DateTime(2026, 12, 5),
      ]);
    });

    test('mocKy(0) là cuối kỳ đầu — ngân sách không lặp hết hạn đúng ở đó', () {
      final b = nganSach(recurrence: false, startDate: DateTime(2026, 1, 31));
      expect(b.mocKy(0), DateTime(2026, 2, 28));
      expect(b.expiresAt, b.mocKy(0));
    });
  });
}
