/// Cửa chặn trần Basic chạy trong `GoRouter` THẬT (spec Premium 7.1) — cùng
/// closure `redirectTaoTheoGoi` mà `app_router.dart` gắn vào ba route tạo, nên
/// router test và router thật không thể lệch nhau về luật.
///
/// ⚠️ Vẫn phải nghiệm thu máy thật: bẫy `StatefulShellRoute` (7.8
/// `NOTIFICATION_FEATURE.md`) chỉ nổ với cây route đầy đủ.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/premium/data/chan_theo_goi.dart';
import 'package:flowmoney/features/premium/data/dem_dang_hoat_dong.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _DemGia implements NguonDemDangHoatDong {
  _DemGia(this.so);
  final int so;
  @override
  Future<int> dem(LoaiTran loai, int idaccount) async => so;
}

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

void main() {
  late GoRouter router;

  Future<void> dung(WidgetTester tester, {required int dangCo}) async {
    if (sl.isRegistered<GoiRepository>()) await sl.unregister<GoiRepository>();
    if (sl.isRegistered<NguonDemDangHoatDong>()) {
      await sl.unregister<NguonDemDangHoatDong>();
    }
    final repo = GoiRepository(api: _ApiIm(), kho: InMemoryGoiStore());
    await repo.datTaiKhoan(10);
    sl.registerSingleton<GoiRepository>(repo);
    sl.registerSingleton<NguonDemDangHoatDong>(_DemGia(dangCo));
    addTearDown(() async {
      await sl.unregister<GoiRepository>();
      await sl.unregister<NguonDemDangHoatDong>();
      await repo.dispose();
    });

    router = GoRouter(initialLocation: '/truoc', routes: [
      GoRoute(
          path: '/truoc',
          builder: (_, __) => const Scaffold(body: Text('TRƯỚC'))),
      GoRoute(
          path: '/wallets/add',
          redirect: redirectTaoTheoGoi(LoaiTran.vi),
          builder: (_, __) => const Scaffold(body: Text('FORM VÍ'))),
      GoRoute(
          path: '/budget/rules',
          redirect: redirectTaoTheoGoi(LoaiTran.nganSach),
          builder: (_, __) => const Scaffold(body: Text('FORM NS'))),
      GoRoute(
          path: '/goals/add',
          redirect: redirectTaoTheoGoi(LoaiTran.mucTieu),
          builder: (_, __) => const Scaffold(body: Text('FORM MT'))),
      GoRoute(
          path: '/premium',
          builder: (_, s) => Scaffold(
              body: Text('NÂNG CẤP ${s.uri.queryParameters['tran']}'))),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('Basic 3/3: push /wallets/add → đứng ở Nâng cấp với tran=vi',
      (tester) async {
    await dung(tester, dangCo: 3);
    router.push('/wallets/add');
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP vi'), findsOneWidget);
    expect(find.text('FORM VÍ'), findsNothing);
  });

  testWidgets('Basic 2/3: form mở', (tester) async {
    await dung(tester, dangCo: 2);
    router.push('/goals/add');
    await tester.pumpAndSettle();
    expect(find.text('FORM MT'), findsOneWidget);
  });

  testWidgets('/budget/rules?id=… mở form sửa dù 3/3', (tester) async {
    await dung(tester, dangCo: 3);
    router.push('/budget/rules?id=b1');
    await tester.pumpAndSettle();
    expect(find.text('FORM NS'), findsOneWidget);
  });

  testWidgets('/budget/rules?category=… (thẻ Chưa đặt ngân sách) bị chặn khi 3/3',
      (tester) async {
    await dung(tester, dangCo: 3);
    router.push('/budget/rules?category=c1&amount=5');
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP ngan_sach'), findsOneWidget);
  });
}
