import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

/// Biến `dedupeKey` thành id số để đặt/huỷ một lịch thông báo hệ điều hành.
///
/// Lấy **4 byte đầu của md5(khoá)**, đọc big-endian, rồi xoá bit dấu
/// (`& 0x7fffffff`) để kết quả luôn nằm gọn trong `int` 32-bit có dấu của
/// Java — đúng kiểu mà `flutter_local_notifications` đẩy xuống Android.
///
/// ## Vì sao KHÔNG dùng `dedupeKey.hashCode`
///
/// Dart **không bảo đảm** `String.hashCode` giữ nguyên giữa các lần chạy, và
/// trên web nó còn khác hẳn VM. Lịch thông báo thì sống trong AlarmManager /
/// UNUserNotificationCenter, tức là **lâu hơn tiến trình Dart**. Huỷ một lịch
/// chỉ có đúng một đường: đưa lại con số đã dùng lúc đặt. Nếu con số ấy đổi
/// sau một lần cập nhật app, mọi lịch cũ thành mồ côi — người dùng nhận nhắc
/// cho hoá đơn đã xoá và không có cách nào tắt ngoài gỡ app. md5 là ổn định
/// tuyệt đối theo đặc tả, nên nó là lựa chọn đúng ở đây.
///
/// Đây **không phải** dùng md5 cho mục đích bảo mật — chỉ cần một hàm băm
/// ổn định và phân tán tốt. Gói `crypto` đã có sẵn trong `pubspec.yaml`.
int osScheduledId(String dedupeKey) {
  final digest = md5.convert(utf8.encode(dedupeKey)).bytes;
  final raw = (digest[0] << 24) |
      (digest[1] << 16) |
      (digest[2] << 8) |
      digest[3];
  return raw & 0x7fffffff;
}
