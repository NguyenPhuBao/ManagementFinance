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
  test('bốn tên sự kiện có thật của backend được dịch đúng', () {
    expect(realtimeEventFromName('bank_transaction.incoming'),
        RealtimeEvent.giaoDichNganHang);
    expect(realtimeEventFromName('ocr.completed'), RealtimeEvent.ocrXong);
    expect(realtimeEventFromName('ocr.duplicate'), RealtimeEvent.ocrTrung);
    expect(realtimeEventFromName('sync.completed'), RealtimeEvent.dongBoXong,
        reason: 'Backend phát sự kiện này tới phòng account_<id> sau mỗi '
            '/sync/push (core/socket.js emitSyncCompleted). Không dịch nó là '
            'thay đổi từ máy khác phải chờ hết chu kỳ 15 phút — G34.');
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

  test('ocr.duplicate KHÔNG đánh thức đồng bộ, ba cái kia thì có', () {
    expect(RealtimeEvent.giaoDichNganHang.canDongBoLai, isTrue);
    expect(RealtimeEvent.ocrXong.canDongBoLai, isTrue);
    expect(RealtimeEvent.dongBoXong.canDongBoLai, isTrue,
        reason: 'Toàn bộ giá trị của sync.completed là kéo dữ liệu máy khác '
            'về NGAY. Không đánh thức đồng bộ thì sự kiện này vô nghĩa.');
    expect(RealtimeEvent.ocrTrung.canDongBoLai, isFalse,
        reason: 'Đúng nghĩa của ocr.duplicate là KHÔNG có gì mới được tạo. '
            'Đồng bộ ở đó là một vòng mạng thừa.');
  });

  test('mỗi sự kiện có toast mang một lời nhắn cố định, không nêu số liệu',
      () {
    expect(RealtimeEvent.giaoDichNganHang.loiNhan,
        'Vừa có giao dịch mới từ ngân hàng');
    expect(RealtimeEvent.ocrXong.loiNhan, 'Đã bóc tách xong hoá đơn');
    expect(RealtimeEvent.ocrTrung.loiNhan,
        'Hoá đơn này đã được ghi nhận trước đó');

    for (final e in RealtimeEvent.values) {
      final chu = e.loiNhan;
      if (chu == null) continue;
      expect(RegExp(r'\d').hasMatch(chu), isFalse,
          reason: 'Lời nhắn là hằng số do client chọn, không lấy từ payload. '
              'Một con số lọt vào đây nghĩa là ai đó đã bắt đầu đọc payload.');
    }
  });

  test('sự kiện có toast thì lời nhắn không rỗng; sync.completed thì im lặng',
      () {
    for (final e in RealtimeEvent.values) {
      final chu = e.loiNhan;
      if (chu == null) continue;
      expect(chu.trim(), isNotEmpty,
          reason: 'Thêm giá trị enum với lời nhắn rỗng thì toast hiện ra '
              'rỗng, và không có gì báo lỗi. Muốn im lặng thì trả null.');
    }
    expect(RealtimeEvent.dongBoXong.loiNhan, isNull,
        reason: 'Máy vừa đẩy dữ liệu cũng nằm trong phòng account_<id> nên '
            'nhận lại chính sự kiện của mình, và payload là hộp đen nên không '
            'phân biệt được máy gửi. Một toast "máy khác vừa đổi dữ liệu" sẽ '
            'nói SAI trên đúng máy vừa ghi, sau mỗi lần ghi. Đồng bộ lại có '
            'dải kết quả riêng ở bậc cao nhất (spec socket §6.3), nên sự kiện '
            'này chỉ kéo về, không hiện gì.');
  });
}
