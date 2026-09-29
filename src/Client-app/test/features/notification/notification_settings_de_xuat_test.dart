/// Trang Cài đặt thông báo — dòng gợi ý của B5b (màn Stitch `065eccd8…`).
///
/// Đề xuất nạp MỘT lần lúc mở trang (`taiDeXuat`). Mỗi dòng nằm ngay dưới hàng
/// nó nói tới; *Đổi sang …* / *Tắt nhóm* đi qua đường lưu duy nhất của trang
/// (`_ghi` — kéo theo đặt lại lịch, G59); *Bỏ qua* / *Giữ* gọi `boQuaDeXuat`
/// (im 30 ngày). Không đề xuất thì trang y hệt trước B5b.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/hoc_gio_thong_bao.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_settings_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _Os implements OsNotifier {
  @override
  Future<bool> daCoQuyen() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const id = 7;
  late InMemoryNotificationPrefsStore store;
  late List<DeXuatThongBao> boQua;
  late List<int> datLai;
  late List<int> taiGoi;

  setUp(() {
    store = InMemoryNotificationPrefsStore();
    boQua = [];
    datLai = [];
    taiGoi = [];
  });

  Future<void> mo(WidgetTester tester, List<DeXuatThongBao> deXuat,
      {NotificationPrefs prefs = NotificationPrefs.macDinh,
      Size kho = const Size(411, 2600),
      ThemeData? theme}) async {
    tester.view.physicalSize = kho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await store.write(id, prefs);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: NotificationSettingsPage(
        idaccount: id,
        store: store,
        osNotifier: _Os(),
        datLaiLich: (i) async => datLai.add(i),
        taiDeXuat: (i) async {
          taiGoi.add(i);
          return deXuat;
        },
        boQuaDeXuat: (i, d) async => boQua.add(d),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double y(WidgetTester t, String chu) => t.getRect(find.text(chu).first).top;

  Future<void> cham(WidgetTester tester, String chu) async {
    await tester.ensureVisible(find.text(chu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(chu));
    await tester.pumpAndSettle();
  }

  const hd = DeXuatThongBao(loai: LoaiDeXuat.gioHoaDon, gio: (gio: 20, phut: 0), soMau: 25);

  testWidgets('không đề xuất → trang y hệt, nạp đúng tài khoản', (tester) async {
    await mo(tester, const []);
    expect(taiGoi, [id]);
    expect(find.textContaining('Bạn hay'), findsNothing);
    expect(find.textContaining('chưa được mở'), findsNothing);
  });

  testWidgets('⭐ giờ nhắc hoá đơn: dòng nằm DƯỚI ô giờ; Đổi sang → lưu + đặt lại lịch, dòng mất',
      (tester) async {
    await mo(tester, const [hd]);
    const cau = 'Bạn hay mở nhắc hoá đơn lúc khoảng 20:00.';
    expect(find.text(cau), findsOneWidget);
    expect(y(tester, cau), greaterThan(y(tester, 'Giờ nhắc trong ngày')));
    expect(y(tester, cau), lessThan(y(tester, 'Nhắc trước')));

    await cham(tester, 'Đổi sang 20:00');

    final p = await store.read(id);
    expect((p.gioNhac, p.phutNhac), (20, 0));
    expect(datLai, [id],
        reason: 'áp dụng đi qua _ghi — lịch đang chờ dời sang giờ mới (G59)');
    expect(find.text(cau), findsNothing);
    expect(boQua, isEmpty, reason: 'áp dụng không cần ghi bo_qua — luật tự thôi đề xuất');
  });

  testWidgets('Bỏ qua → gọi boQuaDeXuat đúng đề xuất, tuỳ chọn không đổi', (tester) async {
    await mo(tester, const [hd]);
    await cham(tester, 'Bỏ qua');
    expect(boQua.map((d) => d.khoa), ['deXuat:gioHoaDon']);
    expect(find.textContaining('Bạn hay mở nhắc hoá đơn'), findsNothing);
    expect((await store.read(id)).gioNhac, 8);
    expect(datLai, isEmpty);
  });

  testWidgets('nhóm bị lờ: dòng dưới công tắc Ngân sách; Tắt nhóm → lưu nhomTat', (tester) async {
    await mo(tester, const [
      DeXuatThongBao(loai: LoaiDeXuat.tatNhom, nhom: NotificationGroup.budget, soMau: 20),
    ]);
    const cau = '10 thông báo gần nhất của nhóm này chưa được mở.';
    expect(y(tester, cau), greaterThan(y(tester, 'Ngân sách')));
    expect(y(tester, cau), lessThan(y(tester, 'Mục tiêu')));

    await cham(tester, 'Tắt nhóm');
    expect((await store.read(id)).nhomTat, contains(NotificationGroup.budget));
    expect(find.text(cau), findsNothing);
  });

  testWidgets('nhóm bị lờ: Giữ → bỏ qua đề xuất', (tester) async {
    await mo(tester, const [
      DeXuatThongBao(loai: LoaiDeXuat.tatNhom, nhom: NotificationGroup.budget, soMau: 20),
    ]);
    await cham(tester, 'Giữ');
    expect(boQua.map((d) => d.khoa), ['deXuat:tatNhom:budget']);
    expect((await store.read(id)).nhomTat, isEmpty);
  });

  testWidgets('tổng kết tuần: một dòng gộp thứ + giờ, áp dụng lưu cả hai', (tester) async {
    await mo(
        tester,
        const [
          DeXuatThongBao(
              loai: LoaiDeXuat.gioTongKet, gio: (gio: 9, phut: 0), thu: DateTime.saturday, soMau: 25),
        ],
        prefs: const NotificationPrefs(tongKetTuanBat: true));
    expect(find.text('Bạn hay mở tổng kết tuần vào khoảng thứ Bảy 09:00.'), findsOneWidget);
    await cham(tester, 'Đổi sang thứ Bảy 09:00');
    final p = await store.read(id);
    expect((p.thuTongKet, p.gioTongKet, p.phutTongKet), (DateTime.saturday, 9, 0));
    expect(datLai, [id], reason: 'một lần ghi, một lần đặt lại');
  });

  testWidgets('tổng kết tuần chỉ lệch thứ / chỉ lệch giờ → câu nói đúng phần lệch', (tester) async {
    await mo(
        tester,
        const [
          DeXuatThongBao(loai: LoaiDeXuat.gioTongKet, thu: DateTime.saturday, soMau: 25),
        ],
        prefs: const NotificationPrefs(tongKetTuanBat: true));
    expect(find.text('Bạn hay mở tổng kết tuần vào thứ Bảy.'), findsOneWidget);
    expect(find.text('Đổi sang thứ Bảy'), findsOneWidget);
  });

  testWidgets('giờ nhắc ghi chép: câu về lúc ghi giao dịch, dưới ô giờ ghi chép', (tester) async {
    await mo(
        tester,
        const [DeXuatThongBao(loai: LoaiDeXuat.gioGhiChep, gio: (gio: 21, phut: 0), soMau: 25)],
        prefs: const NotificationPrefs(nhacGhiChepBat: true));
    const cau = 'Bạn hay ghi giao dịch lúc khoảng 21:00.';
    expect(find.text(cau), findsOneWidget);
    await cham(tester, 'Đổi sang 21:00');
    final p = await store.read(id);
    expect((p.gioNhacGhiChep, p.phutNhacGhiChep), (21, 0));
  });

  testWidgets('nạp đề xuất hỏng → trang vẫn dựng, không dòng gợi ý', (tester) async {
    tester.view.physicalSize = const Size(411, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: NotificationSettingsPage(
        idaccount: id,
        store: store,
        osNotifier: _Os(),
        taiDeXuat: (_) async => throw StateError('hỏng'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt thông báo'), findsOneWidget);
    expect(find.textContaining('Bạn hay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp, theme thật (bẫy 4.11): nút dài nhất không tràn', (tester) async {
    await mo(
        tester,
        const [
          hd,
          DeXuatThongBao(
              loai: LoaiDeXuat.gioTongKet, gio: (gio: 21, phut: 30), thu: DateTime.sunday, soMau: 25),
          DeXuatThongBao(loai: LoaiDeXuat.tatNhom, nhom: NotificationGroup.system, soMau: 20),
        ],
        prefs: const NotificationPrefs(tongKetTuanBat: true),
        kho: const Size(360, 2600),
        theme: AppTheme.lightTheme);
    expect(find.text('Đổi sang chủ nhật 21:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
