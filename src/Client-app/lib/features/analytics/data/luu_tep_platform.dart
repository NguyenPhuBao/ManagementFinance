import 'package:flutter/services.dart';

/// Cửa xuống phía Android để **lưu tệp thẳng vào thư mục Tải về**.
///
/// Dùng `MediaStore.Downloads`, cách duy nhất đặt được tệp vào bộ nhớ chung mà
/// **không xin quyền nào** trên Android 10+ (API 29). Máy cũ hơn — và mọi nền
/// tảng khác — trả `null`; bên gọi khi ấy lùi về sheet chia sẻ, thứ chạy ở đâu
/// cũng được.
class LuuTepPlatform {
  static const MethodChannel kenh = MethodChannel('flowmoney/luu_tep');

  const LuuTepPlatform();

  /// Trả về đường dẫn **hiển thị** của tệp đã lưu (ví dụ `Tải về/BaoCao.pdf`),
  /// hoặc `null` khi máy không lưu kiểu này được.
  ///
  /// Ném [PlatformException] khi việc ghi **thật sự hỏng** (hết dung lượng,
  /// không tạo được bản ghi): hai ca ấy người dùng cần biết, gộp chung vào
  /// nhánh "không hỗ trợ" là nuốt mất một lỗi thật.
  Future<String?> luuVaoTaiVe({
    required String ten,
    required String mime,
    required Uint8List bytes,
  }) async {
    try {
      return await kenh.invokeMethod<String>('luuVaoTaiVe', {
        'ten': ten,
        'mime': mime,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      if (e.code == 'khong_ho_tro') return null;
      rethrow;
    } on MissingPluginException {
      // Web và desktop không có kênh này.
      return null;
    }
  }
}
