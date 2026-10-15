import 'dart:async';

import 'package:flutter/widgets.dart';

/// Gói vòng đời app của hệ điều hành thành một `Stream`.
///
/// ## Vì sao tách thành một lớp riêng
///
/// `NotificationScanner` nhận vòng đời **qua tham số**, đúng khuôn
/// `SyncEngine.statusStream`. Nhờ vậy test của scanner bơm được một
/// `StreamController` mà không phải dựng `WidgetsBinding`, và toàn dự án chỉ
/// có **một** chỗ chạm tới binding — cùng lý lẽ với `os_notifier_factory.dart`
/// và `flutter_local_notifications`.
///
/// ## Vì sao scanner cần vòng đời
///
/// Vòng quét trước đây bị buộc vào một sự kiện **mạng** (`SyncEngine` phát
/// trạng thái kết thúc). Trong một app offline-first thì đó là chỗ hỏng: khi
/// không có kết nối, `SyncEngine` thoát sớm ở `SyncStatus.pending` — không bao
/// giờ `isTerminal` — nên cả phiên offline không có lượt quét nào, và hai bộ
/// tự chuyển tiền chạy bên trong `scan()` cũng đứng im.
///
/// Sự kiện `resumed` là mốc duy nhất bắt được quãng app nằm trong nền: quãng
/// mà hạn hoá đơn trôi qua, ngày đổi, và kỳ trích tới nơi.
class AppLifecycleWatcher with WidgetsBindingObserver {
  AppLifecycleWatcher({WidgetsBinding? binding})
      : _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;

  /// **Broadcast, không phải một-người-nghe.** `NotificationScanner.start()`
  /// huỷ subscription cũ rồi nghe lại ở mỗi lời gọi; với stream
  /// một-người-nghe, lần nghe thứ hai ném `Stream has already been listened
  /// to` — và nó nổ ngay trên đường đăng nhập.
  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  Stream<AppLifecycleState> get stream => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller.isClosed) return;
    _controller.add(state);
  }

  /// Gỡ observer và đóng stream. Luỹ đẳng: gọi hai lần không ném.
  Future<void> dispose() async {
    _binding.removeObserver(this);
    if (_controller.isClosed) return;
    await _controller.close();
  }
}
