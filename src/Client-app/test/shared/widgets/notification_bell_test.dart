/// Chuông thông báo dùng chung.
///
/// Vì sao cần: trước đây chấm đỏ ở `home_page.dart` được vẽ **cứng** — luôn
/// hiện dù chẳng có thông báo nào. Một chấm đỏ luôn sáng dạy người dùng bỏ qua
/// nó, và khi thông báo thật xuất hiện thì không ai còn để ý nữa.
///
/// App có ba chuông ở ba trang (home, goal, profile), trước đây là ba đoạn chép
/// tay khác nhau. Gom về một widget là điều kiện để chấm đỏ nhất quán.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/shared/widgets/notification_bell.dart';

void main() {
  Future<void> dung(
    WidgetTester tester, {
    Stream<int>? unreadCount,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotificationBell(unreadCount: unreadCount, onTap: onTap),
      ),
    ));
    await tester.pump();
  }

  testWidgets('không có thông báo chưa đọc thì KHÔNG có chấm đỏ',
      (tester) async {
    await dung(tester, unreadCount: Stream.value(0));

    expect(find.byKey(const ValueKey('notification-bell-dot')), findsNothing,
        reason: 'Chấm đỏ vẽ cứng như bản cũ khiến người dùng quen bỏ qua nó.');
    expect(find.byIcon(Icons.notifications), findsOneWidget);
  });

  testWidgets('có thông báo chưa đọc thì hiện chấm đỏ', (tester) async {
    await dung(tester, unreadCount: Stream.value(3));

    expect(find.byKey(const ValueKey('notification-bell-dot')), findsOneWidget);
  });

  testWidgets('chấm đỏ bám theo dòng dữ liệu, không chụp một lần',
      (tester) async {
    final ctrl = StreamController<int>();
    addTearDown(ctrl.close);

    await dung(tester, unreadCount: ctrl.stream);
    ctrl.add(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-bell-dot')), findsOneWidget);

    // Người dùng đọc hết ở màn khác → chấm phải tắt mà không cần rời trang.
    ctrl.add(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-bell-dot')), findsNothing);
  });

  testWidgets('chưa đăng nhập thì không chấm và bấm không làm gì',
      (tester) async {
    var soLanBam = 0;
    await dung(tester, unreadCount: null, onTap: () => soLanBam++);

    expect(find.byKey(const ValueKey('notification-bell-dot')), findsNothing,
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
