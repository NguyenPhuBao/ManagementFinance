/// D1 — mở trung tâm thông báo (lọc nhóm Biến động) khi người dùng chạm thông báo tóm tắt *"Có N biến động số dư
/// mới"* (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.4).
///
/// Thông báo tóm tắt do **Kotlin** bắn (`BienDongListenerService`), không qua `flutter_local_notifications`, nên
/// `NotificationTapRouter` không thấy cú chạm ấy. Kotlin đặt một cờ trên `MainActivity` (lúc khởi động, hoặc
/// `onNewIntent` khi app nằm nền) và [KenhBienDong.moTuThongBao] đọc nó — đọc là **tiêu**. Nên lớp này hỏi ở hai lúc:
/// [start] (app vừa mở) và mỗi lần `resumed` (app từ nền lên). Chưa đăng nhập thì giữ lại tới khi có phiên — cùng
/// luật `NotificationTapRouter._choDoi`, và cũng chỉ giữ MỘT.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'kenh_bien_dong.dart';

/// Đích của cú chạm tóm tắt và của thẻ *"Có N biến động chưa ghi"* ở Sổ giao dịch.
const String kRouteBienDongChuaGhi = '/notifications?nhom=bienDong';

class MoTuTomTatBienDong {
  MoTuTomTatBienDong({
    required this.kenh,
    required this.dieuHuong,
    required this.dangDangNhap,
    required this.phienDoi,
    required this.vongDoi,
  });

  final KenhBienDong kenh;
  final void Function(String route) dieuHuong;
  final bool Function() dangDangNhap;

  /// Mỗi lần trạng thái phiên đổi (`AuthBloc.stream`).
  final Stream<void> phienDoi;
  final Stream<AppLifecycleState> vongDoi;

  StreamSubscription<void>? _subPhien;
  StreamSubscription<AppLifecycleState>? _subVongDoi;
  bool _choDoi = false;

  Future<void> start() async {
    await stop();
    _subPhien = phienDoi.listen((_) => _xaChoDoi());
    _subVongDoi = vongDoi.listen((s) {
      if (s == AppLifecycleState.resumed) unawaited(_hoi());
    });
    await _hoi();
  }

  Future<void> stop() async {
    await _subPhien?.cancel();
    _subPhien = null;
    await _subVongDoi?.cancel();
    _subVongDoi = null;
    _choDoi = false;
  }

  Future<void> _hoi() async {
    bool co;
    try {
      co = await kenh.moTuThongBao();
    } catch (_) {
      return;
    }
    if (!co) return;
    if (dangDangNhap()) {
      dieuHuong(kRouteBienDongChuaGhi);
    } else {
      _choDoi = true;
    }
  }

  void _xaChoDoi() {
    if (!_choDoi || !dangDangNhap()) return;
    _choDoi = false;
    dieuHuong(kRouteBienDongChuaGhi);
  }
}
