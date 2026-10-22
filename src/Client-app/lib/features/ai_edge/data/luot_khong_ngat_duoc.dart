/// Lượt mô hình mà `huy()` không ngắt được tức thì vẫn chạy NỐT sau khi người gọi đã bỏ nó — lời gọi mô hình kế tiếp
/// phải CHỜ lượt ấy xong. Hàm thuần về thời gian (không biết gì về mô hình), để test được trên x86.
///
/// Sinh ra cho A5 (người dùng duyệt 2026-10-22): bấm Huỷ ở *"Đang đọc bằng AI…"* thì màn Quét sang form NGAY, nhưng lời
/// gọi đọc ảnh native không ngắt được (Realme CPU 2026-10-21: huỷ 14:23:53, native trả 14:23:58) — nó chạy nốt ở nền. Chỉ có
/// MỘT bản mô hình; hai lượt chồng nhau trên engine là vùng chưa đo (họ bẫy sập native OnePlus GPU). `SlmRuntimeThat` cho
/// `docAnh` chạy qua [chay] và cho các lối sinh khác [cho] trước khi tạo phiên chat.
library;

import 'dart:async';

class LuotKhongNgatDuoc {
  Future<void>? _dang;

  /// Chạy [f] sau khi lượt trước (nếu có) xong; trong lúc [f] chạy, [cho] đợi nó. Lỗi của [f] ném lại cho người gọi.
  Future<T> chay<T>(Future<T> Function() f) async {
    // Kiểm và nhận chỗ trong CÙNG một microtask (vòng lặp nằm ngay đây, không qua [cho]): tách ra là hai lượt cùng thấy
    // chỗ trống rồi cùng chạy.
    while (_dang != null) {
      await _dang;
    }
    final xong = Completer<void>();
    _dang = xong.future;
    try {
      return await f();
    } finally {
      _dang = null;
      xong.complete();
    }
  }

  /// Xong khi không còn lượt nào đang chạy — kể cả lượt vào hàng trong lúc đợi. Không bao giờ ném.
  Future<void> cho() async {
    while (_dang != null) {
      await _dang;
    }
  }
}
