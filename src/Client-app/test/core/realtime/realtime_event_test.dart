/// Ánh xạ tên sự kiện của backend sang enum của client.
///
/// Đây là TOÀN BỘ những gì client đọc từ một sự kiện realtime — payload không
/// bao giờ được chạm tới. Lý do: `bank_transaction.incoming` được backend phát
/// từ hai đường với hai hình dạng payload khác nhau (`workers/bank.worker.js`
/// gửi snake_case, `modules/notification/notification.service.js` gửi camelCase
/// kèm title/message). Đọc trường là tự chuốc lấy loại lỗi im lặng của quy tắc
/// 4 `CLAUDE.md`: sai tên trường thì được `null`, không có exception, không có
/// log.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/realtime/realtime_event.dart';

void main() {
  test('ba tên sự kiện có thật của backend được dịch đúng', () {
    expect(realtimeEventFromName('bank_transaction.incoming'),
        RealtimeEvent.giaoDichNganHang);
    expect(realtimeEventFromName('ocr.completed'), RealtimeEvent.ocrXong);
    expect(realtimeEventFromName('ocr.duplicate'), RealtimeEvent.ocrTrung);
  });

  test('tên lạ trả về null chứ không ném lỗi', () {
    expect(realtimeEventFromName('notification.new'), isNull,
        reason: 'Sự kiện này được ghi trong docs/progress/Client-app.md mục 8 '
            'nhưng KHÔNG dòng nào ở backend phát nó. Client phải bỏ qua êm '
            'thấm, để backend thêm sự kiện mới không làm vỡ bản đang chạy.');
    expect(realtimeEventFromName('audit_activity'), isNull,
        reason: 'Sự kiện này chỉ gửi tới admin_room, không dành cho app.');
    expect(realtimeEventFromName(''), isNull);
  });

  test('ocr.duplicate KHÔNG đánh thức đồng bộ, hai cái kia thì có', () {
    expect(RealtimeEvent.giaoDichNganHang.canDongBoLai, isTrue);
    expect(RealtimeEvent.ocrXong.canDongBoLai, isTrue);
    expect(RealtimeEvent.ocrTrung.canDongBoLai, isFalse,
        reason: 'Đúng nghĩa của ocr.duplicate là KHÔNG có gì mới được tạo. '
            'Đồng bộ ở đó là một vòng mạng thừa.');
  });

  test('mỗi sự kiện có một lời nhắn cố định, không nêu số liệu', () {
    expect(RealtimeEvent.giaoDichNganHang.loiNhan,
        'Vừa có giao dịch mới từ ngân hàng');
    expect(RealtimeEvent.ocrXong.loiNhan, 'Đã bóc tách xong hoá đơn');
    expect(RealtimeEvent.ocrTrung.loiNhan,
        'Hoá đơn này đã được ghi nhận trước đó');

    for (final e in RealtimeEvent.values) {
      expect(RegExp(r'\d').hasMatch(e.loiNhan), isFalse,
          reason: 'Lời nhắn là hằng số do client chọn, không lấy từ payload. '
              'Một con số lọt vào đây nghĩa là ai đó đã bắt đầu đọc payload.');
    }
  });

  test('mọi giá trị enum đều có lời nhắn', () {
    for (final e in RealtimeEvent.values) {
      expect(e.loiNhan.trim(), isNotEmpty,
          reason: 'Thêm giá trị enum mà quên lời nhắn thì toast hiện ra rỗng, '
              'và không có gì báo lỗi.');
    }
  });
}
