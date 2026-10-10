import 'dart:io';

/// Xoá bản sao `image_picker` (Android) để lại trong `cache/` của app sau một lần chụp / chọn ảnh để Quét.
///
/// Gói ấy trả về `cache/scaled_<tên>` (bản thu nhỏ, khi có `maxWidth`) và giữ bản chép từ trình chọn ở
/// `cache/<uuid>/<tên>` — không API nào dọn chúng. Nghiệm thu OnePlus 2026-10-08: 45 thư mục như thế, 13 MB sau ~20 lần
/// quét, trong khi tài liệu hứa ảnh hoá đơn bị xoá khi Lưu / Bỏ qua (`KhoAnhQuet` chỉ dọn bản của chính nó).
///
/// Chỉ xoá khi tệp nằm THẲNG trong một thư mục tên `cache` — đường dẫn khác (ảnh thư viện, tệp test) thì không đụng.
/// Đồng bộ: gọi từ `dispose()`, và I/O bất đồng bộ không chạy dưới FakeAsync của widget test.
void xoaTepTamChonAnh(String duongDan) {
  final tep = File(duongDan);
  final cha = tep.parent;
  if (cha.path.split(RegExp(r'[\\/]')).last != 'cache' || !cha.existsSync()) return;
  final ten = tep.uri.pathSegments.last;
  final tenGoc = ten.startsWith('scaled_') ? ten.substring('scaled_'.length) : ten;
  try {
    if (tep.existsSync()) tep.deleteSync();
    for (final thuMuc in cha.listSync().whereType<Directory>()) {
      final banGoc = File('${thuMuc.path}${Platform.pathSeparator}$tenGoc');
      if (!banGoc.existsSync()) continue;
      banGoc.deleteSync();
      if (thuMuc.listSync().isEmpty) thuMuc.deleteSync();
    }
  } on FileSystemException catch (e) {
    // Dọn cache là việc phụ — hỏng thì để hệ điều hành dọn sau, không làm hỏng màn.
    assert(() {
      // ignore: avoid_print
      print('[Quet] dọn tệp tạm image_picker lỗi: $e');
      return true;
    }());
  }
}
