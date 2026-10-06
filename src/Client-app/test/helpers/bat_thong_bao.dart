/// E4 (2026-10-06): các trang thôi dựng `SnackBar` mà đẩy câu vào `ThongBaoNhanh` (`baoNhanh`), và `AppToast` —
/// ở `MaterialApp.builder` của app thật — vẽ nó. Widget test dựng trang trần thì không có `AppToast`, nên kiểm câu
/// trên KÊNH: gọi [batThongBao] trong thân test (hoặc `setUp`) rồi đọc `.cau` / `.ds`.
library;

import 'dart:async';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/network/connection_monitor.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/widgets/app_toast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class BatThongBao {
  BatThongBao._(this.kenh);

  /// Kênh đã đăng ký vào `sl` — [bocToast] nghe nó.
  final ThongBaoNhanh kenh;
  final ds = <ThongDiepNhanh>[];

  List<String> get cau => [for (final t in ds) t.cau];

  /// Câu cuối cùng đã đẩy — `null` khi chưa có.
  ThongDiepNhanh? get cuoi => ds.isEmpty ? null : ds.last;
}

/// Đăng ký một [ThongBaoNhanh] mới vào `sl` (thay bản đang có) và gom mọi câu đẩy vào. Tự gỡ khi test xong.
BatThongBao batThongBao() {
  final kenh = ThongBaoNhanh();
  final bat = BatThongBao._(kenh);
  final sub = kenh.stream.listen(bat.ds.add);
  if (sl.isRegistered<ThongBaoNhanh>()) sl.unregister<ThongBaoNhanh>();
  sl.registerSingleton<ThongBaoNhanh>(kenh);
  addTearDown(() async {
    await sub.cancel();
    if (sl.isRegistered<ThongBaoNhanh>(instance: kenh)) sl.unregister<ThongBaoNhanh>(instance: kenh);
    unawaited(kenh.dispose());
  });
  return bat;
}

/// `MaterialApp(builder: bocToast(bat), …)` — dựng `AppToast` THẬT quanh trang như app thật, cho test cần thấy viên
/// hoặc BẤM nút của nó (Hoàn tác). Tự ẩn theo mặc định 4 giây của `AppToast`.
TransitionBuilder bocToast(BatThongBao bat) => (context, child) => AppToast(
      connectionEvents: const Stream<ConnectionEvent>.empty(),
      pushResults: const Stream<SyncResult>.empty(),
      realtimeEvents: const Stream<RealtimeEvent>.empty(),
      thongBaoNhanh: bat.kenh.stream,
      child: child!,
    );
