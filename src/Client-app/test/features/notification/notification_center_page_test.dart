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
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
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

  /// Thêm một hàng nữa vào feed của cùng tài khoản.
  ///
  /// `kind` quyết định hàng thuộc nhóm nào khi lọc — xem `nhomCua()`.
  Future<void> them({
    required String id,
    required String kind,
    required String title,
    bool daDoc = false,
    DateTime? createdAt,
  }) async {
    await db.notificationDao.insertIfAbsent(
      AppNotificationsCompanion.insert(
        id: id,
        idaccount: accountId,
        kind: kind,
        dedupeKey: 'k-$id',
        title: title,
        body: 'Nội dung $id',
        severity: 'warning',
        createdAt: createdAt ?? DateTime(2026, 9, 14, 10),
      ),
    );
    if (daDoc) await db.notificationDao.markRead(id);
  }

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

  group('dải chip lọc', () {
    testWidgets('mỗi nhóm thông báo có ĐÚNG một chip', (tester) async {
      await moTrang(tester);

      expect(
        find.byType(ChoiceChip),
        // Hai chip không lọc theo nhóm: "Tất cả" và "Chưa đọc".
        findsNWidgets(NotificationGroup.values.length + 2),
        reason: 'Chú thích của `_Loc.kinds` hứa rằng thêm một loại mà quên xếp '
            'nhóm sẽ thành lỗi biên dịch — nhưng lưới ấy canh `nhomCua`, KHÔNG '
            'canh việc nhóm mới có chip. Nhóm `summary` thêm ngày 2026-09-09 '
            'đã lọt qua đúng khe ấy: thông báo Tổng kết tuần chỉ hiện ở "Tất '
            'cả", không lọc theo nhóm được. Đếm chip theo '
            '`NotificationGroup.values` là phép canh còn thiếu.',
      );
      // ⚠️ BẮT BUỘC — xem chú thích ở `dongTrang`. Thiếu nó là drift đặt timer
      // 0 giây sau khi khung kiểm đã chốt, và **cả tệp kẹt lại từ đó**. Lượt
      // chạy đầu không lộ ra vì `expect` ném sớm nên chưa tới chỗ này.
      await dongTrang(tester);
    });

    testWidgets('có chip Tổng kết', (tester) async {
      await moTrang(tester);
      expect(find.widgetWithText(ChoiceChip, 'Tổng kết'), findsOneWidget);
      await dongTrang(tester);
    });
  });

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

  group('lọc', () {
    testWidgets('chip nhóm thu hẹp danh sách', (tester) async {
      await them(id: 'n2', kind: 'billDueSoon', title: 'Tiền điện sắp tới hạn');
      await moTrang(tester);
      expect(find.text('Số dư ví đang âm'), findsOneWidget);
      expect(find.text('Tiền điện sắp tới hạn'), findsOneWidget);

      await tester.tap(find.text('Hoá đơn'));
      await nhip(tester);

      expect(find.text('Tiền điện sắp tới hạn'), findsOneWidget);
      expect(find.text('Số dư ví đang âm'), findsNothing,
          reason: 'walletNegative thuộc nhóm system. Phép quy đổi nhóm → kind '
              'phải đi qua nhomCua(): thêm một loại mới mà quên xếp nhóm sẽ '
              'thành lỗi biên dịch, còn đoán theo tiền tố chuỗi thì im lặng.');
      await dongTrang(tester);
    });

    testWidgets('chip Chưa đọc bỏ mục đã đọc', (tester) async {
      await them(
          id: 'n2',
          kind: 'billDueSoon',
          title: 'Tiền điện sắp tới hạn',
          daDoc: true);
      await moTrang(tester);

      await tester.tap(find.text('Chưa đọc'));
      await nhip(tester);

      expect(find.text('Số dư ví đang âm'), findsOneWidget);
      expect(find.text('Tiền điện sắp tới hạn'), findsNothing);
      await dongTrang(tester);
    });

    testWidgets('quay lại Tất cả thì danh sách đầy đủ trở lại', (tester) async {
      await them(id: 'n2', kind: 'billDueSoon', title: 'Tiền điện sắp tới hạn');
      await moTrang(tester);

      await tester.tap(find.text('Hoá đơn'));
      await nhip(tester);
      await tester.tap(find.text('Tất cả'));
      await nhip(tester);

      expect(find.text('Số dư ví đang âm'), findsOneWidget,
          reason: 'null nghĩa là KHÔNG lọc. Nếu "Tất cả" gửi xuống một danh '
              'sách kind rỗng thì màn hình trắng và không có lối quay lại.');
      await dongTrang(tester);
    });
  });

  group('phân trang', () {
    /// Kéo danh sách xuống đáy — nút "Tải thêm" là phần tử CUỐI của `ListView`
    /// nên nó chưa được dựng cho tới khi cuộn tới gần nó.
    Future<void> cuonXuongDay(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await nhip(tester);
    }

    Future<void> themTruyenHang(int soLuong) async {
      for (var i = 0; i < soLuong; i++) {
        await them(
          id: 'x$i',
          kind: 'billDueSoon',
          title: 'Mục $i',
          createdAt: DateTime(2026, 9, 10, 0, i),
        );
      }
    }

    testWidgets('còn hàng chưa tải thì hiện nút Tải thêm', (tester) async {
      await themTruyenHang(25);
      await moTrang(tester);
      await cuonXuongDay(tester);

      expect(find.text('Tải thêm'), findsOneWidget,
          reason: 'Trang đầu chỉ tải 20 hàng. Không có lối tải tiếp thì thông '
              'báo thứ 21 trở đi không xem lại được, trong khi bảng giữ dữ '
              'liệu 90 ngày.');
      await dongTrang(tester);
    });

    testWidgets('bấm Tải thêm rồi thì hết nút vì không còn hàng',
        (tester) async {
      await themTruyenHang(25);
      await moTrang(tester);
      await cuonXuongDay(tester);

      await tester.tap(find.text('Tải thêm'));
      await nhip(tester);
      await cuonXuongDay(tester);

      expect(find.text('Tải thêm'), findsNothing,
          reason: '26 hàng nằm gọn trong trang thứ hai (40). Nút còn ở đó là '
              'người dùng bấm mãi mà danh sách không dài thêm.');
      await dongTrang(tester);
    });

    testWidgets('ít hàng thì không có nút Tải thêm', (tester) async {
      await moTrang(tester);
      await cuonXuongDay(tester);

      expect(find.text('Tải thêm'), findsNothing);
      await dongTrang(tester);
    });
  });

  group('đánh dấu chưa đọc', () {
    testWidgets('nhấn giữ một mục đã đọc thì nó thành chưa đọc',
        (tester) async {
      await db.notificationDao.markRead('n1');
      await moTrang(tester);

      await tester.longPress(find.text('Số dư ví đang âm'));
      await nhip(tester);

      expect((await db.notificationDao.getAll(accountId)).single.readAt, isNull,
          reason: '"Đọc tất cả" đọc hộ CẢ những mục người dùng chưa kịp xem. '
              'Không có đường quay lại thì một cú bấm nhầm xoá sạch dấu vết '
              'những gì còn phải xử lý.');
      await dongTrang(tester);
    });

    testWidgets('nhấn giữ một mục chưa đọc thì nó thành đã đọc',
        (tester) async {
      await moTrang(tester);

      await tester.longPress(find.text('Số dư ví đang âm'));
      await nhip(tester);

      expect((await db.notificationDao.getAll(accountId)).single.readAt,
          isNotNull,
          reason: 'Cùng một cử chỉ phải đảo được cả hai chiều — một chiều thôi '
              'là người dùng không đoán được nó làm gì.');
      // ⚠️ Phép kiểm readAt ở trên MỘT MÌNH nó không đủ, và đã tự chứng minh
      // điều đó: nó xanh ngay cả khi `InkWell` chưa có `onLongPress` nào. Lý
      // do là không có recognizer nào tranh chấp thì nhấn giữ vẫn kích hoạt
      // `onTap`, mà `onTap` cũng gọi `markRead` — hai đường khác hẳn nhau cho
      // ra cùng một trạng thái CSDL. Dải báo là thứ duy nhất chỉ đường nhấn
      // giữ mới sinh ra.
      expect(find.text('Đã đánh dấu đã đọc'), findsOneWidget,
          reason: 'Nhấn giữ là cử chỉ khó phát hiện, nên dải báo là chỗ duy '
              'nhất nói cho người dùng biết vừa xảy ra chuyện gì.');
      await dongTrang(tester);
    });
  });

  testWidgets('hàng chip lọc không tràn ở bề rộng 411dp', (tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await moTrang(tester);

    expect(tester.takeException(), isNull,
        reason: 'Sáu chip không vừa 411dp — bề rộng điện thoại thật, bằng nửa '
            'khung test mặc định 800px. Flutter báo tràn qua '
            'FlutterError.reportError chứ KHÔNG ném ra chỗ gọi, nên một test '
            'chỉ pumpWidget rồi find sẽ xanh ngay cả khi màn hình đầy sọc vàng.');
    await dongTrang(tester);
  });
}
