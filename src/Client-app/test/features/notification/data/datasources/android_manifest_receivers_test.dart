/// `flutter_local_notifications` cần **ba** receiver được khai báo trong
/// `AndroidManifest.xml`, và thiếu cái nào cũng hỏng **hoàn toàn im lặng**.
///
/// Đây là vùng mà không một test Dart nào khác chạm tới: `flutter test` không
/// đọc manifest, `flutter analyze` không đọc manifest, và `flutter build apk`
/// vẫn thành công. Sai sót chỉ lộ ra trên máy thật, ở dạng "bấm vào không có
/// gì xảy ra" — không exception, không log, không cả một dòng trong `logcat`.
///
/// Dự án đã vấp đúng kiểu này **hai lần**:
///
/// 1. Thiếu `ScheduledNotificationReceiver` → lịch đặt trước báo "đặt thành
///    công" nhưng không bao giờ nổ.
/// 2. Thiếu `ActionBroadcastReceiver` (2026-09-07) → nút "Hoãn 1 ngày" hiện
///    đúng trên khay thông báo, hệ điều hành dựng đúng `PendingIntent` kiểu
///    `broadcastIntent`, nhưng không tiến trình nào nhận. Chẩn đoán mất một
///    lúc vì mọi tầng đều **trông như** đúng: `dumpsys notification` cho thấy
///    `actions=2`, còn `dumpsys package` thì không liệt kê receiver ấy.
///
/// Test này rẻ và xấu xí — nó đọc một tệp XML bằng chuỗi — nhưng nó là lưới
/// duy nhất có thể giăng ở đây.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUpAll(() {
    // `flutter test` chạy với thư mục làm việc là gốc gói.
    final f = File('android/app/src/main/AndroidManifest.xml');
    expect(f.existsSync(), true,
        reason: 'Không đọc được manifest ở ${f.absolute.path} — nếu đường dẫn '
            'đổi thì sửa test này, đừng xoá nó.');
    manifest = f.readAsStringSync();
  });

  /// Cả ba đều là receiver **của plugin**, không phải lớp của dự án, nên tên
  /// phải khớp từng ký tự với gói `com.dexterous.flutterlocalnotifications`.
  const canCo = <String, String>{
    'ScheduledNotificationReceiver':
        'Thiếu nó thì lịch đặt trước báo "đặt thành công" nhưng KHÔNG BAO GIỜ '
            'nổ — mọi nhắc hoá đơn và nhắc ghi chép im lặng biến mất.',
    'ScheduledNotificationBootReceiver':
        'Thiếu nó thì mọi lịch đang chờ mất sạch sau khi khởi động lại máy, và '
            'người dùng không có cách nào biết.',
    'ActionBroadcastReceiver':
        'Thiếu nó thì nút "Hoãn 1 ngày" vẫn HIỆN và hệ điều hành vẫn dựng đúng '
            'PendingIntent, nhưng broadcast không tới ai cả: isolate nền không '
            'chạy, thông báo cũng không tự tắt. Không lỗi, không log.',
  };

  for (final entry in canCo.entries) {
    test('manifest khai báo ${entry.key}', () {
      expect(
        manifest.contains(
            'com.dexterous.flutterlocalnotifications.${entry.key}'),
        true,
        reason: entry.value,
      );
    });
  }

  test('không receiver nào được xuất ra ngoài app', () {
    // ⚠️ Chỉ xét bên trong thẻ `<receiver ...>`. Bản đầu của test này tìm
    // `exported="true"` trên CẢ file và đỏ ngay — vì `MainActivity` bắt buộc
    // phải xuất để trình khởi chạy mở được app. Một phép kiểm quá rộng như thế
    // sẽ bị người sau tắt đi thay vì sửa.
    final thuoc = <String>[];
    for (final phan in manifest.split('<receiver').skip(1)) {
      final het = phan.indexOf('>');
      if (het != -1) thuoc.add(phan.substring(0, het));
    }

    expect(thuoc, isNotEmpty, reason: 'Không tách được thẻ receiver nào.');
    for (final t in thuoc) {
      expect(t.contains('android:exported="true"'), false,
          reason: 'Một receiver được xuất ra ngoài cho phép app khác bắn intent '
              'giả vào — với receiver xử lý nút hành động thì đó là để người '
              'ngoài giả lập một cú bấm của người dùng.');
    }
  });
}
