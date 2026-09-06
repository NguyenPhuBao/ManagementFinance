/// Trung tâm thông báo — trọng tâm là **đường quay lại** sau một cú vuốt xoá.
///
/// Vuốt xoá là thao tác dễ lỡ tay nhất trên một danh sách, và ở đây nó đắt hơn
/// bình thường: hàng đã xoá mềm **vẫn nằm trong bảng** để chặn trùng, nên lượt
/// quét sau nhìn thấy `dedupeKey` ấy và bỏ qua. Không có nút hoàn tác thì một
/// cú vuốt nhầm làm thông báo biến mất khỏi giao diện vĩnh viễn.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_center_page.dart';

void main() {
  const accountId = 7;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.notificationDao.insertIfAbsent(
      AppNotificationsCompanion.insert(
        id: 'n1',
        idaccount: accountId,
        kind: 'walletNegative',
        dedupeKey: 'walletNeg:vi1:2026-09-15',
        title: 'Số dư ví đang âm',
        body: 'Tiền mặt đang âm 50 nghìn.',
        severity: 'critical',
        createdAt: DateTime(2026, 9, 15, 10),
      ),
    );
  });

  tearDown(() async => db.close());

  /// ⚠️ **Không dùng `pumpAndSettle` ở file này.**
  ///
  /// Trang hiện `CircularProgressIndicator` trong lúc stream chưa phát, và một
  /// vòng quay là animation **vô hạn**: `pumpAndSettle` sẽ pump cho tới khi hết
  /// hạn 10 phút của chính nó, và `--timeout` của `flutter test` không cắt được
  /// vòng lặp ấy. Bơm một số nhịp hữu hạn là đủ cho mọi thứ ở đây.
  Future<void> nhip(WidgetTester tester, [int lan = 10]) async {
    for (var i = 0; i < lan; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Gỡ cây widget **ngay trong** test rồi bơm thêm một nhịp.
  ///
  /// Khi `StreamBuilder` huỷ đăng ký, drift đặt một timer 0 giây
  /// (`StreamQueryStore.markAsClosed`). Nếu việc gỡ ấy xảy ra lúc test kết
  /// thúc thì timer sinh ra SAU khi khung kiểm đã chốt, và `testWidgets` báo
  /// "Pending timers" — một lỗi đọc như hỏng logic nhưng thật ra chỉ là thứ tự
  /// dọn dẹp. Gỡ sớm một nhịp là timer ấy chạy xong bên trong test.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // ⚠️ `pump()` KHÔNG tham số chỉ dựng lại khung hình — nó không đẩy đồng hồ.
    // Timer của drift là một *Timer*, không phải microtask, nên nó chỉ nổ khi
    // có thời gian trôi qua. Thiếu `Duration` ở đây là test đỏ với "Pending
    // timers" và cả file kẹt lại từ đó.
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationCenterPage(
        idaccount: accountId,
        dao: db.notificationDao,
      ),
    ));
    await nhip(tester);
  }

  /// Vuốt phải sang trái — đúng chiều `DismissDirection.endToStart`.
  Future<void> vuotXoa(WidgetTester tester) async {
    await tester.drag(
        find.text('Số dư ví đang âm'), const Offset(-600, 0));
    await nhip(tester);
    // SnackBar TRƯỢT LÊN từ dưới đáy. Màn hình test chỉ cao 600px, nên chạm
    // vào nó giữa chừng hoạt ảnh sẽ rơi ra ngoài cây dựng hình và `tap()` chỉ
    // báo một dòng cảnh báo rồi đi tiếp — test đỏ ở một chỗ hoàn toàn khác.
    // Cộng thêm: `_xoaCoHoanTac` ghi CSDL xong mới gọi `showSnackBar`, nên
    // hoạt ảnh bắt đầu muộn hơn cú vuốt.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('vuốt xoá thì thông báo biến khỏi danh sách', (tester) async {
    await moTrang(tester);
    await vuotXoa(tester);

    expect(find.text('Số dư ví đang âm'), findsNothing);
    expect((await db.notificationDao.getAll(accountId)).single.dismissedAt,
        isNotNull,
        reason: 'Phải là xoá MỀM: hàng chính là bản ghi chặn trùng, xoá hẳn '
            'thì lượt quét sau sinh lại ngay và người dùng xoá mãi không hết.');
    await dongTrang(tester);
  });

  testWidgets('vuốt xoá hiện lối quay lại', (tester) async {
    await moTrang(tester);
    await vuotXoa(tester);

    expect(find.text('Hoàn tác'), findsOneWidget,
        reason: 'Không có nút này thì cú vuốt nhầm là mất hẳn — hàng vẫn ở '
            'trong bảng để chặn trùng nên không có đường nào lấy lại từ giao '
            'diện.');
    await dongTrang(tester);
  });

  testWidgets('bấm Hoàn tác thì thông báo trở lại', (tester) async {
    await moTrang(tester);
    await vuotXoa(tester);

    await tester.tap(find.text('Hoàn tác'));
    await nhip(tester);

    // Kiểm CSDL TRƯỚC giao diện: hai phép này hỏng vì hai lý do khác hẳn nhau,
    // và thứ tự này nói ngay lý do nào.
    expect((await db.notificationDao.getAll(accountId)).single.dismissedAt,
        isNull,
        reason: 'Cờ xoá mềm phải được gỡ — đây là phần việc của khoiPhuc.');
    expect(find.text('Số dư ví đang âm'), findsOneWidget,
        reason: 'Và danh sách phải tự vẽ lại: nó nghe watchFeed, nên gỡ cờ '
            'trong CSDL là đủ để hàng quay lại mà không cần ai gọi setState.');
    await dongTrang(tester);
  });

  testWidgets('chưa đăng nhập thì không đọc gì cả', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationCenterPage(idaccount: null, dao: db.notificationDao),
    ));
    await nhip(tester);

    expect(find.text('Số dư ví đang âm'), findsNothing,
        reason: 'idaccount CHỈ đến từ phiên đăng nhập. Không có thì hiển thị '
            'rỗng, tuyệt đối không mặc định về một tài khoản nào.');
    await dongTrang(tester);
  });
}
