/// C4 — chuẩn hoá các sự kiện của MỘT lượt nghe thành hợp đồng: chữ tạm (`chu(_, false)`) rồi **ĐÚNG MỘT** kết thúc —
/// `chu(_, true)` | `loi` | `done`. Lớp thuần: không gọi nền tảng, test được bằng `fake_async`.
///
/// Vì sao cần: gói `speech_to_text` 7.5.0 (đọc mã, CHƯA đo trên máy) khi lỗi mà chưa có chữ nào thì báo `done` TRƯỚC
/// `error` (Android gọi `notifyListening(false)` trực tiếp, còn lỗi qua `handler.post`); có chữ tạm thì chỉ `error`,
/// không `done`. Để "lỗi thắng", `done` chưa kèm chữ cuối được HOÃN [kChoLoiSauDone]; lỗi tới trong nhịp ấy thì phát
/// lỗi, hết nhịp mới phát `onDung`.
library;

import 'dart:async';

const Duration kChoLoiSauDone = Duration(milliseconds: 300);

class LuotNghe {
  LuotNghe({
    required this.onChu,
    required this.onLoi,
    required this.onDung,
    this.choLoi = kChoLoiSauDone,
  });

  final void Function(String chu, bool xong) onChu;
  final void Function(String ma) onLoi;
  final void Function() onDung;
  final Duration choLoi;

  bool _ketThuc = false;
  Timer? _hen;

  void chu(String c, bool xong) {
    if (_ketThuc) return;
    if (xong) _chot();
    onChu(c, xong);
  }

  void loi(String ma) {
    if (_ketThuc) return;
    _chot();
    onLoi(ma);
  }

  /// Trạng thái `done` của gói.
  void done() {
    if (_ketThuc || _hen != null) return;
    _hen = Timer(choLoi, () {
      _hen = null;
      if (_ketThuc) return;
      _ketThuc = true;
      onDung();
    });
  }

  /// Bỏ lượt: không phát gì nữa.
  void huy() => _chot();

  void _chot() {
    _ketThuc = true;
    _hen?.cancel();
    _hen = null;
  }
}
