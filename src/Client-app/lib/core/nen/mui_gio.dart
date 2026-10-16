import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Nạp bảng múi giờ và đặt múi giờ địa phương.
///
/// **Phải chạy TRƯỚC `setupDependencies()`** vì `ReminderScheduler` dựng
/// `TZDateTime` ngay khi đặt lịch. Thiếu bước này thì `zonedSchedule` neo vào
/// UTC và nhắc hoá đơn lệch 7 tiếng ở Việt Nam — **không có lỗi nào báo ra**
/// (bẫy 7.3 của `docs/NOTIFICATION_FEATURE.md`).
///
/// Dùng chung cho engine của app (`main.dart`) và engine nền của WorkManager
/// (`chay_nen.dart`) — engine nền cũng gọi `resync` qua lượt quét.
///
/// Nuốt lỗi và lùi về UTC: không đọc được múi giờ của máy thì nhắc sai giờ,
/// còn ném ở đây thì app không khởi động được. Hỏng nhẹ hơn hẳn.
Future<void> khoiTaoMuiGio() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    // Giữ nguyên mặc định của gói (UTC).
  }
}
