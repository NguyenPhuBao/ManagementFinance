/// Màn Lịch sử mua `/premium/lich-su` (spec Premium 9.4; spec G94 2026-10-18 mục 5.6; Stitch `04c4aa7d…`): danh sách
/// ngày · số tiền · nhãn trạng thái dùng chung; MỌI dòng bấm được → Chi tiết đơn, quay về thì nạp lại; tín hiệu
/// `payment.*` → nạp lại; rỗng → câu rỗng; lỗi → câu ngắn + Thử lại.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository_impl.dart';
import 'package:flowmoney/features/premium/presentation/pages/lich_su_mua_page.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _ApiGia implements PaymentApi {
  _ApiGia(this.items);

  List<Map<String, Object?>> items;

  /// Có thì lượt `lichSu` kế ném nó (một lần).
  Object? loi;
  int soLan = 0;

  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) async {
    soLan++;
    final l = loi;
    if (l != null) {
      loi = null;
      throw l;
    }
    return items;
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) =>
      throw UnimplementedError();
}

DioException _loi(int? code) {
  final req = RequestOptions(path: '/payment/history');
  return code == null
      ? DioException(requestOptions: req, type: DioExceptionType.connectionError)
      : DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: code));
}

Map<String, Object?> _dong(int ma, String status, {String createdAt = '2026-10-01T10:00:00.000Z', String? paidAt}) => {
      'order_code': ma,
      'amount': 49000,
      'status': status,
      'created_at': createdAt,
      'paid_at': paidAt,
    };

void main() {
  late StreamController<RealtimeEvent> suKien;

  setUp(() => suKien = StreamController<RealtimeEvent>.broadcast());
  tearDown(() => suKien.close());

  /// `/truoc` → push `/premium/lich-su`; `/premium/don/:orderCode` là màn giả.
  Future<GoRouter> dung(WidgetTester tester, _ApiGia api) async {
    final router = GoRouter(initialLocation: '/truoc', routes: [
      GoRoute(path: '/truoc', builder: (_, __) => const Scaffold(body: Text('TRƯỚC'))),
      GoRoute(
        path: '/premium/lich-su',
        builder: (_, __) => LichSuMuaPage(repo: DonThanhToanRepositoryImpl(api: api), suKien: suKien.stream),
      ),
      GoRoute(
        path: '/premium/don/:orderCode',
        builder: (_, s) => Scaffold(body: Text('CHI TIẾT ${s.pathParameters['orderCode']}')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/premium/lich-su');
    await tester.pumpAndSettle();
    return router;
  }

  Color? mauChu(WidgetTester tester, String chu) => tester.widget<Text>(find.text(chu)).style?.color;

  testWidgets('có dòng: ngày dd/MM/yyyy, tiền, trạng thái, mũi tên ›', (tester) async {
    await dung(
        tester,
        _ApiGia([
          _dong(1, 'PAID', createdAt: '2026-10-05T18:39:30.000Z', paidAt: '2026-10-05T18:40:15.000Z'),
          _dong(2, 'EXPIRED'),
        ]));
    expect(find.text('49.000 đ'), findsNWidgets(2));
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Hết hạn'), findsOneWidget);
    expect(find.textContaining('/10/2026'), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2), reason: 'mọi dòng bấm được — mũi tên báo điều ấy');
  });

  testWidgets('nhãn + màu dùng chung: Chờ xác nhận / Chờ hoàn tiền cam, Đã hoàn tiền xám, Đã thanh toán xanh',
      (tester) async {
    await dung(
        tester,
        _ApiGia([
          _dong(1, 'WAITING_CONFIRMATION'),
          _dong(2, 'REFUND_PENDING'),
          _dong(3, 'REFUNDED'),
          _dong(4, 'PAID'),
        ]));
    expect(mauChu(tester, 'Chờ xác nhận'), AppColors.warning);
    expect(mauChu(tester, 'Chờ hoàn tiền'), AppColors.warning);
    expect(mauChu(tester, 'Đã hoàn tiền'), AppColors.textSecondary,
        reason: 'bản backend viết ghi cứng ba màu tím / cam đậm / xanh ngọc ngoài AppColors');
    expect(mauChu(tester, 'Đã thanh toán'), AppColors.income);
  });

  testWidgets('chạm dòng → Chi tiết đơn của đúng mã; quay về → nạp lại lịch sử', (tester) async {
    final api = _ApiGia([_dong(5, 'WAITING_CONFIRMATION'), _dong(6, 'PAID')]);
    final router = await dung(tester, api);
    expect(api.soLan, 1);
    await tester.tap(find.byKey(const Key('lich-su-dong-5')));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT 5'), findsOneWidget);

    api.items = [_dong(5, 'PAID'), _dong(6, 'PAID')];
    router.pop();
    await tester.pumpAndSettle();
    expect(api.soLan, 2, reason: 'vừa xác nhận / từ chối ở Chi tiết đơn — dòng phải đổi theo');
    expect(find.text('Chờ xác nhận'), findsNothing);
    expect(find.text('Đã thanh toán'), findsNWidgets(2));
  });

  testWidgets('tín hiệu donThanhToanDoi → nạp lại; sự kiện khác thì không', (tester) async {
    final api = _ApiGia([_dong(1, 'PENDING')]);
    await dung(tester, api);
    suKien.add(RealtimeEvent.donThanhToanDoi);
    await tester.pumpAndSettle();
    expect(api.soLan, 2);
    suKien.add(RealtimeEvent.dongBoXong);
    await tester.pumpAndSettle();
    expect(api.soLan, 2);
  });

  testWidgets('rỗng → câu rỗng', (tester) async {
    await dung(tester, _ApiGia(const []));
    expect(find.text('Chưa có lượt mua nào'), findsOneWidget);
  });

  testWidgets('lỗi mạng → câu ngắn + Thử lại gọi lại API', (tester) async {
    final api = _ApiGia(const [])..loi = _loi(null);
    await dung(tester, api);
    expect(find.text('Không có kết nối. Thử lại khi có mạng.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(api.soLan, 2);
    expect(find.text('Chưa có lượt mua nào'), findsOneWidget);
  });

  testWidgets('bị từ chối (4xx) → câu nói về LỊCH SỬ, không phải "Không tạo được đơn thanh toán"', (tester) async {
    await dung(tester, _ApiGia(const [])..loi = _loi(403));
    expect(find.text('Không tải được lịch sử mua. Thử lại sau.'), findsOneWidget);
    expect(find.text('Không tạo được đơn thanh toán. Thử lại sau.'), findsNothing);
  });

  for (final rong in const [360.0, 320.0]) {
    testWidgets('$rong × 640 không tràn', (tester) async {
      tester.view.physicalSize = Size(rong, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await dung(tester, _ApiGia([_dong(1, 'WAITING_CONFIRMATION'), _dong(2, 'REFUND_PENDING')]));
      expect(tester.takeException(), isNull);
    });
  }
}
