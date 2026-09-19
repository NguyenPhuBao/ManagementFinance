/// `AppToast` nhận thêm một nguồn: thông báo tự do một dòng (`ThongBaoNhanh`),
/// để những chỗ như "Nhấn lần nữa để thoát" dùng đúng viên toast của app thay
/// vì `SnackBar` dải kín ngang màn — nếp "thông báo tối giản" đã chốt.
library;

import 'dart:async';

import 'package:flowmoney/core/network/connection_monitor.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tuAn = Duration(milliseconds: 80);

  testWidgets('câu đẩy vào ThongBaoNhanh hiện thành toast rồi tự ẩn',
      (tester) async {
    final nhanh = ThongBaoNhanh();
    addTearDown(nhanh.dispose);
    final trong = StreamController<ConnectionEvent>.broadcast();
    addTearDown(trong.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppToast(
          connectionEvents: trong.stream,
          pushResults: const Stream<SyncResult>.empty(),
          realtimeEvents: const Stream<RealtimeEvent>.empty(),
          thongBaoNhanh: nhanh.stream,
          tuAnSau: tuAn,
          child: const Text('trang'),
        ),
      ),
    ));
    await tester.pump();

    nhanh.hien('Nhấn lần nữa để thoát');
    await tester.pump();
    await tester.pump();

    expect(find.text('Nhấn lần nữa để thoát'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(tuAn + thoiGianHieuUngToast + const Duration(milliseconds: 20));
    expect(find.text('Nhấn lần nữa để thoát'), findsNothing,
        reason: 'Toast tự ẩn như mọi toast khác.');
  });
}
