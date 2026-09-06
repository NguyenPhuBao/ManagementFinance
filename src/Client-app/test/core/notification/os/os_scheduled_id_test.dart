/// `osScheduledId` — biến `dedupeKey` (chuỗi) thành id số mà hệ điều hành
/// dùng để đặt và **huỷ** một lịch thông báo.
///
/// Điều đáng canh nhất ở đây không phải là "hàm chạy đúng" mà là **giá trị
/// không được đổi giữa các phiên chạy app**. Lịch nằm trong AlarmManager
/// (Android) / UNUserNotificationCenter (iOS), tức là sống lâu hơn tiến trình
/// Dart. Huỷ một lịch chỉ có một đường: đưa lại **đúng con số** đã dùng lúc
/// đặt. Nếu con số ấy đổi sau khi cập nhật app, lịch cũ trở thành mồ côi —
/// người dùng nhận nhắc cho hoá đơn đã xoá và **không có cách nào tắt** ngoài
/// gỡ app.
///
/// Vì thế test dưới đây khoá cứng bốn giá trị golden. Chúng cố ý làm việc
/// đổi thuật toán trở nên **ồn ào**: ai đó thay `md5` bằng
/// `dedupeKey.hashCode` (thứ Dart KHÔNG bảo đảm ổn định giữa các lần chạy) sẽ
/// thấy test đỏ ngay, chứ không phát hiện ra qua báo lỗi của người dùng ba
/// tháng sau.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';

void main() {
  group('osScheduledId', () {
    test('giữ nguyên giá trị golden cho các khoá thật', () {
      // Bốn giá trị này = 4 byte đầu (big-endian) của md5(khoá) & 0x7fffffff,
      // tính độc lập bằng Python. Chúng là hợp đồng với các bản app đã phát
      // hành: đổi là mọi lịch đang chờ trên máy người dùng thành mồ côi.
      expect(
        osScheduledId('billDue:9f3a:2026-09-15:3'),
        503122046,
        reason: 'Đổi thuật toán băm là mất khả năng huỷ lịch đã đặt bởi bản '
            'app cũ — người dùng nhận nhắc cho hoá đơn đã xoá.',
      );
      expect(osScheduledId('billOverdue:9f3a:2026-09-10'), 207121317,
          reason: 'Golden thứ hai canh cùng một hợp đồng.');
      expect(osScheduledId('budgetNear:b1:2026-09-01:warning'), 2132927364,
          reason: 'Khoá này băm ra byte đầu > 0x7f, nên nó canh riêng bước '
              'xoá bit dấu.');
    });

    test('chuỗi rỗng vẫn ra id hợp lệ', () {
      expect(osScheduledId(''), 1411222745,
          reason: 'Không được ném: một dedupeKey rỗng do lỗi ở nơi khác chỉ '
              'nên làm sai một thông báo, không làm chết cả lượt đặt lịch.');
    });

    test('luôn là số dương nằm trong dải int 32-bit của Android', () {
      // `flutter_local_notifications` đẩy id này xuống một `int` Java 32-bit.
      // Số âm hay số vượt dải bị nền tảng cắt bớt **âm thầm**, và hai khoá
      // khác nhau có thể cùng rơi về một id sau khi cắt — lúc đó đặt lịch cho
      // hoá đơn B sẽ ghi đè lịch của hoá đơn A.
      final khoa = [
        for (var i = 0; i < 500; i++) 'billDue:hoa-don-$i:2026-09-15:3',
        for (var i = 0; i < 500; i++) 'budgetOver:ngan-sach-$i:2026-09-01',
      ];
      for (final k in khoa) {
        final id = osScheduledId(k);
        expect(id, greaterThanOrEqualTo(0), reason: 'Khoá "$k" ra id âm.');
        expect(id, lessThanOrEqualTo(0x7fffffff),
            reason: 'Khoá "$k" ra id vượt dải int 32-bit có dấu.');
      }
    });

    test('hai khoá khác nhau hầu như không đụng nhau', () {
      // Không đòi hỏi "không bao giờ trùng" — 31 bit thì trùng là chuyện có
      // thể xảy ra. Đòi hỏi là hàm phải **phân tán**: một cài đặt hỏng kiểu
      // "lấy độ dài chuỗi" vẫn qua được ba test trên nhưng chết ở đây.
      final ids = {
        for (var i = 0; i < 1000; i++) osScheduledId('billDue:x$i:2026-09-15:3')
      };
      expect(ids.length, 1000,
          reason: 'Một nghìn khoá khác nhau phải ra một nghìn id khác nhau; '
              'đụng độ ở quy mô này nghĩa là hàm băm không phân tán, và hai '
              'hoá đơn sẽ ghi đè lịch của nhau.');
    });

    test('cùng một khoá luôn ra cùng một id', () {
      const k = 'billDue:lap-lai:2026-12-31:7';
      expect(osScheduledId(k), osScheduledId(k),
          reason: 'Đặt lịch và huỷ lịch là hai lần gọi khác nhau trên cùng '
              'một khoá; khác kết quả là không bao giờ huỷ được.');
    });
  });
}
