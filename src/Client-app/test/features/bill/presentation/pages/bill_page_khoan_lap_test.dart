/// Thẻ "Có vẻ là khoản lặp" (B2) trên trang Hoá đơn — kiểm **chỗ nối**: thẻ đứng
/// giữa khối Nhận xét và hàng tab, và trang không tràn ở khổ màn thấp.
///
/// ⚠️ Bẫy chặng 1.3: phần trên hàng tab là một `Column` cố định, danh sách nằm
/// trong `Expanded`. Mỗi khối thêm vào đầu trang lấy bớt chiều cao của danh
/// sách; khối Nhận xét từng làm trạng thái rỗng tràn 73 px.
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/de_xuat_hoa_don_nguon.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';
import 'package:flowmoney/features/transaction/domain/khoan_lap.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());
  final AuthState _fixed;
  @override
  AuthState get state => _fixed;
}

class _FixedBillRepository implements BillRepository {
  _FixedBillRepository(this.bills);
  final List<Bill> bills;
  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);
  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => const {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NguonGia implements DeXuatHoaDonNguon {
  _NguonGia(this.ds);
  final List<KhoanLap>? ds;
  @override
  Future<List<KhoanLap>?> tai(int idaccount) async => ds;
  @override
  Future<Map<String, Category>> bangDanhMuc(int idaccount) async => const {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

KhoanLap _kl(String ten) => KhoanLap(
      khoaNhom: '$ten|c1',
      ten: ten,
      soTien: 3000000,
      chuKy: kBillCycleMonth,
      ngayGoc: 5,
      ngayGanNhat: DateTime(2026, 9, 5),
      categoryId: 'c1',
      walletId: 'w1',
      soLan: 3,
    );

Bill _bill(String id, DateTime dueDate) => Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện $id',
      amount: 100000,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 9, 19, 10);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> moTrang(WidgetTester tester, List<Bill> bills, List<KhoanLap>? ds,
      {Size khoMan = const Size(411, 2400), bool coRouter = false}) async {
    tester.view.physicalSize = khoMan;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(repository: _FixedBillRepository(bills), now: () => now);
    addTearDown(bloc.close);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: coRouter
          // GoRouter THẬT: nút thêm gọi `context.push('/bills/add')`, thứ ném
          // lỗi dưới `MaterialApp(home:)` trần.
          ? MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: GoRouter(initialLocation: '/bills', routes: [
                GoRoute(
                    path: '/bills',
                    builder: (_, __) =>
                        BillPage(now: now, deXuatNguon: _NguonGia(ds))),
                GoRoute(
                    path: '/bills/add',
                    builder: (_, __) =>
                        const Scaffold(body: Text('TRANG TẠO HOÁ ĐƠN'))),
              ]),
            )
          : MaterialApp(
              theme: AppTheme.lightTheme,
              home: BillPage(now: now, deXuatNguon: _NguonGia(ds)),
            ),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();
  }

  final baDong = [_kl('Tiền nhà'), _kl('Gửi xe'), _kl('Netflix')];

  testWidgets('thẻ đứng GIỮA khối Nhận xét và hàng tab', (tester) async {
    await moTrang(tester, [_bill('a', DateTime(2026, 9, 25))], baDong);
    final the = tester.getRect(find.byKey(const ValueKey('the-khoan-lap')));
    final nhanXet = tester.getRect(find.textContaining('NHẬN XÉT').first);
    final tab = tester.getRect(find.byType(TabBar));
    expect(the.top, greaterThan(nhanXet.bottom));
    expect(the.bottom, lessThanOrEqualTo(tab.top),
        reason: 'đặt dưới hàng tab là thẻ rơi vào một tab và trông như gợi ý riêng của tab ấy');
  });

  testWidgets('không có gì để gợi ý → không có thẻ', (tester) async {
    await moTrang(tester, [_bill('a', DateTime(2026, 9, 25))], null);
    expect(find.byKey(const ValueKey('the-khoan-lap')), findsNothing);
  });

  testWidgets('cuộn hết phần đầu: hàng tab GHIM dưới app bar, hoá đơn đầu KHÔNG khuất dưới nó',
      (tester) async {
    await moTrang(
      tester,
      [for (var i = 0; i < 10; i++) _bill('b$i', DateTime(2026, 9, 20 + i))],
      baDong,
      khoMan: const Size(360, 640),
    );
    final appBar = tester.getRect(find.byType(AppBar));
    // Phần đầu trang (thẻ tổng quan, Nhận xét, thẻ khoản lặp) cao hơn cả màn ở
    // khổ này — cuộn bộ cuộn NGOÀI tới cuối, bộ cuộn trong (danh sách) chưa đụng.
    final st = tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    st.outerController.jumpTo(st.outerController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final tab = tester.getRect(find.byType(TabBar));
    final dau = tester.getRect(find.text('Tiền điện b0'));
    expect(tab.top, closeTo(appBar.bottom, 1), reason: 'hàng tab phải ghim ngay dưới app bar');
    expect(dau.top, greaterThanOrEqualTo(tab.bottom),
        reason: 'thiếu SliverOverlapInjector thì hoá đơn đầu nằm khuất dưới hàng tab ghim');
  });

  group('G57 — nút tạo hoá đơn ở thanh tiêu đề (màn Stitch e8b460b4)', () {
    testWidgets('⚠️ 360 × 640 có thẻ khoản lặp: KHÔNG còn nút rộng đè lên hàng tab',
        (tester) async {
      // Nút rộng cố định ở đáy (`Positioned` bottom 24) nằm đúng trên hàng tab
      // khi phần đầu trang cao — thấy trên Realme 360 dp. Màn Stitch B2 đặt nút
      // thêm ở góc phải thanh tiêu đề.
      await moTrang(tester, [_bill('a', DateTime(2026, 9, 25))], baDong,
          khoMan: const Size(360, 640));
      expect(find.widgetWithText(ElevatedButton, 'Tạo hóa đơn lặp lại mới'),
          findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Tạo hóa đơn lặp lại mới'),
        ),
        findsOneWidget,
        reason: 'lối tạo hoá đơn phải còn — chỉ đổi chỗ, không mất',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chạm nút + ở thanh tiêu đề mở trang tạo hoá đơn', (tester) async {
      await moTrang(tester, [_bill('a', DateTime(2026, 9, 25))], null, coRouter: true);
      await tester.tap(find.byTooltip('Tạo hóa đơn lặp lại mới'));
      await tester.pumpAndSettle();
      expect(find.text('TRANG TẠO HOÁ ĐƠN'), findsOneWidget);
    });
  });

  for (final coHoaDon in [true, false]) {
    testWidgets('khổ 360 × 640, thẻ ba dòng, ${coHoaDon ? 'có hoá đơn' : 'danh sách rỗng'} → không tràn',
        (tester) async {
      await moTrang(
        tester,
        coHoaDon ? [_bill('a', DateTime(2026, 9, 25)), _bill('b', DateTime(2026, 9, 28))] : const [],
        baDong,
        khoMan: const Size(360, 640),
      );
      expect(find.byKey(const ValueKey('the-khoan-lap')), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'bẫy chặng 1.3 — khối thêm vào đầu trang lấy bớt chiều cao của danh sách');
    });
  }
}
