/// Trung tâm thông báo — thẻ *"Có N gợi ý chỉnh thông báo"* (B5b, màn Stitch
/// `65dab656…`).
///
/// Thẻ **không** phải một hàng `AppNotifications`: không chấm chưa đọc, không
/// giờ, không badge. Nạp MỘT lần lúc mở trang; bấm thì mở trang Cài đặt thông
/// báo, và quay về thì nạp lại (áp dụng ở bên kia làm đề xuất biến mất).
///
/// ⚠️ Khuôn của `notification_center_page_test`: KHÔNG `pumpAndSettle` (vòng
/// quay chờ stream là animation vô hạn) và `dongTrang()` gọi TRONG thân ca.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/hoc_gio_thong_bao.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_center_page.dart';

void main() {
  const id = 7;
  late AppDatabase db;
  late List<int> taiGoi;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    taiGoi = [];
  });

  tearDown(() async => db.close());

  Future<void> nhip(WidgetTester tester, [int lan = 10]) async {
    for (var i = 0; i < lan; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  const hai = [
    DeXuatThongBao(loai: LoaiDeXuat.gioHoaDon, gio: (gio: 20, phut: 0), soMau: 25),
    DeXuatThongBao(loai: LoaiDeXuat.tatNhom, nhom: NotificationGroup.budget, soMau: 20),
  ];

  Future<void> mo(WidgetTester tester, List<List<DeXuatThongBao>> lanNap) async {
    var lan = 0;
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, __) => NotificationCenterPage(
            idaccount: id,
            dao: db.notificationDao,
            taiDeXuat: (i) async {
              taiGoi.add(i);
              final r = lanNap[lan < lanNap.length ? lan : lanNap.length - 1];
              lan++;
              return r;
            },
          ),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (_, __) =>
              Scaffold(appBar: AppBar(), body: const Text('Trang cài đặt thông báo')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await nhip(tester);
  }

  testWidgets('⭐ 2 đề xuất → thẻ "Có 2 gợi ý chỉnh thông báo" ở trên danh sách', (tester) async {
    await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
      id: 'n1',
      idaccount: id,
      kind: 'walletNegative',
      dedupeKey: 'walletNeg:vi1:2027-01-01',
      title: 'Số dư ví đang âm',
      body: 'Tiền mặt đang âm.',
      severity: 'critical',
      createdAt: DateTime(2027, 1, 1),
    ));
    await mo(tester, const [hai]);

    expect(taiGoi, [id]);
    expect(find.text('Có 2 gợi ý chỉnh thông báo'), findsOneWidget);
    expect(tester.getRect(find.text('Có 2 gợi ý chỉnh thông báo')).top,
        lessThan(tester.getRect(find.text('Số dư ví đang âm')).top),
        reason: 'thẻ đứng đầu danh sách (màn Stitch)');
    await dongTrang(tester);
  });

  testWidgets('0 đề xuất → không thẻ', (tester) async {
    await mo(tester, const [[]]);
    expect(find.textContaining('gợi ý chỉnh thông báo'), findsNothing);
    await dongTrang(tester);
  });

  testWidgets('thẻ hiện cả khi feed rỗng', (tester) async {
    await mo(tester, const [hai]);
    expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
    expect(find.text('Có 2 gợi ý chỉnh thông báo'), findsOneWidget,
        reason: 'gợi ý nói về cài đặt, không phụ thuộc feed đang có gì');
    await dongTrang(tester);
  });

  testWidgets('bấm thẻ → mở trang Cài đặt thông báo; quay về → nạp lại', (tester) async {
    await mo(tester, const [hai, []]);
    await tester.tap(find.text('Có 2 gợi ý chỉnh thông báo'));
    await nhip(tester);
    expect(find.text('Trang cài đặt thông báo'), findsOneWidget);

    await tester.pageBack();
    await nhip(tester);
    expect(taiGoi, [id, id], reason: 'áp dụng ở trang Cài đặt làm đề xuất biến mất — '
        'không nạp lại là thẻ nói "2 gợi ý" cho thứ đã xử lý');
    expect(find.textContaining('gợi ý chỉnh thông báo'), findsNothing);
    await dongTrang(tester);
  });

  testWidgets('nạp đề xuất hỏng → trang vẫn chạy, không thẻ', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationCenterPage(
        idaccount: id,
        dao: db.notificationDao,
        taiDeXuat: (_) async => throw StateError('hỏng'),
      ),
    ));
    await nhip(tester);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.textContaining('gợi ý chỉnh thông báo'), findsNothing);
    expect(tester.takeException(), isNull);
    await dongTrang(tester);
  });
}
