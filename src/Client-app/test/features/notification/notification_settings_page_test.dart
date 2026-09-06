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
