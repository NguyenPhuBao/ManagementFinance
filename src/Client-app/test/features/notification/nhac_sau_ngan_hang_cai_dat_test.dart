/// Nhắc ghi sau khi dùng app ngân hàng — màn đồng ý + công tắc ở Cài đặt thông báo (spec 2026-10-03 §3.1).
///
/// Ba điều đáng canh, cả ba hỏng im lặng:
/// 1. **Không đồng ý thì cờ máy không bao giờ được bật** (`datBat(true)`).
/// 2. **Mỗi lần bật đặt mốc đã xét = lúc bật** — không thì lần bật đầu đổ phiên cũ (tới 7 ngày) thành dòng nhắc.
/// 3. **Dòng quyền nói sự thật của máy** và nút *Mở Cài đặt* mở ĐÚNG trang (*Truy cập dữ liệu sử dụng*, không phải
///    *Truy cập thông báo* của D1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/kenh_bien_dong.dart';
import 'package:flowmoney/core/notification/kenh_phien_ngan_hang.dart';
import 'package:flowmoney/core/notification/moc_phien_store.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/phien_ngan_hang.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/presentation/pages/dong_y_nhac_sau_ngan_hang_page.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_settings_page.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';

class _KenhPhienGia implements KenhPhienNganHang {
  bool quyen = false;
  final List<(bool, DateTime?)> datBatGoi = [];
  int soLanMoCaiDat = 0;

  @override
  Future<bool> coQuyen() async => quyen;
  @override
  Future<void> moCaiDat() async => soLanMoCaiDat++;
  @override
  Future<List<SuKienSuDung>> suKien(DateTime tu) async => const [];
  @override
  Future<DateTime?> boDen() async => null;
  @override
  Future<void> datBat(bool bat, {DateTime? daXetDen}) async => datBatGoi.add((bat, daXetDen));
  @override
  Future<void> huyNhac() async {}
}

class _KenhBienDongGia extends KenhBienDongTrong {
  _KenhBienDongGia();
  bool quyen = false;
  bool chayNen = true;
  int soLanMoCaiDat = 0;

  @override
  Future<bool> coQuyen() async => quyen;
  @override
  Future<bool> duocChayNen() async => chayNen;
  @override
  Future<void> moCaiDat() async => soLanMoCaiDat++;
}

class _OsGia extends Fake implements OsNotifier {
  @override
  Future<bool> daCoQuyen() async => true;
}

void main() {
  group('màn đồng ý', () {
    Future<void> moMan(WidgetTester tester, void Function(Object?) nhan) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => nhan(await Navigator.of(ctx)
                .push<bool>(MaterialPageRoute(builder: (_) => const DongYNhacSauNganHangPage()))),
            child: const Text('mở'),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
    }

    testWidgets('⭐ liệt kê ĐÚNG các app đang theo dõi (danh sách D1), bốn cam kết, hai nút', (tester) async {
      await moMan(tester, (_) {});
      for (final n in nguonDangDoc) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('CHỈ XEM GIỜ MỞ CỦA ${nguonDangDoc.length} APP'), findsOneWidget);
      expect(kCamKetNhacSauNganHang, hasLength(4));
      for (final c in kCamKetNhacSauNganHang) {
        expect(find.text(c), findsOneWidget);
      }
      expect(find.text('Đồng ý và mở Cài đặt'), findsOneWidget);
      expect(find.text('Không, cảm ơn'), findsOneWidget);
    });

    testWidgets('Đồng ý → true; Không, cảm ơn → false', (tester) async {
      Object? kq = 'chưa';
      await moMan(tester, (v) => kq = v);
      await tester.ensureVisible(find.text('Đồng ý và mở Cài đặt'));
      await tester.tap(find.text('Đồng ý và mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(kq, isTrue);
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Không, cảm ơn'));
      await tester.tap(find.text('Không, cảm ơn'));
      await tester.pumpAndSettle();
      expect(kq, isFalse);
    });

    testWidgets('không tràn ở 360 × 640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await moMan(tester, (_) {});
      expect(tester.takeException(), isNull);
    });

    testWidgets('⭐ thanh tiêu đề NGẮN — không dài hơn tiêu đề màn đồng ý D1', (tester) async {
      await moMan(tester, (_) {});
      final thanh = tester.widget<Text>(
          find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first);
      expect(thanh.data, kTieuDeThanhNhacSauNganHang);
      // So độ dài chứ không đo bề rộng: font của bộ test rộng gấp đôi ngoài đời (bẫy 4.4), ở 360 dp chuỗi nào cũng
      // cụt. "Đọc biến động số dư" là tiêu đề đã chứng minh vừa trên máy thật.
      expect(kTieuDeThanhNhacSauNganHang.length, lessThanOrEqualTo('Đọc biến động số dư'.length),
          reason: 'Nghiệm thu Realme 2026-10-03 (360 dp): tên đầy đủ "Nhắc ghi sau khi dùng app ngân hàng" cụt thành '
              '"…app ngân h…" trên thanh tiêu đề. Người dùng chọn rút gọn; tên đầy đủ vẫn ở khối Cài đặt.');
    });
  });

  group('công tắc ở Cài đặt thông báo', () {
    const id = 7;
    late InMemoryNotificationPrefsStore store;
    late InMemoryMocPhienStore moc;
    late _KenhPhienGia kenh;
    late _KenhBienDongGia kenhBienDong;

    setUp(() {
      store = InMemoryNotificationPrefsStore();
      moc = InMemoryMocPhienStore();
      kenh = _KenhPhienGia();
      kenhBienDong = _KenhBienDongGia();
    });

    const khoa = NotificationSettingsPage.khoaCongTacNhacSauNganHang;

    Future<void> moTrang(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NotificationSettingsPage(
          key: UniqueKey(), // dựng lại STATE mỗi lần — trang đọc tuỳ chọn ở initState
          idaccount: id,
          store: store,
          osNotifier: _OsGia(),
          kenhBienDong: kenhBienDong,
          kenhPhienNganHang: kenh,
          mocPhien: moc,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> gat(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(khoa));
      await tester.tap(find.byKey(khoa));
      await tester.pumpAndSettle();
    }

    bool giaTri(WidgetTester tester) => tester.widget<Switch>(find.byKey(khoa)).value;

    testWidgets('⭐ bật lần đầu → màn đồng ý; Không, cảm ơn → vẫn tắt, KHÔNG bật cờ máy, KHÔNG đặt mốc', (tester) async {
      await moTrang(tester);
      await gat(tester);
      expect(find.byType(DongYNhacSauNganHangPage), findsOneWidget);
      await tester.ensureVisible(find.text('Không, cảm ơn'));
      await tester.tap(find.text('Không, cảm ơn'));
      await tester.pumpAndSettle();
      expect(giaTri(tester), isFalse);
      final p = await store.read(id);
      expect((p.nhacSauNganHang, p.dongYNhacSauNganHang), (false, false));
      expect(kenh.datBatGoi, isEmpty);
      expect(moc.values, isEmpty);
    });

    testWidgets('bật lần đầu rồi Back → như không đồng ý', (tester) async {
      await moTrang(tester);
      await gat(tester);
      await tester.tap(find.byTooltip('Quay lại').last);
      await tester.pumpAndSettle();
      expect(giaTri(tester), isFalse);
      expect(kenh.datBatGoi, isEmpty);
    });

    testWidgets('⭐ Đồng ý → lưu hai cờ, mốc = lúc bật, bật cờ máy với mốc ấy, mở Cài đặt (chưa có quyền)',
        (tester) async {
      await moTrang(tester);
      final truoc = DateTime.now();
      await gat(tester);
      await tester.ensureVisible(find.text('Đồng ý và mở Cài đặt'));
      await tester.tap(find.text('Đồng ý và mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(giaTri(tester), isTrue);
      final p = await store.read(id);
      expect((p.nhacSauNganHang, p.dongYNhacSauNganHang), (true, true));
      final m = moc.values[id];
      expect(m, isNotNull);
      expect(m!.isBefore(truoc), isFalse, reason: 'phiên trước lúc bật không bao giờ được nhắc');
      expect(kenh.datBatGoi, [(true, m)]);
      expect(kenh.soLanMoCaiDat, 1);
      expect(kenhBienDong.soLanMoCaiDat, 0, reason: 'không mở nhầm trang Truy cập thông báo của D1');
      expect(find.text('Chưa cấp quyền truy cập dữ liệu sử dụng'), findsOneWidget);
    });

    testWidgets('Đồng ý khi máy ĐÃ có quyền → không mở Cài đặt thừa', (tester) async {
      kenh.quyen = true;
      await moTrang(tester);
      await gat(tester);
      await tester.ensureVisible(find.text('Đồng ý và mở Cài đặt'));
      await tester.tap(find.text('Đồng ý và mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(kenh.soLanMoCaiDat, 0);
    });

    testWidgets('⭐ đã đồng ý trước → bật lại không hỏi; mốc đặt lại = lúc bật', (tester) async {
      await store.write(id, const NotificationPrefs(dongYNhacSauNganHang: true));
      moc.values[id] = DateTime(2026, 9, 1);
      await moTrang(tester);
      await gat(tester);
      expect(find.byType(DongYNhacSauNganHangPage), findsNothing);
      expect(giaTri(tester), isTrue);
      expect(moc.values[id]!.isAfter(DateTime(2026, 9, 1)), isTrue,
          reason: 'tắt rồi bật lại: phiên lúc đang tắt không được nhắc');
      expect(kenh.datBatGoi.single.$1, isTrue);
    });

    testWidgets('⭐ tắt → datBat(false), giữ lần đồng ý; còn quyền → nhắc chỗ thu hồi', (tester) async {
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(nhacSauNganHang: true, dongYNhacSauNganHang: true));
      await moTrang(tester);
      await gat(tester);
      expect(giaTri(tester), isFalse);
      expect(kenh.datBatGoi.single.$1, isFalse);
      final p = await store.read(id);
      expect((p.nhacSauNganHang, p.dongYNhacSauNganHang), (false, true));
      expect(find.text(kNhacThuHoiQuyenSuDung), findsOneWidget);
    });

    testWidgets('bật + chưa quyền → nút Mở Cài đặt của KHỐI NÀY gọi kênh nhắc', (tester) async {
      await store.write(id, const NotificationPrefs(nhacSauNganHang: true, dongYNhacSauNganHang: true));
      await moTrang(tester);
      final nut = find.byKey(NotificationSettingsPage.khoaMoCaiDatSuDung);
      await tester.ensureVisible(nut);
      await tester.tap(nut);
      await tester.pumpAndSettle();
      expect((kenh.soLanMoCaiDat, kenhBienDong.soLanMoCaiDat), (1, 0));
    });

    testWidgets('⭐ bật + có quyền → "đang theo dõi N app"; quay về app (resumed) → đọc lại quyền', (tester) async {
      await store.write(id, const NotificationPrefs(nhacSauNganHang: true, dongYNhacSauNganHang: true));
      await moTrang(tester);
      expect(find.text('Chưa cấp quyền truy cập dữ liệu sử dụng'), findsOneWidget);
      kenh.quyen = true;
      // Trọn chuỗi như `dong_y_bien_dong_test` — framework kiểm chuyển trạng thái hợp lệ.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(find.text('Đã cấp quyền — đang theo dõi ${nguonDangDoc.length} app'), findsOneWidget);
    });

    testWidgets('hàng pin: D1 tắt + khối này bật, có quyền, chưa cho chạy nền → hiện; D1 đã hiện hàng pin → không lặp',
        (tester) async {
      kenh.quyen = true;
      kenhBienDong.chayNen = false;
      await store.write(id, const NotificationPrefs(nhacSauNganHang: true, dongYNhacSauNganHang: true));
      await moTrang(tester);
      expect(find.text(kTieuDeTreNenNhac), findsOneWidget);

      kenhBienDong.quyen = true;
      await store.write(
          id,
          const NotificationPrefs(
              nhacSauNganHang: true, dongYNhacSauNganHang: true, docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.byKey(NotificationSettingsPage.khoaMoCaiDatPin), findsOneWidget,
          reason: 'hai hàng pin = hai nút cùng khoá — Flutter ném lỗi trùng khoá');
      expect(find.text(kTieuDeTreNenNhac), findsNothing);
    });

    testWidgets('360 × 640: hai tính năng cùng bật, cùng thiếu quyền → không tràn', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await store.write(
          id,
          const NotificationPrefs(
              nhacSauNganHang: true, dongYNhacSauNganHang: true, docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      await tester.ensureVisible(find.byKey(khoa));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
