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
import 'package:flutter/foundation.dart';
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

  Future<void> dung(WidgetTester tester, {double banPhim = 0, ValueListenable<double>? cheDay}) async {
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
          cheDay: cheDay ?? ValueNotifier<double>(0),
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
    testWidgets('lỗi: vòng đỏ (expense), dấu "!" như Stitch fb68baba…', (tester) async {
      await dung(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(mauVong(tester), AppColors.expense);
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
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

  group('chi tiết theo Stitch fb68baba… (người dùng chọn 2026-10-06)', () {
    testWidgets('⭐ mặc định tự ẩn sau 3 GIÂY (trước: 4)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AppToast(
          connectionEvents: ketNoi.stream,
          pushResults: dayLen.stream,
          realtimeEvents: const Stream<RealtimeEvent>.empty(),
          thongBaoNhanh: nhanh.stream,
          cheDay: ValueNotifier<double>(0),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ));
      nhanh.hien('Đã xoá giao dịch', loai: LoaiThongBao.xong);
      await nhip(tester);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Đã xoá giao dịch'), findsOneWidget, reason: 'chưa tới 3 giây');
      await tester.pump(const Duration(milliseconds: 600) + thoiGianHieuUngToast);
      expect(find.text('Đã xoá giao dịch'), findsNothing);
    });

    testWidgets('câu mang biểu tượng riêng thì thay biểu tượng của loại (thùng rác cho "Đã xoá thông báo")',
        (tester) async {
      await dung(tester);
      nhanh.hien('Đã xoá thông báo', bieuTuong: Icons.delete_outline, hanhDong: HanhDongToast('Hoàn tác', () {}));
      await nhip(tester);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('⭐ vuốt ngang viên → ẩn ngay, không chạy hành động', (tester) async {
      await dung(tester);
      var lan = 0;
      nhanh.hien('Đã xoá thông báo', hanhDong: HanhDongToast('Hoàn tác', () => lan++));
      await nhip(tester);
      await tester.drag(find.byKey(const Key('toast-vien')), const Offset(-200, 0));
      await tester.pump();
      await tester.pump(thoiGianHieuUngToast + const Duration(milliseconds: 20));
      expect(find.text('Đã xoá thông báo'), findsNothing);
      expect(lan, 0, reason: 'vuốt tắt là bỏ qua, không phải Hoàn tác');
    });

    testWidgets('vuốt ngắn thì viên trượt về chỗ cũ, vẫn hiện', (tester) async {
      await dung(tester);
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      final truoc = tester.getRect(find.byKey(const Key('toast-vien')));
      await tester.drag(find.byKey(const Key('toast-vien')), const Offset(-20, 0));
      await tester.pump();
      await tester.pump(thoiGianHieuUngToast);
      expect(find.text('Vui lòng chọn danh mục'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('toast-vien'))).left, closeTo(truoc.left, 0.5));
    });

    testWidgets('chạm NGOÀI viên vẫn rơi xuống trang bên dưới', (tester) async {
      var cham = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AppToast(
          connectionEvents: ketNoi.stream,
          pushResults: dayLen.stream,
          realtimeEvents: const Stream<RealtimeEvent>.empty(),
          thongBaoNhanh: nhanh.stream,
          tuAnSau: tuAn,
          cheDay: ValueNotifier<double>(0),
          child: child!,
        ),
        home: Scaffold(
            body: GestureDetector(
                behavior: HitTestBehavior.opaque, onTap: () => cham++, child: const SizedBox.expand())),
      ));
      nhanh.hien('Vui lòng', loai: LoaiThongBao.loi);
      await nhip(tester);
      final vien = tester.getRect(find.byKey(const Key('toast-vien')));
      await tester.tapAt(Offset(vien.left - 4, vien.center.dy));
      expect(cham, 1, reason: 'viên chỉ nhận chạm trong đúng hình viên');
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

    testWidgets('⭐ vùng đáy bị che (16 phím số tự vẽ ở Thêm giao dịch): viên nổi 12 dp TRÊN vùng ấy', (tester) async {
      final che = ValueNotifier<double>(0);
      await dung(tester, cheDay: che);
      che.value = 280;
      nhanh.hien('Vui lòng chọn danh mục', loai: LoaiThongBao.loi);
      await nhip(tester);
      final day = tester.getRect(find.byKey(const Key('toast-vien'))).bottom;
      expect(day, closeTo(800 - 280 - 12, 0.5),
          reason: 'Stitch fb68baba… — bàn phím số do app tự vẽ, hệ điều hành không báo viewInsets; bản trước đè hai '
              'hàng phím dưới (000 · 0 · ⌫) 4 giây');
      che.value = 0;
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('toast-vien'))).bottom, closeTo(800 - 92, 0.5),
          reason: 'bàn phím số ẩn → về chỗ cũ trên thanh tab');
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
