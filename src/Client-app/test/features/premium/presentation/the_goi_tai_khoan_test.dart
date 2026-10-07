/// Thẻ "Gói của bạn" ở tab Cá nhân — điểm vào có chủ ý duy nhất của `/premium`
/// (spec Premium 10). Không GoiCubit trong cây (test cũ của trang) → không dựng.
library;

import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/widgets/the_goi_tai_khoan.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 10, 6, 10);

  Future<GoiCubit> cubit({TrangThaiGoi? kho, String? loaiPhien}) async {
    final store = InMemoryGoiStore();
    if (kho != null) await store.ghi(10, kho);
    final repo = GoiRepository(api: _ApiIm(), kho: store, clock: () => now);
    await repo.datTaiKhoan(10, loaiPhien: loaiPhien);
    final c = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await c.close();
      await repo.dispose();
    });
    return c;
  }

  Widget boc(Widget w, {GoiCubit? c, Size? khung}) {
    final than = Scaffold(body: SizedBox(width: khung?.width, child: w));
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: c == null ? than : BlocProvider<GoiCubit>.value(value: c, child: than),
    );
  }

  testWidgets('Basic: "Gói Basic" + Nâng cấp; chạm → onMo', (tester) async {
    var mo = 0;
    final c = await cubit();
    await tester.pumpWidget(boc(TheGoiTaiKhoan(onMo: () => mo++), c: c));
    expect(find.text('Gói Basic'), findsOneWidget);
    expect(find.text('Nâng cấp'), findsOneWidget);
    expect(find.text('Gia hạn'), findsNothing);
    await tester.tap(find.text('Nâng cấp'));
    expect(mo, 1);
  });

  testWidgets('Premium: "Premium" + còn N ngày · đến dd/MM/yyyy + Gia hạn', (tester) async {
    final c = await cubit(
        kho: TrangThaiGoi(loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5, 8), nhanLuc: now));
    // Truyền `clock`: thiếu nó thì thẻ đếm ngày theo đồng hồ THẬT và ca này đỏ
    // ngay khi máy chạy test qua nửa đêm 07/10 ("Còn 29 ngày").
    await tester.pumpWidget(boc(TheGoiTaiKhoan(clock: () => now), c: c));
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Còn 30 ngày · đến 05/11/2026'), findsOneWidget);
    expect(find.text('Gia hạn'), findsOneWidget);
  });

  testWidgets('Premium chưa biết hạn: chỉ "Premium"', (tester) async {
    final c = await cubit(loaiPhien: 'Premium');
    await tester.pumpWidget(boc(const TheGoiTaiKhoan(), c: c));
    expect(find.text('Premium'), findsOneWidget);
    expect(find.textContaining('Còn '), findsNothing);
  });

  testWidgets('không GoiCubit trong cây → không dựng gì', (tester) async {
    await tester.pumpWidget(boc(const TheGoiTaiKhoan()));
    expect(find.byKey(const Key('the-goi-tai-khoan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp không tràn (Premium, dòng hạn dài nhất)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await cubit(
        kho: TrangThaiGoi(loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 25, 8), nhanLuc: now));
    await tester.pumpWidget(boc(TheGoiTaiKhoan(clock: () => now), c: c));
    expect(tester.takeException(), isNull);
  });
}
