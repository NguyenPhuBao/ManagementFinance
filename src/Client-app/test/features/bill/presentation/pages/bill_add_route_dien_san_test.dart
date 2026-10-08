/// Route `/bills/add` của app đọc query điền sẵn (B2) — canh chính dòng nối ở
/// `app_router.dart`. Hàm thuần `dienSanTuQuery` và form đã có ca riêng; nhưng
/// route đọc nhầm chỗ (vd. `pathParameters`) thì mọi ca ấy vẫn xanh trong khi
/// nút **Tạo** của thẻ khoản lặp mở ra một form trống, im lặng.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/constants/app_router.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_add_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowmoney/features/premium/data/dem_dang_hoat_dong.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthCoDinh extends AuthBloc {
  _AuthCoDinh(this._s) : super(authRepository: _RepoGia());
  final AuthState _s;
  @override
  AuthState get state => _s;
}

class _BillRepoGia implements BillRepository {
  @override
  Stream<List<Bill>> watchBills(int idaccount) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    if (sl.isRegistered<BillBloc>()) await sl.unregister<BillBloc>();
    sl.registerFactory<BillBloc>(() => BillBloc(repository: _BillRepoGia()));
    // `/bills/add` nay có cửa chặn trần hoá đơn (spec phân quyền 2026-10-08) đọc `sl<GoiRepository>` lúc chạy. Chưa
    // có phiên (`idaccount == null`) → cửa cho qua, đúng như app trước khi đăng nhập.
    if (sl.isRegistered<GoiRepository>()) await sl.unregister<GoiRepository>();
    sl.registerSingleton<GoiRepository>(GoiRepository(api: _ApiGoiIm(), kho: InMemoryGoiStore()));
    if (sl.isRegistered<NguonDemDangHoatDong>()) await sl.unregister<NguonDemDangHoatDong>();
    sl.registerSingleton<NguonDemDangHoatDong>(_DemKhong());
  });
  tearDown(() async {
    await sl.unregister<GoiRepository>();
    await sl.unregister<NguonDemDangHoatDong>();
    await sl.unregister<BillBloc>();
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> mo(WidgetTester tester, String duong) async {
    tester.view.physicalSize = const Size(411, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _AuthCoDinh(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = AppRouter.createRouter(duong, auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('query của thẻ khoản lặp tới được form qua route thật', (tester) async {
    await mo(tester, '/bills/add?name=Netflix&amount=99000&cycle=Month&anchor=15&start=2026-09-15');
    final trang = tester.widget<BillAddPage>(find.byType(BillAddPage));
    expect(trang.dienSan, isNotNull, reason: 'route phải đọc query, không phải bỏ qua nó');
    expect(trang.dienSan!.ten, 'Netflix');
    expect(trang.dienSan!.soTien, 99000);
    expect(trang.dienSan!.ngayGoc, 15);
    expect(find.text('Netflix'), findsOneWidget);
  });

  testWidgets('không có query → form trống như cũ', (tester) async {
    await mo(tester, '/bills/add');
    expect(tester.widget<BillAddPage>(find.byType(BillAddPage)).dienSan, isNull);
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

class _DemKhong implements NguonDemDangHoatDong {
  @override
  Future<int> dem(LoaiTran loai, int idaccount) async => 0;
}
