/// Màn Lịch sử mua `/premium/lich-su` (spec Premium 9.4): danh sách ngày · số
/// tiền · trạng thái; rỗng → câu rỗng; lỗi → câu ngắn + Thử lại.
library;

import 'package:dio/dio.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/presentation/pages/lich_su_mua_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiGia implements PaymentApi {
  _ApiGia(this.items, {this.nem = false});
  final List<Map<String, Object?>> items;
  bool nem;
  int soLan = 0;

  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) async {
    soLan++;
    if (nem) {
      final req = RequestOptions(path: '/payment/history');
      throw DioException(requestOptions: req, type: DioExceptionType.connectionError);
    }
    return items;
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
}

void main() {
  Widget boc(PaymentApi api) =>
      MaterialApp(theme: AppTheme.lightTheme, home: LichSuMuaPage(api: api));

  testWidgets('có dòng: ngày dd/MM/yyyy, tiền, trạng thái', (tester) async {
    await tester.pumpWidget(boc(_ApiGia([
      {'order_code': 1, 'amount': 49000, 'status': 'PAID', 'created_at': '2026-10-05T18:39:30.000Z', 'paid_at': '2026-10-05T18:40:15.000Z'},
      {'order_code': 2, 'amount': 49000, 'status': 'EXPIRED', 'created_at': '2026-10-01T10:00:00.000Z'},
    ])));
    await tester.pumpAndSettle();
    expect(find.text('49.000 đ'), findsNWidgets(2));
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Hết hạn'), findsOneWidget);
    expect(find.textContaining('/10/2026'), findsNWidgets(2));
  });

  testWidgets('rỗng → câu rỗng', (tester) async {
    await tester.pumpWidget(boc(_ApiGia(const [])));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lượt mua nào'), findsOneWidget);
  });

  testWidgets('lỗi → câu ngắn + Thử lại gọi lại API', (tester) async {
    final api = _ApiGia(const [], nem: true);
    await tester.pumpWidget(boc(api));
    await tester.pumpAndSettle();
    expect(find.text('Không có kết nối. Thử lại khi có mạng.'), findsOneWidget);
    api.nem = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(api.soLan, 2);
    expect(find.text('Chưa có lượt mua nào'), findsOneWidget);
  });

  testWidgets('360 × 640 không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(boc(_ApiGia([
      {'order_code': 1, 'amount': 49000, 'status': 'PAID', 'created_at': '2026-10-05T18:39:30.000Z'},
    ])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
