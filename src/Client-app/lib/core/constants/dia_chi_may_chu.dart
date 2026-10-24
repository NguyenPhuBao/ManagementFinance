/// Chọn và kiểm địa chỉ máy chủ API (siết bảo mật đợt 2, 2026-10-24).
///
/// Bản phát hành KHÔNG được gọi máy chủ công khai qua `http://`: mật khẩu, OTP, token làm mới, token socket và toàn bộ
/// dữ liệu đồng bộ đi qua địa chỉ này, mà `dart:io` (Dio, socket) không đọc network-security-config của Android nên hệ
/// điều hành không chặn cleartext (bẫy 4.20 `AI_EDGE_FEATURE.md`). Địa chỉ NỘI BỘ vẫn cho `http` — đo máy thật với
/// backend dev qua `adb reverse` (127.0.0.1), máy ảo (10.0.2.2), hoặc IP Wi-Fi của máy tính.
///
/// Dart thuần (không `dart:io`) — `AppConstants.baseUrl` chạy cả ở bản web.
library;

/// [tuBuild] (giá trị `--dart-define=API_BASE_URL=…`, rỗng khi không truyền) thắng [macDinh]; kết quả qua
/// [kiemDiaChiMayChu].
String chonDiaChiMayChu({required String tuBuild, required String macDinh, required bool phatHanh}) =>
    kiemDiaChiMayChu(tuBuild.isNotEmpty ? tuBuild : macDinh, phatHanh: phatHanh);

/// Trả nguyên [url] khi dùng được; ném [StateError] khi [phatHanh] mà [url] không phải `https` và host không nội bộ.
String kiemDiaChiMayChu(String url, {required bool phatHanh}) {
  if (!phatHanh) return url;
  final uri = Uri.tryParse(url);
  if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) return url;
  if (uri != null && uri.scheme == 'http' && _laNoiBo(uri.host)) return url;
  throw StateError('Bản phát hành không được gọi máy chủ công khai qua http: "$url". Dùng https — build với '
      '--dart-define=API_BASE_URL=https://…/api (địa chỉ nội bộ 127.0.0.1 / 10.x / 172.16–31.x / 192.168.x vẫn cho http).');
}

/// Loopback, `localhost`, và ba dải IPv4 riêng (10/8, 172.16/12, 192.168/16) — `10.0.2.2` của máy ảo nằm trong 10/8.
bool _laNoiBo(String host) {
  if (host == 'localhost' || host == '::1') return true;
  final so = host.split('.').map(int.tryParse).toList();
  if (so.length != 4 || so.any((s) => s == null || s < 0 || s > 255)) return false;
  final a = so[0]!, b = so[1]!;
  return a == 127 || a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}
