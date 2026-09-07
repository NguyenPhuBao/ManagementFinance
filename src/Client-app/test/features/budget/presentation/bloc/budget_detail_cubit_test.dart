/// BudgetDetailCubit: gom mọi thứ trang chi tiết cần vào một state, và tự
/// cập nhật khi ngân sách hay giao dịch đổi.
///
/// Vì sao cần: trang chi tiết đọc bốn nguồn (ngân sách, nhịp chi, lịch sử kỳ,
/// giao dịch trong kỳ). Để giao diện tự ghép bốn Future là bốn trạng thái nửa
/// vời phải xử lý; gom ở đây thì trang chỉ có ba trạng thái.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_detail_cubit.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';

final _bayGio = DateTime(2026, 9, 15, 12);

class _FakeRepository implements BudgetRepository {
  final calls = <String>[];
  final controller = StreamController<List<BudgetView>>.broadcast();
  List<BudgetPeriodSummary> history = const [];
  List<TransactionEntity> transactions = const [];

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) {
    calls.add('watchBudgets($idaccount)');
    return controller.stream;
  }

  @override
  Future<List<BudgetPeriodSummary>> getPeriodHistory(
    String budgetId, {
    int count = 6,
    DateTime? now,
  }) async {
    calls.add('getPeriodHistory($budgetId)');
    return history;
  }

  @override
  Future<List<TransactionEntity>> getPeriodTransactions(
    String budgetId, {
    DateTime? now,
  }) async {
    calls.add('getPeriodTransactions($budgetId)');
    return transactions;
  }

  @override
  Future<TransactionLookup> lookupFor(int idaccount) async {
    calls.add('lookupFor($idaccount)');
    return TransactionLookup.empty;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} không dùng ở đây');
}

BudgetView _view(String id, {double spent = 1000000}) {
  return BudgetView(
    budget: BudgetEntity(
      id: id,
      idaccount: 7,
      categoryId: 'c1',
      amount: 3000000,
      spent: spent,
      startDate: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    ),
    categoryName: 'Ăn uống',
  );
}

void main() {
  late _FakeRepository repo;
  late BudgetDetailCubit cubit;

  setUp(() {
    repo = _FakeRepository();
    cubit = BudgetDetailCubit(repository: repo, clock: () => _bayGio);
  });

  tearDown(() async {
    await cubit.close();
    await repo.controller.close();
  });

  test('chưa đăng nhập thì báo lỗi và KHÔNG chạm repository', () async {
    cubit.watch(idaccount: null, budgetId: 'b1');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<BudgetDetailError>());
    expect(repo.calls, isEmpty,
        reason: 'Không được đoán tài khoản — xem G4 trong '
            'CLIENT_APP_KNOWN_GAPS.');
  });

  test('gom ngân sách, nhịp chi, lịch sử và giao dịch vào một state', () async {
    repo.history = [
      BudgetPeriodSummary(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 9, 1),
        amount: 3000000,
        spent: 2500000,
      ),
    ];
    repo.transactions = [
      TransactionEntity(
        id: 't1',
        walletId: 'w1',
        idaccount: 7,
        categoryId: 'c1',
        amount: 50000,
        type: 'chi',
        date: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
      ),
    ];

    final loaded = expectLater(
      cubit.stream,
      emitsThrough(isA<BudgetDetailLoaded>()),
    );
    cubit.watch(idaccount: 7, budgetId: 'b1');
    repo.controller.add([_view('khac'), _view('b1')]);
    await loaded;

    final state = cubit.state as BudgetDetailLoaded;
    expect(state.view.budget.id, 'b1');
    expect(state.pace.daysLeft, 16,
        reason: 'Nhịp chi tính theo đồng hồ tiêm vào, không theo giờ máy.');
    expect(state.pace.status, isA<BudgetPaceStatus>());
    expect(state.history.single.spent, 2500000);
    expect(state.transactions.single.id, 't1');
    expect(state.expired, isFalse);
  });

  test('ngân sách không còn trong danh sách thì báo lỗi', () async {
    final error = expectLater(
      cubit.stream,
      emitsThrough(isA<BudgetDetailError>()),
    );
    cubit.watch(idaccount: 7, budgetId: 'b1');
    repo.controller.add([_view('khac')]);
    await error;

    expect(repo.calls.where((c) => c.startsWith('getPeriodHistory')), isEmpty,
        reason: 'Đã biết ngân sách mất thì không đi tải thêm gì.');
  });

  test('giao dịch đổi thì state phát lại với số mới', () async {
    cubit.watch(idaccount: 7, budgetId: 'b1');
    repo.controller.add([_view('b1', spent: 100)]);
    await cubit.stream.firstWhere((s) => s is BudgetDetailLoaded);

    repo.controller.add([_view('b1', spent: 200)]);
    final next = await cubit.stream.firstWhere(
        (s) => s is BudgetDetailLoaded && s.view.budget.spent == 200);

    expect((next as BudgetDetailLoaded).view.budget.spent, 200,
        reason: 'Ghi một khoản chi ở nơi khác phải làm trang này nhúc nhích '
            'ngay, y như danh sách.');
  });
}
