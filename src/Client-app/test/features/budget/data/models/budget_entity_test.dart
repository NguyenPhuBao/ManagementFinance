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
}
