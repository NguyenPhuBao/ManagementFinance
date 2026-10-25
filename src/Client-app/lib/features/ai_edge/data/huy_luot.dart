/// Thẻ huỷ của MỘT lượt mô hình (bẫy 4.60 `AI_EDGE_FEATURE.md`, 2026-10-22). Dart thuần, test được trên x86.
///
/// Hai cách dừng, hai nghĩa khác nhau: người dùng bấm Huỷ là muốn AI dừng hẳn → `huy()` toàn cục của runtime (tăng bộ đếm
/// chung của `BoNapMoHinh`, dừng `_chatDangSinh`); lớp bọc HẾT GIỜ thì chỉ lượt của nó phải dừng → lớp bọc tạo một thẻ cho
/// mỗi lượt, đưa vào `docAnh` / `chepLoi`, hết giờ thì [huy] thẻ ấy. Runtime đọc [daHuy] sau pha nạp (không tạo chat) và
/// nghe [tin] để dừng CHÍNH chat của lượt — không đụng bộ đếm chung, không bỏ oan lượt khác đang chờ.
library;

import 'dart:async';

class HuyLuot {
  final _tin = Completer<void>();

  bool get daHuy => _tin.isCompleted;

  /// Phát một lần khi [huy] — người nghe đăng ký SAU lúc huỷ vẫn nhận (runtime đăng ký sau khi tạo chat).
  Future<void> get tin => _tin.future;

  void huy() {
    if (!_tin.isCompleted) _tin.complete();
  }
}
