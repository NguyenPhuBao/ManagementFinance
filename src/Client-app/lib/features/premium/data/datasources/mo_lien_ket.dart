import 'package:url_launcher/url_launcher.dart';

/// Mở [uri] bằng ứng dụng ngoài (trình duyệt) — trang PayOS có QR và danh sách
/// app ngân hàng mở thẳng kèm số tiền (spec Premium 2026-10-06 câu 7, mục 9.2).
/// Tệp DUY NHẤT import `url_launcher` (test quét 18).
///
/// Cố ý KHÔNG gọi `canLaunchUrl` — nó đòi `<queries>` trong manifest (vùng mù
/// của `flutter test`, bẫy 7.11). `launchUrl` trả `false` / ném thì trả `false`
/// để màn hiện link chép được thay vì báo lỗi.
Future<bool> moLienKetNgoai(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Khe tiêm cho màn Đang chờ thanh toán.
typedef MoLienKet = Future<bool> Function(Uri uri);
