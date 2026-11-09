/// Trang Chi tiết ngân sách nối cổng `CapGopQuyNguon` vào bảng chi tiết giao dịch — đợt 1B Task 9.
///
/// Vì sao cần: cùng lý do với `so_giao_dich_nua_rieng_test.dart` — trang quên hỏi cổng thì nửa riêng của khoản góp vẫn
/// sửa, xoá một mình ở đường này, im lặng (quỹ một số, ví riêng một số khác).
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_detail_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_detail_page.dart';
import 'package:flowmoney/features/transaction/data/cap_gop_quy_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';

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

class _BudgetRepoGia implements BudgetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TxRepoGia implements TransactionRepository {
  var soLanXoaMotNua = 0;

  @override
  Future<void> deleteTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    soLanXoaMotNua++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CubitCoSan extends BudgetDetailCubit {
  _CubitCoSan(this._s) : super(repository: _BudgetRepoGia());

  final BudgetDetailState _s;

  @override
  void watch({required int? idaccount, required String budgetId}) => emit(_s);
}

void main() {
  final now = DateTime(2026, 9, 15, 12);
  final budget = BudgetEntity(
    id: 'b1',
    idaccount: 7,
    categoryId: 'c1',
    amount: 3000000,
    spent: 200000,
    startDate: DateTime(2026, 4, 1),
    recurrence: true,
    note: '',
    updatedAt: DateTime(2026, 9, 1),
  );
  final nuaRieng = TransactionEntity(
    id: 't-nua-rieng',
    walletId: 'w1',
    idaccount: 7,
    fundPairId: 'cap-1',
    amount: 200000,
    type: 'chi',
    note: 'Góp quỹ · Quỹ chợ',
    date: DateTime(2026, 9, 10),
    updatedAt: now,
  );
  final loaded = BudgetDetailLoaded(
    view: BudgetView(budget: budget, categoryName: 'Tổng'),
    pace: budgetPaceOf(budget, now),
    history: [
      for (var m = 4; m <= 9; m++)
        BudgetPeriodSummary(
          from: DateTime(2026, m, 1),
          to: DateTime(2026, m + 1, 1),
          amount: 3000000,
          spent: 1000000,
        ),
    ],
    transactions: [nuaRieng],
    lookup: TransactionLookup.empty,
    expired: false,
  );

  late _TxRepoGia txRepo;
  late BatThongBao bat;

  setUp(() {
    bat = batThongBao();
    txRepo = _TxRepoGia();
    sl.registerFactory<BudgetDetailCubit>(() => _CubitCoSan(loaded));
    sl.registerFactory<TransactionBloc>(() => TransactionBloc(transactionRepository: txRepo));
  });

  tearDown(() async => sl.reset());

  Future<void> moTrangVaChamKhoan(WidgetTester tester, {CapGopQuyNguon? nguon}) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (nguon != null) sl.registerSingleton<CapGopQuyNguon>(nguon);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(value: auth, child: const BudgetDetailPage(budgetId: 'b1')),
      ),
      GoRoute(
        path: '/nha/gop',
        builder: (_, s) => Scaffold(body: Text('GOP ma=${s.uri.queryParameters['ma']} che=${s.uri.queryParameters['che']}')),
      ),
      GoRoute(path: '/add', builder: (_, __) => const Scaffold(body: Text('FORM-ADD'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final dong = find.byKey(const ValueKey('budget-tx-t-nua-rieng'));
    await tester.scrollUntilVisible(dong, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(dong);
    await tester.pumpAndSettle();
    await tester.tap(dong);
    await tester.pumpAndSettle();
  }

  CapGopQuyNguon nguonCo({bool choThaoTac = true, List<String>? daXoa}) => CapGopQuyNguon(
        doc: (_) async => CapGopQuy(maCap: 'cap-1', laGop: true, cauXoa: 'Quỹ chợ cũng giảm 200.000 đ.', choThaoTac: choThaoTac),
        xoa: (m) async => daXoa?.add(m),
      );

  testWidgets('Sửa nửa riêng còn cặp: /nha/gop?ma=cap-1&che=gop, không /add', (tester) async {
    await moTrangVaChamKhoan(tester, nguon: nguonCo());
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('GOP ma=cap-1 che=gop'), findsOneWidget, reason: 'Sửa một nửa ở form thường làm hai nửa lệch nhau.');
    expect(find.text('FORM-ADD'), findsNothing);
  });

  testWidgets('Xoá nửa riêng còn cặp: câu của cặp, xoaCap, không xoá một nửa', (tester) async {
    final daXoa = <String>[];
    await moTrangVaChamKhoan(tester, nguon: nguonCo(daXoa: daXoa));
    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá khoản góp?'), findsOneWidget);
    expect(find.text('Quỹ chợ cũng giảm 200.000 đ.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(daXoa, ['cap-1']);
    expect(txRepo.soLanXoaMotNua, 0, reason: 'DeleteTransactionEvent gỡ một nửa → lệch cặp.');
    expect(bat.cau, ['Đã xóa giao dịch']);
  });

  testWidgets('nhà chỉ xem: bảng không có Sửa, Xoá', (tester) async {
    await moTrangVaChamKhoan(tester, nguon: nguonCo(choThaoTac: false));
    expect(find.text('Sửa giao dịch'), findsNothing);
    expect(find.text('Xoá giao dịch'), findsNothing);
  });

  testWidgets('chưa đăng ký cổng: đường cũ, Sửa đi /add', (tester) async {
    await moTrangVaChamKhoan(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('FORM-ADD'), findsOneWidget);
  });

  testWidgets('đã rời nhà (cổng trả null): Sửa đi /add', (tester) async {
    await moTrangVaChamKhoan(tester, nguon: CapGopQuyNguon(doc: (_) async => null, xoa: (_) async {}));
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('FORM-ADD'), findsOneWidget);
  });
}
