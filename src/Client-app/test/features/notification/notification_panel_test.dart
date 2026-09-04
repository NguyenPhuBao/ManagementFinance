/// Panel thông báo rút gọn trên trang chủ.
///
/// Điều đáng canh: **rỗng thì phải biến mất hoàn toàn**. Một khung trắng có
/// tiêu đề "Thông báo" mà không có mục nào chiếm chỗ ngay giữa màn hình chính
/// và không nói được gì — tệ hơn là không có.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/presentation/widgets/notification_panel.dart';

void main() {
  AppNotification mau(String id, {String body = 'Sắp vượt ngân sách Ăn uống'}) {
    return AppNotification(
      id: id,
      idaccount: 7,
      kind: 'budgetNearLimit',
      dedupeKey: 'k-$id',
      title: 'Sắp vượt ngân sách',
      body: body,
      severity: 'warning',
      subjectType: 'budget',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
  }

  Future<void> dung(WidgetTester tester, List<AppNotification> items) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotificationPanel(
          idaccount: 7,
          feed: Stream.value(items),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không có thông báo thì panel biến mất hoàn toàn',
      (tester) async {
    await dung(tester, []);

    expect(find.byKey(const ValueKey('notification-panel')), findsNothing);
    expect(find.text('Thông báo'), findsNothing,
        reason: 'Kể cả tiêu đề cũng không được còn lại — panel rỗng chiếm chỗ '
            'ngay giữa màn hình chính mà không nói được gì.');
  });

  testWidgets('chưa đăng nhập thì cũng không hiện gì', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NotificationPanel(idaccount: null)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notification-panel')), findsNothing,
        reason: 'Không có phiên thì không có tài khoản nào để đọc thông báo. '
            'Đọc bừa là hiện thông báo của người dùng trước.');
  });

  testWidgets('có thông báo thì hiện panel kèm liên kết Xem tất cả',
      (tester) async {
    await dung(tester, [mau('n1')]);

    expect(find.byKey(const ValueKey('notification-panel')), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget,
        reason: 'Thiết kế Stitch có liên kết này ở góc phải tiêu đề.');
    expect(find.textContaining('Ăn uống'), findsOneWidget);
  });

  testWidgets('nhiều hơn ba mục thì chỉ hiện ba mục mới nhất', (tester) async {
    await dung(tester, [
      mau('n1', body: 'Mục một'),
      mau('n2', body: 'Mục hai'),
      mau('n3', body: 'Mục ba'),
      mau('n4', body: 'Mục bốn'),
      mau('n5', body: 'Mục năm'),
    ]);

    expect(find.text('Mục một'), findsOneWidget);
    expect(find.text('Mục ba'), findsOneWidget);
    expect(find.text('Mục bốn'), findsNothing,
        reason: 'Panel là bản rút gọn — tràn ra thì nó đẩy hết phần còn lại '
            'của trang chủ xuống dưới màn hình. Phần đầy đủ nằm ở "Xem tất cả".');
    expect(find.text('Mục năm'), findsNothing);
  });

  testWidgets('hiện thời gian tương đối, không phải mốc thô', (tester) async {
    await dung(tester, [mau('n1')]);

    expect(find.text('10 phút trước'), findsOneWidget,
        reason: 'Thiết kế Stitch viết "10 phút trước" — một dấu thời gian ISO '
            'ở đây thì người dùng phải tự trừ trong đầu.');
  });
}
