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
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_detail_page.dart';
import 'package:flowmoney/features/bill/presentation/widgets/bill_payment_sheet.dart';

/// Trang chi tiết hoá đơn (`/bills/:id`): mở khi chạm một dòng chưa trả.
///
/// Hiện: tên, số tiền, trạng thái, hạn, chu kỳ, ví, danh mục, nhắc trước, tự
/// trả, ghi chú; "Lịch sử các kỳ" theo chuỗi `generatedFromBillId` kèm ngày
/// trả; nút Thanh toán / Hoàn tác / Sửa / Xoá. Đọc CSDL trực tiếp như trang
/// chi tiết mục tiêu; thao tác đi qua BillBloc như trang danh sách.
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

void main() {
  final now = DateTime(2026, 9, 6, 10);
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
      name: 'Điện nước',
      classify: 'chi',
      icon: const drift.Value('receipt'),
      colour: const drift.Value('#4CAF50'),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> hoaDon(
    String id,
    DateTime due, {
    String? tu,
    bool paid = false,
    bool tuTra = false,
    String note = '',
  }) =>
      db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: 10,
        walletId: const drift.Value('w1'),
        categoryId: const drift.Value('c1'),
        generatedFromBillId: drift.Value(tu),
        name: 'Tiền điện',
        amount: 250000,
        startDate: drift.Value(due.subtract(const Duration(days: 30))),
        dueDate: due,
        payStatus: drift.Value(paid ? 'Payed' : 'Pending'),
        isPaid: drift.Value(paid),
        autoPayEnabled: drift.Value(tuTra),
        timeNotification: const drift.Value('3'),
        isRecurrence: const drift.Value(true),
        timeRecurrence: const drift.Value(kBillCycleMonth),
        note: drift.Value(note),
        updatedAt: DateTime(2026, 9, 1),
      ));

  Future<void> khoanChi(String billId, DateTime ngay) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: 'tx-$billId',
        idaccount: 10,
        walletId: 'w1',
        categoryId: const drift.Value('c1'),
        amount: 250000,
        type: 'chi',
        billId: drift.Value(billId),
        date: ngay,
        updatedAt: ngay,
      ));

  Future<void> dungTrang(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(411, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
          id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(
      repository:
          BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db),
      now: () => now,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(home: BillDetailPage(id: id, now: now)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện đủ thông tin của kỳ đang mở, không tràn ở 411dp',
      (tester) async {
    await hoaDon('k3', DateTime(2026, 9, 8), tuTra: true, note: 'Số công tơ');
    await dungTrang(tester, 'k3');

    expect(find.text('Tiền điện'), findsWidgets);
    expect(find.textContaining('250.000'), findsWidgets);
    expect(find.text('SẮP ĐẾN HẠN'), findsOneWidget,
        reason: 'Cùng bốn trạng thái và nhãn với trang danh sách.');
    expect(find.text('08/09/2026'), findsWidgets);
    expect(find.text('Hàng tháng'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('Điện nước'), findsOneWidget);
    expect(find.text('Số công tơ'), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-detail-autopay')), findsOneWidget,
        reason: 'Trang chi tiết là nơi duy nhất nói rõ hoá đơn này app sẽ '
            'tự trừ tiền.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lịch sử các kỳ theo chuỗi generatedFromBillId, kèm ngày trả',
      (tester) async {
    await hoaDon('k1', DateTime(2026, 7, 6), paid: true);
    await hoaDon('k2', DateTime(2026, 8, 6), tu: 'k1', paid: true);
    await hoaDon('k3', DateTime(2026, 9, 6), tu: 'k2');
    // Hoá đơn khác trùng tên, không thuộc chuỗi.
    await hoaDon('x1', DateTime(2026, 9, 20));
    await khoanChi('k1', DateTime(2026, 7, 4));
    await khoanChi('k2', DateTime(2026, 8, 7));
    await dungTrang(tester, 'k3');

    expect(find.byKey(const ValueKey('bill-history-k1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-history-k2')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-history-k3')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-history-x1')), findsNothing,
        reason: 'Trùng tên không phải cùng chuỗi.');
    expect(find.textContaining('Trả 04/07/2026'), findsOneWidget,
        reason: 'Ngày trả lấy từ khoản chi, không đoán theo hạn.');
    expect(find.textContaining('Trả 07/08/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chưa trả: có Thanh toán, không có Hoàn tác; bấm mở bảng trả',
      (tester) async {
    await hoaDon('k3', DateTime(2026, 9, 8));
    await dungTrang(tester, 'k3');

    expect(find.byKey(const ValueKey('bill-detail-pay')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-detail-undo')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bill-detail-pay')));
    await tester.pumpAndSettle();
    expect(find.byType(BillPaymentSheet), findsOneWidget);
  });

  testWidgets('đã trả: có Hoàn tác, không có Thanh toán', (tester) async {
    await hoaDon('k2', DateTime(2026, 8, 6), paid: true);
    await dungTrang(tester, 'k2');

    expect(find.byKey(const ValueKey('bill-detail-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-detail-pay')), findsNothing);
    expect(find.text('ĐÃ THANH TOÁN'), findsOneWidget);
  });

  testWidgets('trả xong thì trang nạp lại: trạng thái đổi, kỳ mới vào lịch sử',
      (tester) async {
    await hoaDon('k3', DateTime(2026, 9, 8));
    await dungTrang(tester, 'k3');

    await tester.tap(find.byKey(const ValueKey('bill-detail-pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ THANH TOÁN'), findsOneWidget,
        reason: 'Trang đọc CSDL một lần lúc mở; sau thao tác phải đọc lại.');
    expect(find.byKey(const ValueKey('bill-detail-undo')), findsOneWidget);
    // Kỳ kế tiếp vừa sinh ra nằm trong chuỗi → hai dòng lịch sử.
    expect(find.byKey(const ValueKey('bill-history-k3')), findsOneWidget);
    final kySau = await db.billDao.getGeneratedFrom('k3');
    expect(kySau, isNotNull);
    expect(find.byKey(ValueKey('bill-history-${kySau!.id}')), findsOneWidget);
  });

  testWidgets('không tìm thấy hoá đơn → thông báo, không văng', (tester) async {
    await dungTrang(tester, 'khong-co');
    expect(find.text('Không tìm thấy hoá đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
