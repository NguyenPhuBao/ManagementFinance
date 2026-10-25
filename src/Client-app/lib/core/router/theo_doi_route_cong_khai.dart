import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart';

/// Theo dõi route TRÊN CÙNG của navigator gốc: đã đứng yên ở một route công khai (màn Đăng nhập…) chưa — tức route đó có
/// tên khớp [laCongKhai] VÀ hiệu ứng vào của nó đã xong (hoặc không có hiệu ứng). Lớp khoá ứng dụng dùng nó để biết lúc
/// nào gỡ được màn che sau khi phiên mất: gỡ sớm hơn là trang được bảo vệ (route cũ ở trạng thái `removing`, vẫn được vẽ
/// dưới trang Đăng nhập đang trượt vào) lộ ra không cần PIN.
///
/// Tên route = `settings.name` (GoRouter đặt `state.name ?? state.path`; route công khai đều ở gốc nên là đường dẫn).
class TheoDoiRouteCongKhai extends NavigatorObserver {
  TheoDoiRouteCongKhai({required this.laCongKhai});

  /// Một định nghĩa "route công khai" do chỗ dựng router truyền vào — không chép danh sách ở đây.
  final bool Function(String? tenRoute) laCongKhai;

  final ValueNotifier<bool> _dungYen = ValueNotifier<bool>(false);

  /// `true` khi route trên cùng là route công khai và hiệu ứng vào của nó đã xong.
  ValueListenable<bool> get dungYenOCongKhai => _dungYen;

  Route<dynamic>? _tren;
  Animation<double>? _hieuUng;

  void _datTren(Route<dynamic>? r) {
    _hieuUng?.removeStatusListener(_khiTrangThai);
    _tren = r;
    _hieuUng = r is TransitionRoute ? r.animation : null;
    _hieuUng?.addStatusListener(_khiTrangThai);
    _tinh();
  }

  // Hoãn một microtask: lúc `didPush`, `animation` (ProxyAnimation) báo `completed` thoáng qua rồi mới sang `forward` ngay
  // trong cùng lời gọi (đo bằng ca GoRouter thật) — đọc ngay sẽ tưởng hiệu ứng đã xong. Sau microtask thì trạng thái thật.
  void _khiTrangThai(AnimationStatus _) => scheduleMicrotask(_tinh);

  bool _daHuy = false;

  void _tinh() {
    if (_daHuy) return;
    final r = _tren;
    final h = _hieuUng;
    _dungYen.value = r != null && laCongKhai(r.settings.name) && (h == null || h.status == AnimationStatus.completed);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _datTren(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _datTren(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _tren)) _datTren(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(oldRoute, _tren)) _datTren(newRoute);
  }

  void dispose() {
    _daHuy = true;
    _hieuUng?.removeStatusListener(_khiTrangThai);
    _dungYen.dispose();
  }
}
