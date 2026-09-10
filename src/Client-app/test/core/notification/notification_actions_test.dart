/// Nút hành động trên thông báo hệ điều hành.
///
/// Toàn bộ **quyết định** nằm ở đây, tách khỏi `os_notifier_native.dart` vì hai
/// lẽ. Thứ nhất là bẫy 7.7: file kia là nơi DUY NHẤT được import
/// `flutter_local_notifications`, và một handler chạy trong isolate nền thì
/// không test được bằng `flutter test`. Thứ hai, phần khó của tính năng này
/// không phải gọi plugin mà là **chọn đúng mốc và đúng khoá** — và đó là thứ
/// một hàm thuần canh được.
///
/// Điều quan trọng nhất cả file này canh: **"Hoãn" giữ NGUYÊN khoá.** Cùng khoá
/// nghĩa là cùng `osScheduledId`, và `ReminderScheduler.resync()` bỏ qua mọi id
/// đã nằm trong hàng chờ (`if (dangCho.contains(entry.key)) continue;`). Nhờ
/// đó lịch hoãn **sống sót** qua lượt quét kế tiếp mà không cần lưu trạng thái
/// ở đâu cả. Đổi khoá là resync huỷ lịch hoãn rồi đặt lại mốc cũ — người dùng
/// bấm "Hoãn" xong vẫn bị nhắc đúng giờ ấy, và không có gì báo là vì sao.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_actions.dart';
import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';

void main() {
  final now = DateTime(2026, 9, 15, 8, 5);

  group('thông báo nào có nút', () {
    test('chỉ nhắc hoá đơn', () {
      expect(coHanhDong('billDue:hd1:2026-09-20:3'), true);
      expect(coHanhDong('billOverdue:hd1:2026-09-10'), true);
    });

    test('các loại khác thì không', () {
      // Nút "Hoãn" chỉ có nghĩa với một lời nhắc đặt trước. Gắn nó lên cảnh báo
      // ví âm hay nhắc ghi chép là hứa một hành vi không tồn tại.
      for (final khoa in [
        'walletNeg:vi1:2026-09-15',
        'walletLow:vi1:2026-09-15',
        'budgetNear:b1:2026-09-01:caution',
        'goalAuto:mt1:2026-09-15T08:00',
        'ghiChep:2026-09-15',
        'syncFailed:2026-09-15',
        '',
      ]) {
        expect(coHanhDong(khoa), false, reason: 'Khoá "$khoa" không được có nút.');
      }
    });
  });

  group('Trả ngay', () {
    test('dựng payload mở ĐÚNG hoá đơn ấy', () {
      expect(payloadTraNgay('billDue:hd1:2026-09-20:3'), 'billOpen:hd1');
      expect(payloadTraNgay('billOverdue:hd-abc:2026-09-10'), 'billOpen:hd-abc');
    });

    test('khoá thiếu id thì không dựng gì', () {
      // Khoá có thể đến từ một lịch do bản app cũ đặt và vẫn còn nằm trong
      // AlarmManager sau khi nâng cấp. Trả null để nơi gọi rơi về cú chạm
      // thường, thay vì dựng "billOpen:" rồi đẩy người dùng vào màn trống.
      expect(payloadTraNgay('billDue'), isNull);
      expect(payloadTraNgay('billDue:'), isNull);
      expect(payloadTraNgay('walletNeg:vi1:2026-09-15'), isNull);
    });
  });

  group('khoá dùng để suy route sau khi bấm nút', () {
    const khoaHoaDon = 'billDue:hd1:2026-09-20:3';

    test('bấm "Trả ngay" thì đổi sang khoá mở đúng hoá đơn', () {
      expect(
        khoaSauChamNut(actionId: hanhDongTraNgay, payload: khoaHoaDon),
        'billOpen:hd1',
      );
    });

    test('chạm thường (không có actionId) giữ nguyên khoá', () {
      expect(khoaSauChamNut(actionId: null, payload: khoaHoaDon), khoaHoaDon,
          reason: 'Cú chạm vào THÂN thông báo vẫn mở danh sách hoá đơn — đó là '
              'đúng cột deeplink bộ luật đặt, và có phép canh cả 14 loại.');
      expect(khoaSauChamNut(actionId: '', payload: khoaHoaDon), khoaHoaDon,
          reason: 'Android trả chuỗi rỗng chứ không phải null ở một số bản.');
    });

    test('khoá không mang id thì giữ nguyên, không dựng "billOpen:"', () {
      expect(khoaSauChamNut(actionId: hanhDongTraNgay, payload: 'billDue'),
          'billDue',
          reason: 'Rơi về cú chạm thường còn hơn đẩy người dùng vào màn trống.');
    });

    test('mã hành động lạ cũng giữ nguyên khoá', () {
      // Lịch của một bản app cũ vẫn nằm trong AlarmManager sau khi nâng cấp và
      // có thể trả về mã không còn ai biết.
      expect(khoaSauChamNut(actionId: 'ma_cu_nao_do', payload: khoaHoaDon),
          khoaHoaDon);
    });
  });

  group('Hoãn', () {
    test('dời đúng 24 giờ kể từ lúc bấm', () {
      final lich = lichHoan(dedupeKey: 'billDue:hd1:2026-09-20:3', now: now);

      expect(lich, isNotNull);
      expect(lich!.when, DateTime(2026, 9, 16, 8, 5),
          reason: 'Đếm từ lúc BẤM, không phải từ giờ nhắc đã cài. Người dùng '
              'bấm lúc 8h05 thì mai 8h05 nhắc lại — và vì đây là một khoảng '
              'thời gian tuyệt đối nên nó không phụ thuộc múi giờ, thứ mà '
              'isolate nền không đọc được (bẫy 7.3).');
    });

    test('GIỮ NGUYÊN khoá, nên cùng osScheduledId', () {
      const khoa = 'billDue:hd1:2026-09-20:3';
      final lich = lichHoan(dedupeKey: khoa, now: now);

      expect(lich!.khoa, khoa);
      expect(osScheduledId(lich.khoa), osScheduledId(khoa),
          reason: 'Đây là cả cơ chế làm lịch hoãn sống sót: resync() bỏ qua id '
              'đã nằm trong hàng chờ. Đổi khoá là resync huỷ lịch hoãn rồi đặt '
              'lại mốc cũ, và người dùng vẫn bị nhắc đúng giờ họ vừa hoãn.');
    });

    test('hoãn lần nữa thì dồn thêm một ngày', () {
      final lan1 = lichHoan(dedupeKey: 'billDue:hd1:2026-09-20:3', now: now)!;
      final lan2 = lichHoan(dedupeKey: lan1.khoa, now: lan1.when)!;

      expect(lan2.when, DateTime(2026, 9, 17, 8, 5));
      expect(lan2.khoa, lan1.khoa,
          reason: 'Hoãn nhiều lần vẫn phải là cùng một lịch, không đẻ ra lịch '
              'thứ hai — hai thông báo cho một hoá đơn là thứ người dùng đọc '
              'thành app hỏng.');
    });

    test('câu chữ không nêu số liệu nào', () {
      final lich = lichHoan(dedupeKey: 'billDue:hd1:2026-09-20:3', now: now)!;

      // Isolate nền không đọc được CSDL, nên nó không biết hoá đơn tên gì hay
      // còn bao nhiêu ngày. Câu chữ vì thế phải chung chung một cách có chủ ý
      // — đoán rồi nói sai còn tệ hơn nói ít.
      expect(lich.title, isNotEmpty);
      expect(lich.body, isNotEmpty);
      expect(lich.body, isNot(contains('hd1')),
          reason: 'Không được rò id ra câu chữ người dùng đọc.');
    });

    test('loại không có nút thì không hoãn được', () {
      expect(lichHoan(dedupeKey: 'ghiChep:2026-09-15', now: now), isNull);
      expect(lichHoan(dedupeKey: 'walletNeg:vi1:2026-09-15', now: now), isNull,
          reason: 'Cùng một danh sách với coHanhDong(). Hai nơi lệch nhau là '
              'nút hiện ra nhưng bấm vào không làm gì cả.');
    });
  });
}
