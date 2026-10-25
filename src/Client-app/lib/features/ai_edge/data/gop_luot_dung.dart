/// Gộp các lời dừng CÙNG LÚC vào một chat thành MỘT lời gọi native (bẫy 4.60 `AI_EDGE_FEATURE.md`, lối A người dùng chốt
/// 2026-10-22). Dart thuần, test được trên x86.
///
/// Vì sao: nút Huỷ pha AI màn Quét gọi cả `_docGemma.huy()` lẫn `_docDanhMuc.huy()` — cả hai tới `runtime.huy()` → dừng
/// cùng chat đọc ảnh, song song, trong lúc native chưa trả; thẻ hết giờ (`HuyLuot`) cũng đi đúng đường ấy. OnePlus GPU từng
/// sập native ở lời gọi lặp (họ bẫy *đóng lần hai*), nên native chỉ nhận một `stopGeneration` mỗi lúc; lời thứ hai chờ chung.
///
/// Chỉ gộp lúc ĐANG dừng: lượt xong (kể cả hỏng / quá hạn) là nhả chỗ, lời dừng sau đó gọi lại native — bấm Huỷ lần nữa vẫn
/// thử dừng. Đổi lại (người dùng chấp nhận): lượt đang dừng hỏng thì lời dừng đã gộp vào nó không có lần thử riêng.
library;

import 'dart:async';

class GopLuotDung<K extends Object> {
  /// So khoá theo định danh: hai chat native khác nhau luôn dừng riêng, kể cả khi `==` nói chúng bằng nhau.
  final Map<K, Future<void>> _dangDung = Map.identity();

  /// Có lượt dừng của [khoa] đang chạy — lời [dung] lúc này sẽ gộp vào nó.
  bool dangDung(K khoa) => _dangDung.containsKey(khoa);

  /// Dừng [khoa] bằng [goi], hoặc chờ chung lượt dừng đang chạy của nó. Lỗi của [goi] (kể cả ném đồng bộ) tới mọi người chờ.
  Future<void> dung(K khoa, Future<void> Function() goi) {
    final dang = _dangDung[khoa];
    if (dang != null) return dang;
    // ⚠️ Thân khối, không mũi tên: `remove` trả về chính [luot] (một `Future`), và `whenComplete` chờ Future mà hàm của nó
    // trả về — viết `() => _dangDung.remove(khoa)` là lượt tự chờ chính nó, không bao giờ xong (test bắt được).
    final luot = Future<void>.sync(goi).whenComplete(() {
      _dangDung.remove(khoa);
    });
    _dangDung[khoa] = luot;
    return luot;
  }
}
