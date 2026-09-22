/// Khối "Nhận xét" trên trang Hoá đơn (chặng 1.3) — màn Stitch
/// `179dbd70b0fd4b6a97df6b7d2c38d0e2` *"Hoá đơn - Khối Nhận xét AI"*.
///
/// Gói số và mẫu câu có bộ test riêng (`goi_so_hoa_don_test.dart`); ở đây chỉ
/// kiểm **chỗ nối**: khối có dựng không, đứng đúng chỗ không, và kỳ rỗng thì
/// nó nói một câu thật chứ không biến mất.
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';

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

Bill _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: amount,
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
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c1',
      idaccount: 10,
      name: 'Nhà cửa',
      classify: 'chi',
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> moTrang(WidgetTester tester, List<Bill> bills,
      {Size khoMan = const Size(411, 2400)}) async {
    tester.view.physicalSize = khoMan;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(
      repository: _FixedBillRepository(bills),
      now: () => now,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(home: BillPage(now: now)),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();
  }

  testWidgets('khối hiện đúng câu của kỳ còn nợ', (tester) async {
    await moTrang(tester, [_bill(dueDate: DateTime(2026, 9, 26))]);

    expect(find.text('NHẬN XÉT'), findsOneWidget);
    expect(
        find.text('Kỳ này còn 1 hoá đơn chưa trả, tổng 100.000 đ.'),
        findsOneWidget);
  });

  testWidgets('khối đứng GIỮA thẻ tổng quan và hàng tab, đúng màn Stitch',
      (tester) async {
    await moTrang(tester, [_bill(dueDate: DateTime(2026, 9, 26))]);

    final yNhanXet = tester.getTopLeft(find.text('NHẬN XÉT')).dy;
    final yTab = tester.getTopLeft(find.text('Cần thanh toán (1)')).dy;
    // Thẻ tổng quan là con số lớn "Còn phải trả" ở đầu trang.
    final yTong = tester.getTopLeft(find.text('100.000 đ').first).dy;

    expect(yNhanXet, greaterThan(yTong),
        reason: 'khối phải nằm DƯỚI thẻ tổng quan');
    expect(yNhanXet, lessThan(yTab), reason: 'và TRÊN hàng tab');
  });

  testWidgets('kỳ rỗng: khối vẫn hiện và nói một câu THẬT', (tester) async {
    await moTrang(tester, const []);

    expect(find.text('NHẬN XÉT'), findsOneWidget,
        reason: 'mục 1 AI_EDGE_FEATURE.md: thiếu dữ liệu là một CÂU, không '
            'phải một khối biến mất');
    expect(find.text('Kỳ này chưa có hoá đơn nào.'), findsOneWidget);
  });

  testWidgets('khổ màn THẤP + kỳ rỗng: không tràn bố cục', (tester) async {
    // ⚠️ Ca này sinh ra từ một lỗi thật: khối Nhận xét lấy bớt chiều cao của
    // `Expanded`, và trạng thái rỗng vốn là `Column` cao cố định nên tràn
    // **73 px** ở khổ 600. Máy cao thì không thấy gì đổi — đúng vùng mù số 1
    // của `flutter test` (`CLAUDE.md`). Sửa bằng cách cho nó cuộn được.
    await moTrang(tester, const [], khoMan: const Size(411, 600));
    expect(tester.takeException(), isNull);
  });
}
