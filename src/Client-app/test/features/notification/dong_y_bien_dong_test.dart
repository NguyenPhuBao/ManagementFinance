/// D1 Task 6 — màn xin đồng ý đọc biến động số dư (backend BẮT BUỘC, Nghị định 13) + công tắc ở
/// trang Cài đặt thông báo (Stitch `bed4d292…` và `d42ce712…`).
///
/// Ba điều đáng canh, cả ba hỏng im lặng:
/// 1. **Không đồng ý thì dịch vụ Kotlin không bao giờ được bật** (`datBat(true)`): cờ ấy là thứ cho
///    `BienDongListenerService` đọc thông báo ngân hàng.
/// 2. **Màn liệt kê đúng những nguồn app THẬT SỰ đọc** — suy từ danh sách trắng `kNguonTheoGoi`,
///    không chép tay (người dùng chốt 2026-09-30: không hứa nguồn chưa đo).
/// 3. **Dòng trạng thái quyền nói sự thật của máy**, đọc lại khi người dùng quay về từ Cài đặt hệ
///    thống — công tắc sáng mà quyền chưa cấp là tính năng chết không lời giải thích.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/kenh_bien_dong.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/presentation/pages/dong_y_bien_dong_page.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_settings_page.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';

class _KenhGia implements KenhBienDong {
  bool quyen = false;
  bool chayNen = false;
  final List<bool> datBatGoi = [];
  int soLanMoCaiDat = 0;
  int soLanMoCaiDatPin = 0;
  int soLanHoiQuyen = 0;

  @override
  Future<bool> coQuyen() async {
    soLanHoiQuyen++;
    return quyen;
  }

  @override
  Future<void> moCaiDat() async => soLanMoCaiDat++;
  @override
  Future<void> moCaiDatPin() async => soLanMoCaiDatPin++;
  @override
  Future<bool> duocChayNen() async => chayNen;
  @override
  Future<bool> moTuThongBao() async => false;
  @override
  Future<void> huyTomTat() async {}
  @override
  Future<void> datBat(bool bat) async => datBatGoi.add(bat);
  @override
  Future<void> datCoPhien(bool co) async {}
}

/// Trang hỏi quyền thông báo của hệ điều hành lúc mở (công tắc tổng mặc định bật) — ngoài phạm vi
/// tệp này, chỉ cần trả lời "có".
class _OsGia extends Fake implements OsNotifier {
  @override
  Future<bool> daCoQuyen() async => true;
}

void main() {
  group('nguonDangDoc', () {
    test('⭐ là các nguồn của danh sách trắng, không trùng, không thêm nguồn chưa đo', () {
      expect(nguonDangDoc, kNguonTheoGoi.values.toSet().toList());
      expect(nguonDangDoc.toSet().length, nguonDangDoc.length);
      for (final n in nguonDangDoc) {
        expect(kNguonBienDong, contains(n), reason: 'mỗi nguồn đang đọc phải là một trong bảy nguồn đã báo backend');
      }
    });
  });

  group('màn xin đồng ý', () {
    Future<Object?> moMan(WidgetTester tester) async {
      Object? ketQua = 'chưa pop';
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async =>
                ketQua = await Navigator.of(ctx).push<bool>(
                    MaterialPageRoute(builder: (_) => const DongYBienDongPage())),
            child: const Text('mở'),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      return ketQua;
    }

    testWidgets('⭐ liệt kê ĐÚNG các nguồn đang đọc, kèm số đếm; không nguồn chưa đo', (tester) async {
      await moMan(tester);
      for (final n in nguonDangDoc) {
        expect(find.text(n), findsOneWidget, reason: 'backend bắt buộc màn nêu danh sách trắng');
      }
      expect(find.text('CHỈ ĐỌC THÔNG BÁO CỦA ${nguonDangDoc.length} NGUỒN'), findsOneWidget);
      for (final n in kNguonBienDong.where((n) => !nguonDangDoc.contains(n))) {
        expect(find.text(n), findsNothing,
            reason: 'hứa đọc $n khi dịch vụ chưa đọc gói nào của nó là lời hứa sai (người dùng chốt 2026-09-30)');
      }
    });

    testWidgets('có đủ bốn cam kết và hai nút', (tester) async {
      await moMan(tester);
      for (final c in kCamKetBienDong) {
        expect(find.text(c), findsOneWidget);
      }
      expect(kCamKetBienDong, hasLength(4));
      expect(find.text('Đồng ý và mở Cài đặt'), findsOneWidget);
      expect(find.text('Không, cảm ơn'), findsOneWidget);
    });

    testWidgets('Đồng ý → pop true; Không, cảm ơn → pop false', (tester) async {
      Object? kq;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => kq = await Navigator.of(ctx).push<bool>(
                MaterialPageRoute(builder: (_) => const DongYBienDongPage())),
            child: const Text('mở'),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
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
      await moMan(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('công tắc ở Cài đặt thông báo', () {
    const id = 7;
    late InMemoryNotificationPrefsStore store;
    late _KenhGia kenh;

    setUp(() {
      store = InMemoryNotificationPrefsStore();
      kenh = _KenhGia();
    });

    final khoa = NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.bienDong);

    Future<void> moTrang(WidgetTester tester, {Map<String, bool>? quyen}) async {
      final trang = MaterialApp(
        home: NotificationSettingsPage(
            idaccount: id, store: store, osNotifier: _OsGia(), kenhBienDong: kenh),
      );
      if (quyen == null) {
        await tester.pumpWidget(trang);
      } else {
        final repo = GoiRepository(api: _ApiGoiIm(), kho: InMemoryGoiStore());
        final goi = GoiCubit(repo);
        goi.emit(TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: DateTime.now(), quyenTinhNang: quyen));
        addTearDown(() async {
          await goi.close();
          await repo.dispose();
        });
        await tester.pumpWidget(BlocProvider<GoiCubit>.value(value: goi, child: trang));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('quyền bank_notification_parser tắt → công tắc khoá + "Cần Premium" (spec phân quyền 2026-10-08)',
        (tester) async {
      await moTrang(tester, quyen: const {'bank_notification_parser': false});
      await tester.ensureVisible(find.byKey(khoa));
      expect(tester.widget<Switch>(find.byKey(khoa)).onChanged, isNull);
      expect(find.text('Cần Premium'), findsOneWidget);
    });

    Future<void> gat(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(khoa));
      await tester.tap(find.byKey(khoa));
      await tester.pumpAndSettle();
    }

    bool giaTri(WidgetTester tester) => tester.widget<Switch>(find.byKey(khoa)).value;

    testWidgets('⭐ bật lần đầu → màn đồng ý; "Không, cảm ơn" → vẫn tắt, KHÔNG bật dịch vụ', (tester) async {
      await moTrang(tester);
      await gat(tester);
      expect(find.byType(DongYBienDongPage), findsOneWidget);

      await tester.ensureVisible(find.text('Không, cảm ơn'));
      await tester.tap(find.text('Không, cảm ơn'));
      await tester.pumpAndSettle();

      expect(find.byType(DongYBienDongPage), findsNothing);
      expect(giaTri(tester), isFalse);
      final p = await store.read(id);
      expect((p.docBienDong, p.dongYBienDong), (false, false));
      expect(kenh.datBatGoi, isEmpty, reason: 'không đồng ý thì dịch vụ đọc thông báo ngân hàng không được bật');
      expect(kenh.soLanMoCaiDat, 0);
    });

    testWidgets('bật lần đầu rồi bấm Back → coi như không đồng ý', (tester) async {
      await moTrang(tester);
      await gat(tester);
      // `.last`: trang Cài đặt bên dưới cũng có nút "Quay lại".
      await tester.tap(find.byTooltip('Quay lại').last);
      await tester.pumpAndSettle();
      expect(find.byType(DongYBienDongPage), findsNothing);
      expect(giaTri(tester), isFalse);
      expect(kenh.datBatGoi, isEmpty);
    });

    testWidgets('⭐ Đồng ý → lưu hai cờ, bật dịch vụ, mở Cài đặt hệ thống (chưa có quyền)', (tester) async {
      await moTrang(tester);
      await gat(tester);
      await tester.ensureVisible(find.text('Đồng ý và mở Cài đặt'));
      await tester.tap(find.text('Đồng ý và mở Cài đặt'));
      await tester.pumpAndSettle();

      expect(giaTri(tester), isTrue);
      final p = await store.read(id);
      expect((p.docBienDong, p.dongYBienDong), (true, true));
      expect(kenh.datBatGoi, [true]);
      expect(kenh.soLanMoCaiDat, 1, reason: 'app không tự cấp được quyền Truy cập thông báo');
      expect(find.text('Chưa cấp quyền truy cập thông báo'), findsOneWidget);
    });

    testWidgets('Đồng ý khi máy ĐÃ có quyền → không mở Cài đặt thừa', (tester) async {
      kenh.quyen = true;
      await moTrang(tester);
      await gat(tester);
      await tester.ensureVisible(find.text('Đồng ý và mở Cài đặt'));
      await tester.tap(find.text('Đồng ý và mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(kenh.datBatGoi, [true]);
      expect(kenh.soLanMoCaiDat, 0);
    });

    testWidgets('⭐ đã đồng ý trước đó → bật lại KHÔNG hỏi lần nữa', (tester) async {
      await store.write(id, const NotificationPrefs(dongYBienDong: true));
      await moTrang(tester);
      await gat(tester);
      expect(find.byType(DongYBienDongPage), findsNothing);
      expect(giaTri(tester), isTrue);
      expect(kenh.datBatGoi, [true]);
    });

    testWidgets('⭐ tắt → datBat(false), giữ lần đồng ý, nhắc cách thu hồi hẳn quyền', (tester) async {
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      await gat(tester);
      expect(giaTri(tester), isFalse);
      expect(kenh.datBatGoi, [false]);
      final p = await store.read(id);
      expect((p.docBienDong, p.dongYBienDong), (false, true));
      expect(find.text(kNhacThuHoiQuyen), findsOneWidget,
          reason: 'tắt trong app chỉ dừng đọc; quyền hệ thống vẫn còn — người dùng phải biết chỗ thu hồi');
    });

    testWidgets('bật + chưa có quyền → dòng cảnh báo + nút Mở Cài đặt gọi kênh', (tester) async {
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text('Chưa cấp quyền truy cập thông báo'), findsOneWidget);
      await tester.ensureVisible(find.text('Mở Cài đặt'));
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(kenh.soLanMoCaiDat, 1);
    });

    testWidgets('⭐ bật + có quyền → "đang đọc N nguồn" đúng số của danh sách trắng', (tester) async {
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text('Đã cấp quyền — đang đọc ${nguonDangDoc.length} nguồn'), findsOneWidget);
      expect(find.text(nguonDangDoc.join(', ')), findsOneWidget);
      expect(find.text('Chưa cấp quyền truy cập thông báo'), findsNothing);
    });

    // Đo Realme RMX2205 2026-09-30: ColorOS (Hans) đóng băng FlowMoney ~40 giây sau khi về nền — tin ngân hàng
    // tới trễ cho tới khi bật màn hình / mở app (trễ ~84 giây ở lượt đo), dù app đã được miễn tối ưu pin chuẩn.
    // Người dùng chọn thêm dòng hướng dẫn (Stitch `2ff589c7…`).
    testWidgets('⭐ bật + có quyền → hàng "Tin có thể đến trễ…"; Mở cài đặt gọi moCaiDatPin, KHÔNG moCaiDat',
        (tester) async {
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text(kTieuDeTreNen), findsOneWidget);
      final nut = find.byKey(NotificationSettingsPage.khoaMoCaiDatPin);
      await tester.ensureVisible(nut);
      await tester.tap(nut);
      await tester.pumpAndSettle();
      expect(kenh.soLanMoCaiDatPin, 1);
      expect(kenh.soLanMoCaiDat, 0, reason: 'nút pin không được mở trang Truy cập thông báo');
    });

    testWidgets('chưa có quyền / công tắc tắt → không có hàng pin (chưa đọc gì thì chưa có gì để trễ)',
        (tester) async {
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text(kTieuDeTreNen), findsNothing, reason: 'chưa có quyền');

      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: false, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text(kTieuDeTreNen), findsNothing, reason: 'công tắc tắt');
    });

    // Đo đối chứng Realme 2026-09-30: "Cho phép hoạt động dưới nền" TẮT → Hans đóng băng app sau ~12 giây; BẬT → không
    // đóng băng (2 × 110 giây). Công tắc ấy CHÍNH là miễn tối ưu pin chuẩn — đọc được, nên đã bật thì im.
    testWidgets('⭐ máy ĐÃ cho phép chạy nền → không hiện hàng pin (nói "có thể trễ" khi không trễ là nói sai)',
        (tester) async {
      kenh.quyen = true;
      kenh.chayNen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.textContaining('Đã cấp quyền'), findsOneWidget);
      expect(find.text(kTieuDeTreNen), findsNothing);
    });

    testWidgets('⭐ bật "hoạt động dưới nền" ở Cài đặt rồi quay về (resumed) → hàng pin tự biến mất', (tester) async {
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text(kTieuDeTreNen), findsOneWidget);

      kenh.chayNen = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(kTieuDeTreNen), findsNothing);
    });

    testWidgets('⭐ quay về app (resumed) → đọc lại quyền, dòng trạng thái đổi theo', (tester) async {
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(find.text('Chưa cấp quyền truy cập thông báo'), findsOneWidget);

      kenh.quyen = true; // người dùng vừa bật trong Cài đặt hệ thống
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Chưa cấp quyền truy cập thông báo'), findsNothing,
          reason: 'không đọc lại thì dòng cảnh báo còn đó dù người dùng vừa cấp quyền — họ sẽ cấp đi cấp lại');
      expect(find.textContaining('Đã cấp quyền'), findsOneWidget);
    });

    testWidgets('khối nằm dưới nhãn "TỰ ĐỘNG HOÁ GIAO DỊCH" kèm nhãn Mới, không trong LOẠI THÔNG BÁO',
        (tester) async {
      await moTrang(tester);
      expect(find.text('TỰ ĐỘNG HOÁ GIAO DỊCH'), findsOneWidget);
      expect(find.text('Mới'), findsOneWidget);
      final yLoai = tester.getTopLeft(find.text('LOẠI THÔNG BÁO')).dy;
      final yTuDong = tester.getTopLeft(find.text('TỰ ĐỘNG HOÁ GIAO DỊCH')).dy;
      final yCongTac = tester.getTopLeft(find.byKey(khoa)).dy;
      expect(yTuDong, greaterThan(yLoai));
      expect(yCongTac, greaterThan(yTuDong));
    });

    testWidgets('không tràn ở 360 dp với dòng trạng thái dài', (tester) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      kenh.quyen = true;
      await store.write(id, const NotificationPrefs(docBienDong: true, dongYBienDong: true));
      await moTrang(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ApiGoiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
}
