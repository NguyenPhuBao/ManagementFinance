/// Ánh xạ tên sự kiện của backend sang enum của client.
///
/// Đây là TOÀN BỘ những gì client đọc từ một sự kiện realtime — payload không
/// bao giờ được chạm tới. Lý do: một tên sự kiện không bảo đảm một hình dạng
/// payload. `ocr.completed` đi qua EventBus của backend và client không có
/// cách nào biết bản backend đang chạy dựng nó bằng khoá gì; đọc trường là tự
/// chuốc lấy loại lỗi im lặng của quy tắc 4 `CLAUDE.md` — sai tên trường thì
/// được `null`, không có exception, không có log.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/realtime/realtime_event.dart';

void main() {
  test('ba tên sự kiện client còn quan tâm được dịch đúng', () {
    expect(realtimeEventFromName('ocr.completed'), RealtimeEvent.ocrXong);
    expect(realtimeEventFromName('ocr.duplicate'), RealtimeEvent.ocrTrung);
    expect(realtimeEventFromName('sync.completed'), RealtimeEvent.dongBoXong,
        reason: 'Backend phát sự kiện này tới phòng account_<id> sau mỗi '
            '/sync/push (core/socket.js emitSyncCompleted). Không dịch nó là '
            'thay đổi từ máy khác phải chờ hết chu kỳ 15 phút — G34.');
  });

  test('bank_transaction.incoming bị bỏ qua — tính năng đã bỏ', () {
    expect(realtimeEventFromName('bank_transaction.incoming'), isNull,
        reason: 'Nhóm đã bỏ liên kết ngân hàng ngày 2026-09-18. Backend vẫn '
            'phát sự kiện này (SePay webhook → bank.worker.js), nên client '
            'phải bỏ qua nó êm thấm — đúng như với mọi tên lạ. Dịch nó thành '
            'một giá trị enum là mang một toast "vừa có giao dịch từ ngân '
            'hàng" trở lại cho một tính năng không còn tồn tại.');
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
