/// Trang Chi tiết ngân sách nối cổng `HoaDonDaXoaNguon` vào bảng chi tiết giao dịch — việc 4c (spec mục 3.4).
///
/// Vì sao cần: cùng lý do với `so_giao_dich_khoan_mo_coi_test.dart` — bảng nhận cờ qua tham số tuỳ chọn, mặc định
/// khoá; trang quên hỏi cổng thì khoản mồ côi khoá vĩnh viễn ở đường này, im lặng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:flowmoney/features/transaction/data/hoa_don_da_xoa_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';

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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cubit phát sẵn một trạng thái đã nạp — bỏ qua kho ngân sách.
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
    spent: 120000,
    startDate: DateTime(2026, 4, 1),
    recurrence: true,
    note: '',
    updatedAt: DateTime(2026, 9, 1),
  );
  final view = BudgetView(budget: budget, categoryName: 'Internet');

  final khoanMoCoi = TransactionEntity(
    id: 't-mo-coi',
    walletId: 'w1',
    idaccount: 7,
    categoryId: 'c1',
    billId: 'b-da-xoa',
    amount: 120000,
    type: 'chi',
    note: '${kGhiChuTraHoaDon}Internet',
    date: DateTime(2026, 9, 10),
    updatedAt: now,
  );

  final loaded = BudgetDetailLoaded(
    view: view,
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
    transactions: [khoanMoCoi],
    lookup: TransactionLookup.empty,
    expired: false,
  );

  setUp(() {
    sl.registerFactory<BudgetDetailCubit>(() => _CubitCoSan(loaded));
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _TxRepoGia()),
    );
  });

  tearDown(() async => sl.reset());

  Future<void> moTrangVaChamKhoan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: auth,
        child: const BudgetDetailPage(budgetId: 'b1'),
      ),
    ));
    await tester.pumpAndSettle();

    final dong = find.byKey(const ValueKey('budget-tx-t-mo-coi'));
    await tester.scrollUntilVisible(dong, 300,
        scrollable: find.byType(Scrollable).first);
    // `scrollUntilVisible` dừng khi dòng mới ló mép khung — xem budget_detail_view_test.dart.
    await tester.ensureVisible(dong);
    await tester.pumpAndSettle();
    await tester.tap(dong);
    await tester.pumpAndSettle();
  }

  testWidgets('khoản mồ côi: bảng có Xoá, hộp xác nhận mang câu cảnh báo',
      (tester) async {
    sl.registerSingleton<HoaDonDaXoaNguon>(HoaDonDaXoaNguon((_) async => true));
    await moTrangVaChamKhoan(tester);

    expect(find.text('Xoá giao dịch'), findsOneWidget,
        reason: 'Trang phải hỏi cổng TRƯỚC khi mở và truyền kết quả vào bảng.');
    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hoá đơn của khoản này đã xoá'), findsOneWidget,
        reason: 'Khoản mồ côi mở khoá nhưng phải kèm câu cảnh báo trong hộp xác nhận.');
    expect(find.textContaining('Số dư ví sẽ được hoàn lại'), findsOneWidget,
        reason: 'Câu chung vẫn đứng sau câu cảnh báo.');

    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();
  });

  testWidgets('cổng chưa đăng ký: khoản có billId vẫn KHOÁ', (tester) async {
    await moTrangVaChamKhoan(tester);

    expect(find.text('Xoá giao dịch'), findsNothing,
        reason: 'Không có cổng thì khoản có billId vẫn khoá: không có nút Xoá.');
    expect(find.textContaining('không xoá được từ sổ giao dịch'), findsOneWidget,
        reason: 'Đòi câu lý do khoá, không chỉ vắng nút Xoá.');
  });
}
