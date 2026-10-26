/// Tên máy gửi kèm mọi request tới backend qua header `x-device-name` (2026-10-26, mục v4 `Event-Notification-to-ClientApp.md`
/// mà người dùng chọn làm). Backend ghi lịch sử thiết bị + IP che mờ (`modules/auth/device-history.service.js` — gọi từ
/// `middleware/auth.js:122`, đăng nhập / đăng ký và `/auth/refresh`); thiếu header thì nó lấy `user-agent` — với Dio là
/// `Dart/…`. Hôm nay chưa màn admin nào ĐỌC bảng ấy (`getDeviceHistory` không có chỗ gọi ngoài test).
///
/// ⚠️ Tên ĐỔI là backend thêm một dòng lịch sử mới — nên mọi đường gọi backend của một máy gửi CÙNG một tên: Dio chung
/// (`DioClient`), Dio làm mới token (`AuthInterceptor`), engine app lẫn engine nền (kênh đăng ký ở cả `MainActivity` và
/// `TuChuyenTien.chayHeadless`). DI đọc MỘT lần (`setupDependencies`).
///
/// Chỉ Android: bản web gửi header lạ là preflight CORS hỏng (`app.js:32` chưa cho `x-device-name`) — mọi request bị chặn;
/// iOS chưa có mã gốc.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const kHeaderTenThietBi = 'x-device-name';
const kKenhThietBi = 'flowmoney/thiet_bi';

/// Trần của backend (`device-history.service.js` cắt `substring(0, 150)`).
const kDoDaiTenThietBiToiDa = 150;

final _kyTuDieuKhien = RegExp(r'[\x00-\x1F\x7F]');
final _ngoaiAsciiIn = RegExp(r'[^\x20-\x7E]');
final _nhieuKhoangTrang = RegExp(r' {2,}');

/// Tên an toàn cho một header HTTP; `null` = không gửi. Ký tự điều khiển (kể cả xuống dòng — chèn header) thành dấu cách;
/// ký tự ngoài ASCII in được bị bỏ (header ngoài Latin-1 là `HttpClient` của Dart ném — mọi request hỏng); gom khoảng trắng,
/// cắt còn [kDoDaiTenThietBiToiDa].
String? chuanHoaTenThietBi(String? tho) {
  if (tho == null) return null;
  var s = tho.replaceAll(_kyTuDieuKhien, ' ').replaceAll(_ngoaiAsciiIn, '');
  s = s.replaceAll(_nhieuKhoangTrang, ' ').trim();
  if (s.isEmpty) return null;
  return s.length > kDoDaiTenThietBiToiDa ? s.substring(0, kDoDaiTenThietBiToiDa).trimRight() : s;
}

/// Hỏi tên máy qua kênh `flowmoney/thiet_bi` (`ThietBi.kt`); không phải Android, kênh thiếu, hay lỗi → `null`, không ném.
Future<String?> docTenThietBi({MethodChannel kenh = const MethodChannel(kKenhThietBi)}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return chuanHoaTenThietBi(await kenh.invokeMethod<String>('ten'));
  } catch (e) {
    debugPrint('[TenThietBi] Không đọc được tên máy: $e');
    return null;
  }
}
