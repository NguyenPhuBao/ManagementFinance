/// Nối luồng sự kiện realtime vào việc đồng bộ.
///
/// Tách thành một hàm riêng thay vì viết thẳng vào `main.dart`: `main.dart`
/// không test được, mà đây lại là chỗ dễ sai nhất — gọi `syncNow()` cho một sự
/// kiện nói rằng KHÔNG có gì mới là một vòng mạng thừa ở mỗi lần trùng hoá đơn.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/realtime/realtime_wakeup.dart';

void main() {
  late StreamController<RealtimeEvent> nguon;
  late int soLanDongBo;
  StreamSubscription<RealtimeEvent>? sub;

  setUp(() {
    nguon = StreamController<RealtimeEvent>.broadcast();
    soLanDongBo = 0;
  });

  tearDown(() async {
    await sub?.cancel();
    sub = null;
    await nguon.close();
  });

  void noi() => sub = noiRealtimeVaoDongBo(
        events: nguon.stream,
        dongBoNgay: () async => soLanDongBo++,
      );

  test('giao dịch ngân hàng đánh thức đồng bộ', () async {
    noi();
    nguon.add(RealtimeEvent.giaoDichNganHang);
    await Future<void>.delayed(Duration.zero);
    expect(soLanDongBo, 1);
  });

  test('OCR xong đánh thức đồng bộ', () async {
    noi();
    nguon.add(RealtimeEvent.ocrXong);
    await Future<void>.delayed(Duration.zero);
    expect(soLanDongBo, 1);
  });

  test('OCR trùng KHÔNG đánh thức đồng bộ', () async {
    noi();
    nguon.add(RealtimeEvent.ocrTrung);
    await Future<void>.delayed(Duration.zero);
    expect(soLanDongBo, 0,
        reason: 'ocr.duplicate nói đúng điều ngược lại: không có gì được tạo. '
            'Kéo dữ liệu về sau nó là một vòng mạng thừa ở mỗi lần người dùng '
            'chụp lại một hoá đơn cũ.');
  });

  test('nhiều sự kiện thì đồng bộ nhiều lần', () async {
    noi();
    nguon
      ..add(RealtimeEvent.giaoDichNganHang)
      ..add(RealtimeEvent.ocrTrung)
      ..add(RealtimeEvent.ocrXong);
    await Future<void>.delayed(Duration.zero);
    expect(soLanDongBo, 2,
        reason: 'Hai sự kiện mang dữ liệu mới, một sự kiện thì không. '
            'SyncEngine tự chống chạy chồng nhau nên không cần gộp ở đây.');
  });

  test('huỷ đăng ký thì thôi đồng bộ', () async {
    noi();
    await sub!.cancel();
    sub = null;

    nguon.add(RealtimeEvent.giaoDichNganHang);
    await Future<void>.delayed(Duration.zero);

    expect(soLanDongBo, 0,
        reason: 'Hàm phải TRẢ VỀ subscription chứ không nuốt mất nó — nơi gọi '
            'cần huỷ được.');
  });
}
