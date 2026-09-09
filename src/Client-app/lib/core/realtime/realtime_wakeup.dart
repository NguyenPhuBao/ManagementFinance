import 'dart:async';

import 'realtime_event.dart';

/// Nối luồng sự kiện realtime vào việc đồng bộ ngay.
///
/// Tách khỏi `main.dart` để test được: đây là chỗ dễ sai nhất của cả mục —
/// gọi đồng bộ cho một sự kiện nói rằng *không có gì mới* là một vòng mạng
/// thừa ở mỗi lần trùng hoá đơn.
///
/// Không cần chống dội: `SyncEngine._runSync()` đã tự bỏ qua khi đang chạy dở.
StreamSubscription<RealtimeEvent> noiRealtimeVaoDongBo({
  required Stream<RealtimeEvent> events,
  required Future<void> Function() dongBoNgay,
}) {
  return events.listen((e) {
    if (!e.canDongBoLai) return;
    unawaited(dongBoNgay());
  });
}
