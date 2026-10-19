/// Màn Đang chờ thanh toán `/premium/cho-thanh-toan` (spec Premium 9.3; spec G94 2026-10-18 mục 5.4; Stitch `95b2774f…`):
/// KHÔNG tự mở trang PayOS — đủ thông tin để trả trong app: ảnh QR + *Lưu mã QR*, số tài khoản / chủ tài khoản / số
/// tiền / nội dung (chép được), ba bước; nút phụ mở trang PayOS (mở hỏng → link chép được); hỏi trạng thái mỗi 3 s khi
/// đang hiện, hỏi ngay khi quay lại app / bấm *Tôi đã chuyển khoản* / socket `account.upgraded` · `payment.*`;
/// PAID → làm mới gói + Thành công + Xong pop hai lớp; trạng thái đối soát → THAY bằng Chi tiết đơn;
/// EXPIRED → Tạo đơn mới — đồng hồ trên máy về 0 KHÔNG tự báo hết hạn, server quyết (G94 việc 1); rời màn dừng hỏi.
library;

import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/luu_anh_qr.dart';
import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository_impl.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/cho_thanh_toan_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';

class _ApiGia implements PaymentApi {
  /// Kịch bản trả lời theo thứ tự; hết kịch bản thì lặp phần tử cuối; rỗng = `PENDING` mãi.
  final List<String> trangThai = [];

  /// Có thì thắng [trangThai] — trả lời theo đồng hồ giả, như server cho đơn `PENDING` quá `expired_at` thành
  /// `EXPIRED` ngay lúc đọc.
  String Function()? traLoiTheoGio;
  int soLanHoiDon = 0;
  int soLanHoiGoi = 0;

  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) async {
    soLanHoiDon++;
    final s = traLoiTheoGio?.call() ??
        (trangThai.isEmpty ? 'PENDING' : (trangThai.length > 1 ? trangThai.removeAt(0) : trangThai.first));
    return {'order_code': orderCode, 'status': s};
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() async {
    soLanHoiGoi++;
    return const {'accountType': 'Premium', 'premiumExpiresAt': '2026-11-05T01:00:00.000Z'};
  }

  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) =>
      throw UnimplementedError('màn Chờ thôi xác nhận — việc của Chi tiết đơn');
}

class _LuuGia extends LuuAnhQr {
  _LuuGia() : super(taiAnh: (_) async => Uint8List(0));

  KetQuaLuuAnh ketQua = KetQuaLuuAnh.daLuu;
  final goi = <(Uri, String)>[];

  @override
  Future<KetQuaLuuAnh> luu(Uri url, {required String ten}) async {
    goi.add((url, ten));
    return ketQua;
  }
}

/// Ảnh QR giả: [hong] → báo lỗi ngay (như `img.vietqr.io` trả 4xx); không thì đang tải mãi (nút Lưu không chờ ảnh).
class _AnhGia extends ImageProvider<_AnhGia> {
  _AnhGia({this.hong = false});

  final bool hong;

  @override
  Future<_AnhGia> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_AnhGia key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(
      hong ? Future<ImageInfo>.error(StateError('ảnh QR 400')) : Completer<ImageInfo>().future);
}

void main() {
  var now = DateTime(2026, 10, 6, 10);
  final qr = Uri.parse('https://img.vietqr.io/image/970422-0123456789-compact2.png?amount=49000');
  final don = DonThanhToan(
    orderCode: 200370869,
    checkoutUrl: Uri.parse('https://pay.payos.vn/web/abc'),
    soTien: 49000,
    recognitionCode: 'A8K9M2',
    hetHanLuc: DateTime(2026, 10, 6, 10, 30),
    qrUrl: qr,
    noiDung: 'CSCYDEZ2N10 A8K9M2',
    soTaiKhoan: '0123456789',
    chuTaiKhoan: 'NGUYEN VAN A',
  );

  late _ApiGia api;
  late _LuuGia luu;
  late List<Uri> daMo;
  late List<Uri> anhDaDung;
  late bool moDuoc;
  late bool anhHong;
  late StreamController<RealtimeEvent> suKien;
  late GoRouter router;

  setUp(() {
    now = DateTime(2026, 10, 6, 10);
    api = _ApiGia();
    luu = _LuuGia();
    daMo = [];
    anhDaDung = [];
    moDuoc = true;
    anhHong = false;
    suKien = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => suKien.close());

  Future<void> dung(WidgetTester tester, {DonThanhToan? d}) async {
    final repo = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
    await repo.datTaiKhoan(10);
    final cubit = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    router = GoRouter(initialLocation: '/truoc', routes: [
      GoRoute(path: '/truoc', builder: (_, __) => const Scaffold(body: Text('TRƯỚC'))),
      GoRoute(path: '/premium', builder: (_, __) => const Scaffold(body: Text('NÂNG CẤP'))),
      GoRoute(
        path: '/premium/cho-thanh-toan',
        builder: (_, s) => ChoThanhToanPage(
          don: s.extra as DonThanhToan,
          repo: DonThanhToanRepositoryImpl(api: api),
          goi: cubit,
          moLienKet: (u) async {
            daMo.add(u);
            return moDuoc;
          },
          luuAnh: luu,
          nguonAnhQr: (u) {
            anhDaDung.add(u);
            return _AnhGia(hong: anhHong);
          },
          suKien: suKien.stream,
          clock: () => now,
        ),
      ),
      GoRoute(
        path: '/premium/don/:orderCode',
        builder: (_, s) => Scaffold(body: Text('CHI TIẾT ${s.pathParameters['orderCode']}')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.push('/premium');
    await tester.pumpAndSettle();
    router.push('/premium/cho-thanh-toan', extra: d ?? don);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Trôi [giay] giây: đồng hồ giả lẫn timer của Flutter cùng tiến.
  Future<void> troi(WidgetTester tester, int giay) async {
    for (var i = 0; i < giay; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// Gom lời gọi kênh nền tảng (Clipboard) trong ca.
  List<MethodCall> batKenhHeThong(WidgetTester tester) {
    final goi = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      goi.add(c);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return goi;
  }

  Future<void> cham(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('⭐ vào màn KHÔNG tự mở trang PayOS; đủ thông tin: đếm ngược, mã đơn, số tiền, ảnh QR + Lưu, chuyển khoản, ba bước',
      (tester) async {
    await dung(tester);
    await troi(tester, 2);
    expect(daMo, isEmpty,
        reason: 'người dùng chốt 2026-10-18: không tự mở trang PayOS — màn đủ thông tin để trả trong app');
    expect(find.text('Còn 29:58'), findsOneWidget);
    expect(find.text('Mã đơn #200370869'), findsOneWidget);
    expect(find.text('49.000 đ'), findsNWidgets(2), reason: 'số tiền lớn ở thẻ trên + dòng Số tiền');
    expect(find.text('Gói FlowMoney Premium 30 ngày'), findsOneWidget);
    expect(find.byKey(const Key('cho-anh-qr')), findsOneWidget);
    expect(anhDaDung, [qr], reason: 'ảnh dựng từ qrUrl của server, MỘT lần (không dựng lại mỗi nhịp đồng hồ)');
    expect(find.byKey(const Key('cho-luu-qr')), findsOneWidget, reason: 'nút Lưu không chờ ảnh tải xong');
    expect(find.text('THÔNG TIN CHUYỂN KHOẢN'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.text('NGUYEN VAN A'), findsOneWidget);
    expect(find.text('CSCYDEZ2N10 A8K9M2'), findsOneWidget);
    expect(find.text('Lưu mã QR hoặc chụp màn hình'), findsOneWidget);
    expect(find.text('Mở app ngân hàng → Quét QR → chọn ảnh'), findsOneWidget);
    expect(find.text('Chuyển xong quay lại đây — app tự kiểm tra'), findsOneWidget);
    expect(find.text('Đang chờ bạn chuyển khoản…'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('nút phụ Mở trang thanh toán PayOS mở đúng link; mở hỏng → link chép được', (tester) async {
    moDuoc = false;
    await dung(tester);
    expect(find.byKey(const Key('cho-link')), findsNothing);
    await cham(tester, 'cho-mo-payos');
    expect(daMo, [don.checkoutUrl]);
    expect(find.byKey(const Key('cho-link')), findsOneWidget);
    expect(find.text(don.checkoutUrl.toString()), findsOneWidget);
    final goi = batKenhHeThong(tester);
    await tester.ensureVisible(find.text('Chép'));
    await tester.tap(find.text('Chép'));
    await tester.pump();
    expect(goi.where((c) => c.method == 'Clipboard.setData').map((c) => (c.arguments as Map)['text']),
        [don.checkoutUrl.toString()]);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Lưu mã QR: đã lưu → viên xong; không hỗ trợ / hỏng → viên lỗi bảo chụp màn hình', (tester) async {
    final bat = batThongBao();
    await dung(tester);
    await cham(tester, 'cho-luu-qr');
    expect(luu.goi, [(qr, 'FlowMoney-QR-200370869.png')]);
    expect(bat.cuoi?.cau, 'Đã lưu mã QR vào Thư viện ảnh');
    expect(bat.cuoi?.loai, LoaiThongBao.xong);

    for (final kq in const [KetQuaLuuAnh.khongHoTro, KetQuaLuuAnh.hong]) {
      luu.ketQua = kq;
      await cham(tester, 'cho-luu-qr');
      expect(bat.cuoi?.cau, 'Không lưu được mã QR. Hãy chụp màn hình.', reason: '$kq');
      expect(bat.cuoi?.loai, LoaiThongBao.loi);
    }
    expect(luu.goi, hasLength(3));
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('ảnh QR báo hỏng → câu chỉ sang thông tin / trang PayOS, nút Lưu ẩn; khối thông tin vẫn hiện', (tester) async {
    anhHong = true;
    await dung(tester);
    await tester.pump();
    expect(find.textContaining('Không tải được mã QR'), findsOneWidget);
    expect(find.byKey(const Key('cho-luu-qr')), findsNothing, reason: 'ảnh hỏng thì lưu cũng hỏng — đừng mời bấm');
    expect(find.text('0123456789'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('đơn không qrUrl / thiếu số tài khoản, chủ tài khoản → không ảnh, không nút Lưu, không dòng trống',
      (tester) async {
    await dung(tester,
        d: DonThanhToan(
            orderCode: 7, checkoutUrl: don.checkoutUrl, soTien: 49000, hetHanLuc: don.hetHanLuc, noiDung: 'CS7 X'));
    expect(find.byKey(const Key('cho-anh-qr')), findsNothing);
    expect(find.byKey(const Key('cho-luu-qr')), findsNothing);
    expect(anhDaDung, isEmpty);
    expect(find.text('THÔNG TIN CHUYỂN KHOẢN'), findsOneWidget);
    expect(find.text('Số tài khoản'), findsNothing);
    expect(find.text('Chủ tài khoản'), findsNothing);
    expect(find.text('Số tiền'), findsOneWidget);
    expect(find.text('CS7 X'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('chép số tài khoản / nội dung → Clipboard đúng chuỗi + viên xong', (tester) async {
    final bat = batThongBao();
    await dung(tester);
    final goi = batKenhHeThong(tester);
    await cham(tester, 'cho-chep-stk');
    expect(bat.cuoi?.cau, 'Đã chép số tài khoản');
    await cham(tester, 'cho-chep-noi-dung');
    expect(bat.cuoi?.cau, 'Đã chép nội dung chuyển khoản');
    expect(bat.cuoi?.loai, LoaiThongBao.xong);
    expect(goi.where((c) => c.method == 'Clipboard.setData').map((c) => (c.arguments as Map)['text']),
        ['0123456789', 'CSCYDEZ2N10 A8K9M2']);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('hỏi mỗi 3 s; PAID → làm mới gói, Thành công, Xong pop HAI lớp', (tester) async {
    api.trangThai.addAll(['PENDING', 'PAID']);
    await dung(tester);
    expect(api.soLanHoiDon, 0);
    await troi(tester, 3);
    expect(api.soLanHoiDon, 1);
    await troi(tester, 3);
    await tester.pump();
    await tester.pump();
    expect(api.soLanHoiDon, 2);
    expect(api.soLanHoiGoi, 1, reason: 'PAID → GoiRepository.lamMoi()');
    await tester.pumpAndSettle();
    expect(find.text('Nâng cấp Premium thành công'), findsOneWidget);
    expect(find.textContaining('05/11/2026'), findsOneWidget);
    await troi(tester, 6);
    expect(api.soLanHoiDon, 2, reason: 'đã trả thì dừng hỏi');
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('TRƯỚC'), findsOneWidget, reason: 'pop hai lớp — về màn trước Nâng cấp');
  });

  for (final status in const ['WAITING_CONFIRMATION', 'REFUND_PENDING', 'REFUNDED']) {
    testWidgets('$status → màn được THAY bằng Chi tiết đơn (Back về Nâng cấp), dừng hỏi', (tester) async {
      api.trangThai.add(status);
      await dung(tester);
      await troi(tester, 3);
      await tester.pumpAndSettle();
      expect(find.text('CHI TIẾT 200370869'), findsOneWidget);
      final sau = api.soLanHoiDon;
      await troi(tester, 6);
      expect(api.soLanHoiDon, sau, reason: 'màn Chờ đã bị thay — không còn ai hỏi');
      router.pop();
      // Không `pumpAndSettle`: bản sai (`push`) đưa Back về màn Chờ, vòng xoay chạy mãi → treo thay vì đỏ.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('NÂNG CẤP'), findsOneWidget, reason: 'pushReplacement — Back không quay lại màn Chờ');
      expect(find.text('Thanh toán Premium'), findsNothing);
    });
  }

  testWidgets('EXPIRED → câu hết hạn + Tạo đơn mới pop về Nâng cấp', (tester) async {
    api.trangThai.addAll(['EXPIRED']);
    await dung(tester);
    await troi(tester, 3);
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã hết hạn'), findsOneWidget);
    await tester.tap(find.text('Tạo đơn mới'));
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP'), findsOneWidget);
  });

  /// Đơn hạn 5 giây sau `now` của `setUp` — cho các ca đồng hồ về 0.
  DonThanhToan donHan5Giay() =>
      DonThanhToan(orderCode: 1, checkoutUrl: don.checkoutUrl, soTien: 49000, hetHanLuc: DateTime(2026, 10, 6, 10, 0, 5));

  void doiVongDoi(WidgetTester tester, List<AppLifecycleState> chuoi) {
    // Đi đủ từng bậc — framework kiểm chuyển trạng thái hợp lệ.
    for (final s in chuoi) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  testWidgets('đồng hồ về 0 KHÔNG tự kết luận hết hạn: server còn PENDING → vẫn chờ, vẫn hỏi; server EXPIRED → hết hạn, dừng hỏi',
      (tester) async {
    // Server là nguồn sự thật: `order-status` tự trả EXPIRED cho đơn PENDING quá
    // `expired_at`. Ở đây giờ máy chạy nhanh hơn giờ server 3 giây.
    final hetHanServer = DateTime(2026, 10, 6, 10, 0, 8);
    api.traLoiTheoGio = () => now.isBefore(hetHanServer) ? 'PENDING' : 'EXPIRED';
    await dung(tester, d: donHan5Giay());
    await troi(tester, 6);
    expect(find.text('Còn 00:00'), findsOneWidget);
    expect(find.text('Đơn đã hết hạn'), findsNothing,
        reason: 'đồng hồ trên máy về 0 chỉ là lý do để hỏi — server chưa nói EXPIRED thì chưa được báo hết hạn');
    final truoc = api.soLanHoiDon;
    await troi(tester, 3);
    expect(api.soLanHoiDon, truoc + 1, reason: 'quá hạn theo máy vẫn hỏi theo nhịp');
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã hết hạn'), findsOneWidget);
    final sau = api.soLanHoiDon;
    await troi(tester, 6);
    expect(api.soLanHoiDon, sau, reason: 'server báo hết hạn thì dừng hỏi');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('⭐ G94 việc 1: đồng hồ về 0 lúc app ở nền, quay lại → sang Chi tiết đơn để xác nhận, KHÔNG "Đơn đã hết hạn"',
      (tester) async {
    // Người dùng sang app ngân hàng chuyển thừa; webhook đưa đơn sang
    // WAITING_CONFIRMATION — server không bao giờ cho trạng thái ấy hết hạn; họ
    // quay lại sau khi đồng hồ trên máy đã về 0.
    api.trangThai.add('WAITING_CONFIRMATION');
    await dung(tester, d: donHan5Giay());
    doiVongDoi(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await troi(tester, 8);
    expect(api.soLanHoiDon, 0, reason: 'app ở nền thì không hỏi theo nhịp');
    doiVongDoi(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.soLanHoiDon, 1, reason: 'quay lại app → hỏi ngay');
    expect(find.text('Đơn đã hết hạn'), findsNothing,
        reason: 'đồng hồ về 0 lúc màn không hiện từng đưa màn sang hết hạn, rồi `_khiCo` bỏ qua câu trả lời của server');
    expect(find.text('CHI TIẾT 1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('⭐ G94 việc 1: webhook tới sát hạn — đồng hồ về 0 trước lượt hỏi kế, server báo WAITING_CONFIRMATION → Chi tiết đơn',
      (tester) async {
    api.trangThai.addAll(['PENDING', 'WAITING_CONFIRMATION']);
    await dung(tester, d: donHan5Giay());
    // Giây 3: PENDING · giây 5: đồng hồ về 0 · giây 6: WAITING_CONFIRMATION.
    await troi(tester, 6);
    await tester.pumpAndSettle();
    expect(api.soLanHoiDon, 2);
    expect(find.text('Đơn đã hết hạn'), findsNothing);
    expect(find.text('CHI TIẾT 1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('"Tôi đã chuyển khoản" hỏi NGAY; socket taiKhoanNangCap / donThanhToanDoi hỏi NGAY; sự kiện khác thì không',
      (tester) async {
    await dung(tester);
    await cham(tester, 'cho-da-chuyen');
    expect(api.soLanHoiDon, 1);
    suKien.add(RealtimeEvent.taiKhoanNangCap);
    await tester.pump();
    await tester.pump();
    expect(api.soLanHoiDon, 2);
    suKien.add(RealtimeEvent.donThanhToanDoi);
    await tester.pump();
    await tester.pump();
    expect(api.soLanHoiDon, 3, reason: 'payment.* (chuyển thừa / thiếu / đã nhận) — hỏi ngay, không chờ nhịp 3 s');
    suKien.add(RealtimeEvent.dongBoXong);
    await tester.pump();
    expect(api.soLanHoiDon, 3, reason: 'sự kiện khác không hỏi');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('rời màn (Huỷ) → dừng hỏi', (tester) async {
    await dung(tester);
    await cham(tester, 'cho-huy');
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP'), findsOneWidget);
    final truoc = api.soLanHoiDon;
    await troi(tester, 9);
    expect(api.soLanHoiDon, truoc);
  });

  for (final rong in const [360.0, 320.0]) {
    testWidgets('$rong × 640 không tràn — đủ khối, chủ tài khoản dài, mở PayOS hỏng (link dài)', (tester) async {
      tester.view.physicalSize = Size(rong, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      moDuoc = false;
      await dung(tester,
          d: DonThanhToan(
            orderCode: 200370869,
            checkoutUrl: Uri.parse('https://pay.payos.vn/web/9d8f7e6a5b4c3d2e1f0a9b8c7d6e5f4a'),
            soTien: 9999999999999,
            hetHanLuc: don.hetHanLuc,
            qrUrl: qr,
            noiDung: 'CSCYDEZ2N10 A8K9M2',
            soTaiKhoan: '0123456789012345',
            chuTaiKhoan: 'CONG TY CO PHAN CONG NGHE THANH TOAN VIET NAM',
          ));
      expect(tester.takeException(), isNull);
      // `Text` dài ngắt / cắt im lặng — số tiền lớn phải nằm trọn một dòng.
      final p = tester.renderObject<RenderParagraph>(find.text('9.999.999.999.999 đ').first);
      expect(p.didExceedMaxLines, isFalse);
      expect(p.size.height, lessThan(p.text.style!.fontSize! * 2));
      await cham(tester, 'cho-mo-payos');
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
    });
  }
}
