import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Khoảng đáy màn (dp) đang bị một vùng do app TỰ VẼ che — `AppToast` nổi viên lên trên nó.
///
/// Thêm 2026-10-06 (người dùng chọn, theo Stitch `fb68baba…` *"Thông báo nổi (toast) - Ba biến thể"*): 16 phím số ở
/// màn Thêm giao dịch là bàn phím tự vẽ, hệ điều hành không báo `viewInsets` cho nó, nên viên lỗi ("Vui lòng chọn danh
/// mục" lúc bấm ✓) nằm ở chỗ cố định và đè hai hàng phím dưới. Một biến toàn cục vì `AppToast` ở `MaterialApp.builder`,
/// TRÊN router — không ở trong cây của trang nên không đọc được gì từ trang qua context.
final ValueNotifier<double> cheDayToast = ValueNotifier<double>(0);

/// Bọc vùng nằm sát đáy màn mà toast phải né. Sau mỗi lần dựng, đo khoảng từ mép trên của vùng tới đáy màn rồi báo
/// vào [kenh]; rời cây (bàn phím ẩn, rời màn) thì trả về 0.
class BaoCheDayToast extends StatefulWidget {
  const BaoCheDayToast({super.key, required this.child, this.kenh});

  final Widget child;

  /// `null` → [cheDayToast]. Test truyền kênh riêng.
  final ValueNotifier<double>? kenh;

  @override
  State<BaoCheDayToast> createState() => _BaoCheDayToastState();
}

/// Ai đang giữ từng kênh — vùng mới dựng trong cùng khung với lúc vùng cũ rời cây thì vùng cũ không được xoá số của nó.
final Map<ValueNotifier<double>, Object> _chuKenh = {};

class _BaoCheDayToastState extends State<BaoCheDayToast> {
  late ValueNotifier<double> _kenh = widget.kenh ?? cheDayToast;

  void _do(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final tren = box.localToGlobal(Offset.zero).dy;
    final cao = MediaQuery.sizeOf(context).height;
    _chuKenh[_kenh] = this;
    _kenh.value = math.max(0, cao - tren);
  }

  @override
  void didUpdateWidget(BaoCheDayToast old) {
    super.didUpdateWidget(old);
    _kenh = widget.kenh ?? cheDayToast;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_do);
    return widget.child;
  }

  @override
  void dispose() {
    // ⚠️ Không gán ngay: `dispose` chạy lúc cây đang khoá, gán là gọi setState lên `AppToast` giữa chừng. Microtask chạy
    // SAU cả khung (kể cả post-frame của vùng mới, nếu có) — vùng mới đã nhận quyền thì thôi.
    final kenh = _kenh;
    if (identical(_chuKenh[kenh], this)) {
      Future.microtask(() {
        if (!identical(_chuKenh[kenh], this)) return;
        _chuKenh.remove(kenh);
        kenh.value = 0;
      });
    }
    super.dispose();
  }
}
