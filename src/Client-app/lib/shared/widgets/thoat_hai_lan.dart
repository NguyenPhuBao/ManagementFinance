import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kết quả của một lần nhấn Back ở shell chính.
enum QuyetDinhThoat {
  /// Đang ở tab khác: đưa về tab đầu, không tính là lần nhấn.
  veTabDau,

  /// Lần nhấn đầu ở tab đầu (hoặc lần trước đã quá cửa sổ): báo và chờ.
  baoNhanLanNua,

  /// Nhấn lần hai trong cửa sổ: thoát app.
  thoat,
}

/// Luật "nhấn Back hai lần để thoát" — lớp thuần, không widget, để test được
/// bằng đồng hồ giả.
///
/// E3 của lượt UX 2026-09-19: máy ảo đo được Back ở tab Trang chủ đưa thẳng ra
/// launcher, không cảnh báo (app không có `PopScope` nào). Luật quen thuộc trên
/// Android: Back ở tab khác thì về tab đầu; ở tab đầu thì báo "Nhấn lần nữa để
/// thoát", nhấn lại trong [cuaSo] mới thoát thật.
class LuatThoatHaiLan {
  LuatThoatHaiLan({this.cuaSo = const Duration(seconds: 2)});

  final Duration cuaSo;
  DateTime? _lanTruoc;

  QuyetDinhThoat quyetDinh({required bool laTabDau, required DateTime luc}) {
    if (!laTabDau) {
      // Về tab đầu KHÔNG mồi cho lần thoát kế: người dùng chưa từng nhấn Back
      // ở tab đầu, nên lần nhấn tiếp theo ở đó vẫn phải là lần đầu.
      _lanTruoc = null;
      return QuyetDinhThoat.veTabDau;
    }
    final truoc = _lanTruoc;
    if (truoc != null && luc.difference(truoc) < cuaSo) {
      _lanTruoc = null;
      return QuyetDinhThoat.thoat;
    }
    _lanTruoc = luc;
    return QuyetDinhThoat.baoNhanLanNua;
  }
}

/// Bọc thân shell chính bằng `PopScope` và áp [LuatThoatHaiLan].
///
/// Chỉ can thiệp khi route của shell đang ở **trên cùng**: trang đẩy lên root
/// navigator (Thêm giao dịch, Sổ giao dịch…) có route riêng nằm trên, Back ở
/// đó pop trang ấy như thường và không đi qua đây.
class ThoatHaiLan extends StatefulWidget {
  const ThoatHaiLan({
    super.key,
    required this.child,
    required this.laTabDau,
    required this.veTabDau,
    required this.baoNhanLanNua,
    this.cuaSo = const Duration(seconds: 2),
    this.dongHo,
  });

  final Widget child;
  final bool Function() laTabDau;
  final VoidCallback veTabDau;

  /// Hiện câu "Nhấn lần nữa để thoát" — shell nối vào `ThongBaoNhanh`.
  final VoidCallback baoNhanLanNua;
  final Duration cuaSo;

  /// Đồng hồ, để test; mặc định `DateTime.now`.
  final DateTime Function()? dongHo;

  @override
  State<ThoatHaiLan> createState() => _ThoatHaiLanState();
}

class _ThoatHaiLanState extends State<ThoatHaiLan> {
  late final LuatThoatHaiLan _luat = LuatThoatHaiLan(cuaSo: widget.cuaSo);

  void _khiBack(bool didPop, Object? _) {
    if (didPop) return;
    final luc = (widget.dongHo ?? DateTime.now)();
    switch (_luat.quyetDinh(laTabDau: widget.laTabDau(), luc: luc)) {
      case QuyetDinhThoat.veTabDau:
        widget.veTabDau();
      case QuyetDinhThoat.baoNhanLanNua:
        widget.baoNhanLanNua();
      case QuyetDinhThoat.thoat:
        SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _khiBack,
      child: widget.child,
    );
  }
}
