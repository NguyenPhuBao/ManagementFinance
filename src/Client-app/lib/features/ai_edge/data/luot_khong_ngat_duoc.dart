/// Lượt mô hình mà `huy()` không ngắt được tức thì vẫn chạy NỐT sau khi người gọi đã bỏ nó — lời gọi mô hình kế tiếp
/// phải CHỜ lượt ấy xong. Hàm thuần về thời gian (không biết gì về mô hình), để test được trên x86.
///
/// Sinh ra cho A5 (người dùng duyệt 2026-10-22): bấm Huỷ ở *"Đang đọc bằng AI…"* thì màn Quét sang form NGAY, nhưng lời
/// gọi đọc ảnh native không ngắt được (Realme CPU 2026-10-21: huỷ 14:23:53, native trả 14:23:58) — nó chạy nốt ở nền. Chỉ có
/// MỘT bản mô hình; hai lượt chồng nhau trên engine là vùng chưa đo (họ bẫy sập native OnePlus GPU). `SlmRuntimeThat` cho
/// `docAnh` chạy qua [chay] và cho các lối sinh khác [cho] trước khi tạo phiên chat.
library;

import 'dart:async';

/// Trần chờ lượt cũ của MỘT lời gọi [LuotKhongNgatDuoc.chay] / [LuotKhongNgatDuoc.cho], tính từ lúc bắt đầu đợi (code-review
/// 2026-10-22: lượt native TREO thì năm lối sinh treo theo). ≥ lượt đọc ảnh chậm nhất đã đo (Realme CPU 42 s — lượt bị bỏ
/// mà `stopGeneration` hỏng thì chạy nốt tới cùng), và NGẮN HƠN trần của hai lớp bọc (`kThoiHanChepLoi` 60 s,
/// `kThoiHanDocAnhGemma` 90 s): lượt đang chờ tự ném trước, nên `onTimeout` của lớp bọc — gọi `huy()` toàn cục — không bao
/// giờ chạy lúc lượt còn đứng chờ. Test canh cả hai vế. Chưa đo trên máy.
const Duration kTranChoLuotCu = Duration(seconds: 45);

/// Lượt cũ không xong trong [kTranChoLuotCu] — coi như mô hình không chạy được lúc này; người gọi rơi về luật / mẫu câu.
class LuotCuChuaXong implements Exception {
  const LuotCuChuaXong();
  @override
  String toString() => 'LuotCuChuaXong: lượt mô hình trước chưa xong sau ${kTranChoLuotCu.inSeconds} s';
}

class LuotKhongNgatDuoc {
  LuotKhongNgatDuoc({this.toiDa = kTranChoLuotCu});

  final Duration toiDa;

  Future<void>? _dang;

  /// Lượt đã làm MỘT lời gọi quá trần — lời gọi sau ném ngay thay vì đợi thêm một trần nữa (native treo thì mỗi câu hỏi
  /// chờ 45 s). ⚠️ Quá trần KHÔNG giải phóng chỗ: lượt ấy vẫn chạy trên engine, cho lượt mới chạy là hai lượt chồng nhau.
  Future<void>? _quaTran;

  /// Chạy [f] sau khi lượt trước (nếu có) xong; trong lúc [f] chạy, [cho] đợi nó. Lỗi của [f] ném lại cho người gọi.
  /// Lượt trước không xong trong [toiDa] → ném [LuotCuChuaXong], [f] không chạy.
  Future<T> chay<T>(Future<T> Function() f) async {
    final han = _HanCho(this);
    try {
      // Kiểm và nhận chỗ trong CÙNG một microtask (vòng lặp nằm ngay đây, không qua [cho]): tách ra là hai lượt cùng thấy
      // chỗ trống rồi cùng chạy.
      while (_dang != null) {
        await han.doi(_dang!);
      }
    } finally {
      han.dung();
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

  /// Xong khi không còn lượt nào đang chạy — lượt đang chạy và lượt đã vào hàng TRƯỚC lời gọi này (lượt vào hàng sau nó
  /// thì không: bẫy 4.60 `AI_EDGE_FEATURE.md`). Ném [LuotCuChuaXong] khi quá [toiDa]; ngoài ra không bao giờ ném.
  Future<void> cho() async {
    final han = _HanCho(this);
    try {
      while (_dang != null) {
        await han.doi(_dang!);
      }
    } finally {
      han.dung();
    }
  }
}

/// Hạn chờ của một lời gọi — hẹn giờ chỉ dựng khi thật sự phải đợi, và huỷ khi thôi đợi (hẹn giờ sót lại làm widget test
/// đỏ *"Timer is still pending"*). Một hạn cho cả vòng đợi: lượt nối sau không được cấp trần mới.
class _HanCho {
  _HanCho(this._luot);

  final LuotKhongNgatDuoc _luot;
  final _het = Completer<bool>();
  Timer? _hen;

  Future<void> doi(Future<void> dang) async {
    _hen ??= Timer(_luot.toiDa, () => _het.complete(false));
    final kip = !identical(dang, _luot._quaTran) && await Future.any([dang.then((_) => true), _het.future]);
    if (!kip) {
      _luot._quaTran = dang;
      throw const LuotCuChuaXong();
    }
  }

  void dung() => _hen?.cancel();
}
