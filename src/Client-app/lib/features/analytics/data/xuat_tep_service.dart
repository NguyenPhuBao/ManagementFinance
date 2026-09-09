import '../domain/bao_cao_xuat.dart';

/// Sinh tệp báo cáo rồi giao cho hệ điều hành (sheet chia sẻ / lưu).
///
/// Tách thành một cửa riêng vì đây là chỗ **duy nhất** của tính năng xuất báo
/// cáo mà bộ test không với tới được: nó ghi tệp thật và gọi plugin. Mọi luật
/// về *nội dung* tệp nằm ở `domain/xuat_tep.dart` và được kiểm ở đó.
abstract class XuatTepService {
  /// [dinhDang] là `'PDF'` hoặc `'CSV'` (không phân biệt hoa thường).
  ///
  /// Ném lỗi khi ghi tệp hỏng — giao diện bắt và **nói ra**, đừng nuốt: người
  /// dùng bấm "Tải xuống" mà không thấy gì sẽ bấm tiếp mãi.
  Future<void> xuat(
    BaoCao bc, {
    required String dinhDang,
    required String nhanVi,
    required String nhanDanhMuc,
    required DateTime lapNgay,
  });
}
