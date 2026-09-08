/// Trang cài đặt thông báo.
///
/// Ba điều đáng canh, không cái nào làm app chết:
///
/// 1. **Công tắc phải phản ánh thứ đã lưu.** Một trang cài đặt hiện sai trạng
///    thái tệ hơn là không có trang nào: người dùng tưởng đã tắt rồi vẫn bị làm
///    phiền, hoặc tưởng đã bật mà chẳng nhận được gì.
/// 2. **Bật công tắc hệ điều hành phải xin quyền ngay lúc đó.** Đây là chỗ
///    DUY NHẤT trong app xin quyền. Không có nó thì trên Android 13+ mọi thông
///    báo bị nuốt im lặng, và trên iOS người dùng không bao giờ được hỏi.
/// 3. **Chưa đăng nhập thì không đọc, không ghi.** `idaccount` chỉ đến từ phiên
///    đăng nhập; mặc định về 1 là ghi tuỳ chọn vào hồ sơ tài khoản admin thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_settings_page.dart';

class _OsGia implements OsNotifier {
  int soLanXinQuyen = 0;
  bool traVe = true;

  /// Hệ điều hành có đang cho phép hay không — tách khỏi [traVe] vì "đang cho
  /// phép" và "chịu cấp khi được xin" là hai chuyện khác nhau.
  bool coQuyen = true;
  int soLanHoiQuyen = 0;

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async {
    soLanXinQuyen++;
    return traVe;
  }

  @override
  Future<bool> daCoQuyen() async {
    soLanHoiQuyen++;
    return coQuyen;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  // Hai thành viên của cú chạm — bản giả này không dựng kịch bản chạm nào.
  @override
  Stream<String> get payloadDaCham => const Stream<String>.empty();

  @override
  Future<String?> payloadKhoiDong() async => null;

  @override
  Future<Set<int>> pendingIds() async => const {};

  // Hai thành viên của badge — bản giả này không canh badge, xem
  // badge_updater_test.dart.
  @override
  Future<Set<int>> activeIds() async => const {};

  @override
  Future<void> datBadge(int soLuong) async {}

  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

void main() {
  const accountId = 7;

  late InMemoryNotificationPrefsStore store;
  late _OsGia os;

  setUp(() {
    store = InMemoryNotificationPrefsStore();
    os = _OsGia();
  });

  Future<void> moTrang(WidgetTester tester, {int? idaccount = accountId}) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsPage(
        idaccount: idaccount,
        store: store,
        osNotifier: os,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('hiển thị', () {
    testWidgets('có công tắc tổng và bốn công tắc nhóm', (tester) async {
      await moTrang(tester);

      expect(find.byKey(NotificationSettingsPage.khoaCongTacOs), findsOneWidget);
      for (final nhom in NotificationGroup.values) {
        expect(find.byKey(NotificationSettingsPage.khoaCongTacNhom(nhom)),
            findsOneWidget,
            reason: 'Thiếu công tắc cho nhóm ${nhom.name} thì người dùng không '
                'tắt riêng được nhóm ấy, và lựa chọn duy nhất còn lại là tắt '
                'hết.');
      }
    });

    testWidgets('quyền bị thu hồi thì công tắc KHÔNG được sáng', (tester) async {
      await store.write(accountId, const NotificationPrefs(osBat: true));
      os.coQuyen = false;

      await moTrang(tester);

      final sw = tester.widget<Switch>(
          find.byKey(NotificationSettingsPage.khoaCongTacOs));
      expect(sw.value, isFalse,
          reason: 'Người dùng có thể thu hồi quyền trong Cài đặt của máy sau '
              'khi đã bật công tắc. Để nó sáng là nói dối: họ tin mình đang '
              'nhận thông báo và sẽ không bao giờ đi tìm lý do vì sao chẳng '
              'thấy gì.');
      expect(os.soLanXinQuyen, 0,
          reason: 'Chỉ HỎI, tuyệt đối không XIN lúc mở trang — trên iOS người '
              'dùng chỉ được hỏi một lần trong cả vòng đời cài đặt.');
    });

    testWidgets('quyền bị thu hồi KHÔNG ghi đè tuỳ chọn đã lưu',
        (tester) async {
      await store.write(accountId, const NotificationPrefs(osBat: true));
      os.coQuyen = false;

      await moTrang(tester);

      expect((await store.read(accountId)).osBat, isTrue,
          reason: 'Công tắc hiển thị sự thật, nhưng ý muốn của người dùng thì '
              'giữ nguyên: cấp lại quyền trong Cài đặt máy là thông báo chạy '
              'lại ngay, không bắt họ vào đây gạt lại lần nữa.');
    });

    testWidgets('còn quyền thì công tắc phản ánh đúng tuỳ chọn', (tester) async {
      await store.write(accountId, const NotificationPrefs(osBat: true));
      os.coQuyen = true;

      await moTrang(tester);

      final sw = tester.widget<Switch>(
          find.byKey(NotificationSettingsPage.khoaCongTacOs));
      expect(sw.value, isTrue);
    });

    testWidgets('giờ im lặng tắt sẵn và chưa hiện hai mốc giờ', (tester) async {
      await moTrang(tester);

      final congTac = tester.widget<Switch>(
          find.byKey(NotificationSettingsPage.khoaCongTacImLang));
      expect(congTac.value, isFalse,
          reason: 'Bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài — cảnh '
              'báo lúc 23h thôi hiện ra ngoài mà không ai báo.');
      expect(find.text('Từ'), findsNothing,
          reason: 'Hai mốc giờ không có ý nghĩa gì khi công tắc còn tắt; hiện '
              'chúng ra là mời người dùng chỉnh một thứ không có tác dụng.');
    });

    testWidgets('bật giờ im lặng thì hiện hai mốc và ghi ngay', (tester) async {
      await moTrang(tester);

      await tester
          .ensureVisible(find.byKey(NotificationSettingsPage.khoaCongTacImLang));
      await tester.tap(find.byKey(NotificationSettingsPage.khoaCongTacImLang));
      await tester.pumpAndSettle();

      expect((await store.read(accountId)).imLangBat, isTrue,
          reason: 'Trang này không có nút Lưu; mỗi thay đổi phải xuống kho '
              'ngay.');
      expect(find.text('Từ'), findsOneWidget);
      expect(find.text('Đến'), findsOneWidget);
    });

    testWidgets('nói rõ báo tự chuyển tiền không tắt được', (tester) async {
      await moTrang(tester);

      expect(find.textContaining('luôn được bật'), findsOneWidget,
          reason: 'Bốn loại báo tiền vừa rời ví cố ý bỏ qua công tắc nhóm. Im '
              'lặng về ngoại lệ ấy là để người dùng gạt tắt rồi tin rằng mình '
              'đã tắt — một công tắc nói dối theo chiều ngược lại.');
    });

    testWidgets('mô tả nhóm không hứa những gì công tắc không làm được',
        (tester) async {
      await moTrang(tester);

      expect(find.textContaining('Sắp đến hạn và quá hạn.'), findsOneWidget,
          reason: 'Mô tả cũ liệt kê đúng hai loại này, nhưng công tắc khi ấy '
              'còn tắt cả báo tự thanh toán. Nay hành vi khớp với câu chữ.');
    });

    testWidgets('công tắc phản ánh đúng thứ đã lưu', (tester) async {
      await store.write(
        accountId,
        const NotificationPrefs(
          osBat: false,
          nhomTat: {NotificationGroup.goal},
        ),
      );

      await moTrang(tester);

      final swOs = tester.widget<Switch>(
          find.byKey(NotificationSettingsPage.khoaCongTacOs));
      final swGoal = tester.widget<Switch>(find
          .byKey(NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.goal)));
      final swBill = tester.widget<Switch>(find
          .byKey(NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.bill)));

      expect(swOs.value, isFalse);
      expect(swGoal.value, isFalse);
      expect(swBill.value, isTrue,
          reason: 'Trang hiện sai trạng thái tệ hơn là không có trang nào — '
              'người dùng tưởng đã tắt rồi vẫn bị làm phiền.');
    });

    testWidgets('hiện giờ nhắc và số ngày nhắc đã lưu', (tester) async {
      await store.write(
        accountId,
        const NotificationPrefs(
            gioNhac: 21, phutNhac: 30, soNgayNhacHoaDon: 7),
      );

      await moTrang(tester);

      expect(find.text('21:30'), findsOneWidget);
      expect(find.textContaining('7 ngày'), findsWidgets);
    });
  });

  group('ghi lại lựa chọn', () {
    testWidgets('tắt một nhóm thì ghi ngay vào kho', (tester) async {
      await moTrang(tester);

      await tester.tap(find
          .byKey(NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.budget)));
      await tester.pumpAndSettle();

      final daLuu = await store.read(accountId);
      expect(daLuu.batNhom(NotificationGroup.budget), isFalse,
          reason: 'Ghi ngay chứ không đợi nút Lưu: trang cài đặt không có nút '
              'nào như vậy, nên người dùng sẽ rời trang và tưởng đã xong.');
      expect(daLuu.batNhom(NotificationGroup.bill), isTrue,
          reason: 'Tắt một nhóm không được chạm tới nhóm khác.');
    });

    testWidgets('bật lại nhóm vừa tắt thì kho trở về như cũ', (tester) async {
      await store.write(accountId,
          const NotificationPrefs(nhomTat: {NotificationGroup.budget}));
      await moTrang(tester);

      await tester.tap(find
          .byKey(NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.budget)));
      await tester.pumpAndSettle();

      expect((await store.read(accountId)).batNhom(NotificationGroup.budget),
          isTrue);
    });

    testWidgets('tắt công tắc tổng thì ghi osBat = false', (tester) async {
      await moTrang(tester);

      await tester.tap(find.byKey(NotificationSettingsPage.khoaCongTacOs));
      await tester.pumpAndSettle();

      expect((await store.read(accountId)).osBat, isFalse);
    });
  });

  group('ngưỡng số dư ví thấp', () {
    testWidgets('mặc định hiện là TẮT', (tester) async {
      await moTrang(tester);

      expect(find.text('Cảnh báo số dư thấp'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<int>>(
                find.byKey(NotificationSettingsPage.khoaNguongSoDu))
            .value,
        0,
        reason: 'Mặc định của tuỳ chọn là 0 = tắt. Hiện một số tiền nào đó khi '
            'người dùng chưa đặt gì là nói dối về trạng thái thật.',
      );
    });

    testWidgets('ngưỡng đã lưu được hiện lại', (tester) async {
      await store.write(
          accountId, const NotificationPrefs(nguongSoDuThap: 200000));

      await moTrang(tester);

      expect(
        tester
            .widget<DropdownButton<int>>(
                find.byKey(NotificationSettingsPage.khoaNguongSoDu))
            .value,
        200000,
      );
    });

    testWidgets('đổi ngưỡng thì ghi ngay vào kho', (tester) async {
      await moTrang(tester);

      // Thẻ này nằm cuối một trang cuộn được, nên ở 800px của môi trường test
      // nó nằm dưới mép màn hình và `tap` sẽ trượt ra nền.
      await tester
          .ensureVisible(find.byKey(NotificationSettingsPage.khoaNguongSoDu));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(NotificationSettingsPage.khoaNguongSoDu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100.000 ₫').last);
      await tester.pumpAndSettle();

      expect((await store.read(accountId)).nguongSoDuThap, 100000,
          reason: 'Ghi ngay chứ không đợi nút Lưu — trang này không có nút nào '
              'như vậy, đúng khuôn của mọi mục còn lại.');
    });
  });

  group('xin quyền', () {
    testWidgets('BẬT công tắc tổng thì xin quyền hệ điều hành', (tester) async {
      await store.write(accountId, const NotificationPrefs(osBat: false));
      await moTrang(tester);

      await tester.tap(find.byKey(NotificationSettingsPage.khoaCongTacOs));
      await tester.pumpAndSettle();

      expect(os.soLanXinQuyen, 1,
          reason: 'Đây là chỗ DUY NHẤT trong app xin quyền thông báo. Không có '
              'nó thì trên Android 13+ mọi thông báo bị nuốt im lặng, và trên '
              'iOS người dùng không bao giờ được hỏi.');
    });

    testWidgets('TẮT công tắc tổng thì không xin quyền', (tester) async {
      await moTrang(tester);

      await tester.tap(find.byKey(NotificationSettingsPage.khoaCongTacOs));
      await tester.pumpAndSettle();

      expect(os.soLanXinQuyen, 0,
          reason: 'Hỏi quyền lúc người dùng vừa nói "không" là quấy rối, và '
              'trên iOS còn đốt mất lần hỏi duy nhất được phép.');
    });

    testWidgets('người dùng từ chối quyền thì công tắc quay về tắt',
        (tester) async {
      os.traVe = false;
      await store.write(accountId, const NotificationPrefs(osBat: false));
      await moTrang(tester);

      await tester.tap(find.byKey(NotificationSettingsPage.khoaCongTacOs));
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(
          find.byKey(NotificationSettingsPage.khoaCongTacOs));
      expect(sw.value, isFalse,
          reason: 'Để công tắc sáng khi hệ điều hành đã chặn là nói dối người '
              'dùng: họ tưởng đã bật và sẽ không bao giờ đi tìm lý do vì sao '
              'chẳng nhận được gì.');
      expect((await store.read(accountId)).osBat, isFalse);
    });
  });

  group('nhắc ghi chép hằng ngày', () {
    /// ⚠️ Thẻ này nằm **cuối** trang cuộn. Ở khung test 800×600 nó rơi dưới mép
    /// màn hình, và `tap()` vào một widget ngoài khung chỉ in một dòng cảnh báo
    /// rồi đi tiếp — test sẽ đỏ ở phép kiểm phía sau, không ở dòng `tap()`.
    Future<void> keoToi(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    testWidgets('công tắc tắt sẵn', (tester) async {
      await moTrang(tester);

      final f = find.byKey(NotificationSettingsPage.khoaCongTacGhiChep);
      await keoToi(tester, f);

      expect(tester.widget<Switch>(f).value, isFalse,
          reason: 'Bật sẵn là mọi bản đã cài bỗng nhiên nhận một thông báo mỗi '
              'ngày mà không ai báo trước.');
    });

    testWidgets('bật công tắc thì ghi ngay, không cần nút Lưu', (tester) async {
      await moTrang(tester);
      final f = find.byKey(NotificationSettingsPage.khoaCongTacGhiChep);
      await keoToi(tester, f);

      await tester.tap(f);
      await tester.pumpAndSettle();

      expect((await store.read(accountId)).nhacGhiChepBat, isTrue);
    });

    testWidgets('hàng chọn giờ chỉ hiện khi công tắc BẬT', (tester) async {
      await moTrang(tester);
      expect(find.byKey(NotificationSettingsPage.khoaGioGhiChep), findsNothing,
          reason: 'Mời người dùng chỉnh một thứ không có tác dụng là cách '
              'nhanh nhất để họ mất tin vào trang cài đặt — cùng lý lẽ đã dùng '
              'cho hai mốc giờ im lặng.');

      final f = find.byKey(NotificationSettingsPage.khoaCongTacGhiChep);
      await keoToi(tester, f);
      await tester.tap(f);
      await tester.pumpAndSettle();

      expect(
          find.byKey(NotificationSettingsPage.khoaGioGhiChep), findsOneWidget);
    });

    testWidgets('giờ hiện đúng mặc định 20:00', (tester) async {
      await store.write(accountId, const NotificationPrefs(nhacGhiChepBat: true));
      await moTrang(tester);

      final f = find.byKey(NotificationSettingsPage.khoaGioGhiChep);
      await keoToi(tester, f);

      expect(find.descendant(of: f, matching: find.text('20:00')),
          findsOneWidget,
          reason: 'Giờ RIÊNG, không phải gioNhac (mặc định 08:00). Hiện nhầm '
              'giờ hoá đơn ở đây là người dùng tưởng đã đặt xong buổi tối '
              'trong khi lời nhắc nổ lúc sáng sớm.');
    });
  });

  group('chưa đăng nhập', () {
    testWidgets('không hiện công tắc và không ghi gì', (tester) async {
      await moTrang(tester, idaccount: null);

      expect(find.byKey(NotificationSettingsPage.khoaCongTacOs), findsNothing);
      expect(find.textContaining('đăng nhập'), findsWidgets,
          reason: 'Phải nói rõ vì sao trang trống, nếu không nó trông như lỗi.');
      expect(store.values, isEmpty,
          reason: 'idaccount CHỈ đến từ phiên đăng nhập. Mặc định về 1 là ghi '
              'tuỳ chọn vào hồ sơ tài khoản admin thật.');
    });
  });
}
