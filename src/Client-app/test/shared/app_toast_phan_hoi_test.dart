/// E4 (2026-10-06, người dùng duyệt): `SnackBar` của các trang chuyển sang viên toast của `AppToast` qua
/// `ThongBaoNhanh`. Kênh mang thêm LOẠI (lỗi · xong · thông tin) và một HÀNH ĐỘNG tuỳ chọn ("Hoàn tác" ở trung
/// tâm thông báo — chỗ duy nhất từng có `SnackBarAction`). Câu phản hồi cho cú bấm của người dùng có bậc CAO NHẤT
/// (người dùng chọn: "câu phản hồi thắng"), và viên phải nổi TRÊN bàn phím — đa số câu lỗi ("Vui lòng nhập…")
/// hiện đúng lúc form đang mở bàn phím.
library;

import 'dart:async';

import 'package:flowmoney/core/network/connection_monitor.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flowmoney/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Đủ dài để hiệu ứng trượt vào (220 ms) chạy xong trước khi đo / bấm.
  const tuAn = Duration(seconds: 2);
  late ThongBaoNhanh nhanh;
  late StreamController<ConnectionEvent> ketNoi;
  late StreamController<SyncResult> dayLen;

  setUp(() {
    nhanh = ThongBaoNhanh();
    ketNoi = StreamController<ConnectionEvent>.broadcast();
    dayLen = StreamController<SyncResult>.broadcast();
  });
  tearDown(() async {
    await nhanh.dispose();
    await ketNoi.close();
    await dayLen.close();
  });

  Future<void> dung(WidgetTester tester, {double banPhim = 0}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Không bọc Scaffold: app thật đặt AppToast ở `MaterialApp.builder`, NGOÀI mọi Scaffold — Scaffold tự co
    // thân theo bàn phím nên bọc vào là trừ khoảng bàn phím hai lần.
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.only(bottom: banPhim)),
        child: AppToast(
          connectionEvents: ketNoi.stream,
          pushResults: dayLen.stream,
          realtimeEvents: const Stream<RealtimeEvent>.empty(),
          thongBaoNhanh: nhanh.stream,
          tuAnSau: tuAn,
          child: child!,
        ),
      ),
      home: const Scaffold(body: SizedBox.expand()),
    ));
    await tester.pump();
  }

  /// Ba nhịp: dựng viên · ticker của `AnimatedSlide` bắt đầu ở khung SAU khung dựng · chạy hết hiệu ứng. Hai nhịp
  /// thì viên còn ở vị trí đầu (lệch nửa chiều cao — đo được 25 dp).
  Future<void> nhip(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(thoiGianHieuUngToast);
  }

  Color mauVong(WidgetTester tester) {
    final c = tester.widget<Container>(find.byKey(const Key('toast-vong')));
    return (c.decoration! as BoxDecoration).color!;
  }

  SyncResult hong() => const SyncResult(totalOps: 1, succeeded: 0, failed: 1);

  group('loại', () {
    testWidgets('lỗi: vòng đỏ (expense), biểu tượng lỗi', (tester) async {
      await dung(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(mauVong(tester), AppColors.expense);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('xong: vòng xanh (income), dấu ✓', (tester) async {
      await dung(tester);
      nhanh.hien('Đã xoá giao dịch', loai: LoaiThongBao.xong);
      await nhip(tester);
      expect(mauVong(tester), AppColors.income);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('mặc định là thông tin: vòng đen (primary) như trước E4', (tester) async {
      await dung(tester);
      nhanh.hien('Nhấn lần nữa để thoát');
      await nhip(tester);
      expect(mauVong(tester), AppColors.primary);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('hành động (Hoàn tác)', () {
    testWidgets('⭐ nút bấm được: chạy việc rồi ẩn viên', (tester) async {
      await dung(tester);
      var lan = 0;
      nhanh.hien('Đã xoá thông báo', hanhDong: HanhDongToast('Hoàn tác', () => lan++));
      await nhip(tester);
      expect(find.text('Hoàn tác'), findsOneWidget);
      await tester.tap(find.text('Hoàn tác'));
      await nhip(tester);
      expect(lan, 1);
      await tester.pump(thoiGianHieuUngToast + const Duration(milliseconds: 20));
      expect(find.text('Đã xoá thông báo'), findsNothing, reason: 'bấm rồi thì viên ẩn, không chờ hết giờ');
    });

    testWidgets('viên có hành động vẫn tự ẩn (SnackBar có action thì không — bẫy Flutter 3.47)', (tester) async {
      await dung(tester);
      nhanh.hien('Đã xoá thông báo', hanhDong: HanhDongToast('Hoàn tác', () {}));
      await nhip(tester);
      await tester.pump(tuAn + thoiGianHieuUngToast + const Duration(milliseconds: 20));
      expect(find.text('Hoàn tác'), findsNothing);
    });

    testWidgets('viên KHÔNG có hành động không chặn chạm vào trang bên dưới', (tester) async {
      await dung(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      final chan = tester.widgetList<IgnorePointer>(
          find.ancestor(of: find.text('Vui lòng chọn danh mục'), matching: find.byType(IgnorePointer)));
      expect(chan.any((w) => w.ignoring), isTrue);
    });
  });

  group('ưu tiên — câu phản hồi thắng (người dùng chọn 2026-10-06)', () {
    testWidgets('⭐ phản hồi đè toast mất mạng đang hiện', (tester) async {
      await dung(tester);
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(find.textContaining('Không có kết nối'), findsNothing);
    });

    testWidgets('⭐ toast nền tới SAU không đè phản hồi đang hiện', (tester) async {
      await dung(tester);
      nhanh.hien('Đã xoá giao dịch', loai: LoaiThongBao.xong);
      await nhip(tester);
      dayLen.add(hong());
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);
      expect(find.text('Đã xoá giao dịch'), findsOneWidget);
      expect(find.textContaining('chưa lên được'), findsNothing);
    });

    testWidgets('phản hồi mới thay phản hồi cũ (cùng nguồn)', (tester) async {
      await dung(tester);
      nhanh.hien('Vui lòng nhập số tiền hợp lệ', loai: LoaiThongBao.loi);
      await nhip(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(find.text('Vui lòng nhập số tiền hợp lệ'), findsNothing);
    });
  });

  group('bố cục', () {
    testWidgets('⭐ bàn phím mở: viên nổi TRÊN bàn phím', (tester) async {
      const banPhim = 300.0;
      await dung(tester, banPhim: banPhim);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      final day = tester.getRect(find.byKey(const Key('toast-vien'))).bottom;
      expect(day, lessThanOrEqualTo(800 - banPhim - 12 + 0.5),
          reason: 'đa số câu lỗi hiện khi form đang mở bàn phím — viên nằm cố định trên thanh tab thì bị che');
    });

    testWidgets('bàn phím đóng: giữ chỗ cũ trên thanh tab', (tester) async {
      await dung(tester);
      nhanh.hien('Đã xoá giao dịch', loai: LoaiThongBao.xong);
      await nhip(tester);
      final day = tester.getRect(find.byKey(const Key('toast-vien'))).bottom;
      expect(day, closeTo(800 - 92, 0.5));
    });

    testWidgets('câu dài được tới 3 dòng; nút Hoàn tác không tràn ở 360 dp', (tester) async {
      await dung(tester);
      nhanh.hien('Chưa xác định được tài khoản đăng nhập. Vui lòng đăng nhập lại rồi thử lại thao tác này nhé.',
          loai: LoaiThongBao.loi, hanhDong: HanhDongToast('Hoàn tác', () {}));
      await nhip(tester);
      expect(tester.takeException(), isNull);
      final t = tester.widget<Text>(find.textContaining('Chưa xác định'));
      expect(t.maxLines, 3);
    });
  });
}
