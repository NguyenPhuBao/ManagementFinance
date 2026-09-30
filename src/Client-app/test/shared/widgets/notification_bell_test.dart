/// Chuông thông báo dùng chung.
///
/// Vì sao cần: trước đây chấm đỏ ở `home_page.dart` được vẽ **cứng** — luôn
/// hiện dù chẳng có thông báo nào. Một chấm đỏ luôn sáng dạy người dùng bỏ qua
/// nó, và khi thông báo thật xuất hiện thì không ai còn để ý nữa.
///
/// App có ba chuông ở ba trang (home, goal, profile), trước đây là ba đoạn chép
/// tay khác nhau. Gom về một widget là điều kiện để chấm đỏ nhất quán.
///
/// Từ 2026-09-30 chấm đỏ thành **số đếm** (việc duy nhất client nhận từ
/// `docs/Notification/Notification_Client-app.md` §3.5 A): 0 → ẩn, 1–99 → đúng
/// số, > 99 → `99+`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/shared/widgets/notification_bell.dart';

void main() {
  const soKey = ValueKey('notification-bell-so');

  Future<void> dung(
    WidgetTester tester, {
    Stream<int>? unreadCount,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: NotificationBell(unreadCount: unreadCount, onTap: onTap)),
      ),
    ));
    await tester.pump();
  }

  group('nhanSoChuaDoc', () {
    test('0 và số âm → null (ẩn)', () {
      expect(nhanSoChuaDoc(0), isNull);
      expect(nhanSoChuaDoc(-3), isNull);
    });
    test('1 … 99 → đúng số', () {
      expect(nhanSoChuaDoc(1), '1');
      expect(nhanSoChuaDoc(44), '44');
      expect(nhanSoChuaDoc(99), '99');
    });
    test('> 99 → 99+', () {
      expect(nhanSoChuaDoc(100), '99+');
      expect(nhanSoChuaDoc(12345), '99+');
    });
  });

  testWidgets('không có thông báo chưa đọc thì KHÔNG có số', (tester) async {
    await dung(tester, unreadCount: Stream.value(0));

    expect(find.byKey(soKey), findsNothing,
        reason: 'Dấu vẽ cứng như bản cũ khiến người dùng quen bỏ qua nó.');
    expect(find.byIcon(Icons.notifications), findsOneWidget);
  });

  testWidgets('⭐ có thông báo chưa đọc thì hiện ĐÚNG số', (tester) async {
    await dung(tester, unreadCount: Stream.value(44));

    expect(find.byKey(soKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(soKey), matching: find.text('44')), findsOneWidget);
  });

  testWidgets('trên 99 hiện 99+, và nút chuông không phình quá 48 × 48', (tester) async {
    await dung(tester, unreadCount: Stream.value(250));

    expect(find.text('99+'), findsOneWidget);
    final nut = tester.getSize(find.byType(NotificationBell));
    expect(nut, const Size(48, 48), reason: 'số dài không được đẩy các nút khác trên thanh tiêu đề');
    expect(tester.takeException(), isNull);
  });

  testWidgets('số bám theo dòng dữ liệu, không chụp một lần', (tester) async {
    final ctrl = StreamController<int>();
    addTearDown(ctrl.close);

    await dung(tester, unreadCount: ctrl.stream);
    ctrl.add(2);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    ctrl.add(7);
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);

    // Người dùng đọc hết ở màn khác → số phải tắt mà không cần rời trang.
    ctrl.add(0);
    await tester.pumpAndSettle();
    expect(find.byKey(soKey), findsNothing);
  });

  testWidgets('trình đọc màn hình nghe được số chưa đọc', (tester) async {
    final h = tester.ensureSemantics();
    await dung(tester, unreadCount: Stream.value(3));
    expect(find.bySemanticsLabel('Thông báo, 3 chưa đọc'), findsOneWidget);
    h.dispose();
  });

  testWidgets('chưa đăng nhập thì không số và bấm không làm gì', (tester) async {
    var soLanBam = 0;
    await dung(tester, unreadCount: null, onTap: () => soLanBam++);

    expect(find.byKey(soKey), findsNothing,
        reason: 'Không có phiên thì không có tài khoản nào để đếm thông báo — '
            'theo đúng tinh thần currentAccountIdOrNull.');

    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pump();
    expect(soLanBam, 0);
  });

  testWidgets('bấm chuông gọi đúng callback khi đã đăng nhập', (tester) async {
    var soLanBam = 0;
    await dung(
      tester,
      unreadCount: Stream.value(1),
      onTap: () => soLanBam++,
    );

    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pump();
    expect(soLanBam, 1);
  });
}
