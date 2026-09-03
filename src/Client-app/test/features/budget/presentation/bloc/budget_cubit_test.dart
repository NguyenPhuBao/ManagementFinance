/// BudgetCubit: không được đoán tài khoản, và phải giữ đúng thứ tự state.
///
/// Trọng tâm là nhánh **chưa đăng nhập**. `idaccount = 1` là tài khoản admin
/// THẬT chứ không phải giá trị "chưa biết" — dự án đã từng ghi hoá đơn và
/// khoản tiết kiệm dưới danh nghĩa admin vì bốn trang tự chép một bản
/// `?? 1` (xem G4 trong `docs/CLIENT_APP_KNOWN_GAPS.md`). Cubit này phải báo
/// lỗi thay vì đọc/ghi bằng một mã đoán được.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_cubit.dart';

/// Repository giả — ghi lại lời gọi để khẳng định cubit KHÔNG chạm tới nó khi
/// chưa có phiên đăng nhập.
class _FakeRepository implements BudgetRepository {
  final List<String> calls = [];
  List<BudgetView> budgets = const [];
  Object? throwOnAdd;

  @override
  Future<List<BudgetView>> getBudgets(int idaccount, {DateTime? now}) async {
    calls.add('getBudgets($idaccount)');
    return budgets;
  }

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) {
    calls.add('watchBudgets($idaccount)');
    return Stream.value(budgets);
  }

  @override
  Future<BudgetView?> getBudgetById(String id, {DateTime? now}) async {
    calls.add('getBudgetById($id)');
    return budgets.where((v) => v.budget.id == id).firstOrNull;
  }

  @override
  Future<BudgetEntity> addBudget({
    required int idaccount,
    required double amount,
    String? categoryId,
    double? thresholdWarningAmount,
    double? thresholdWarningPercent,
    String overSpending = BudgetOverSpending.over,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
    String timeRecurrence = BudgetRecurrence.month,
    String note = '',
  }) async {
    calls.add('addBudget($idaccount)');
    final error = throwOnAdd;
    if (error != null) throw error;
    return BudgetEntity(
      id: 'x',
      idaccount: idaccount,
      amount: amount,
      startDate: startDate ?? DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> updateBudget(BudgetEntity budget) async {
    calls.add('updateBudget(${budget.id})');
  }

  @override
  Future<void> deleteBudget(String id) async {
    calls.add('deleteBudget($id)');
  }

  @override
  Future<List<Category>> getExpenseCategories(int idaccount) async {
    calls.add('getExpenseCategories($idaccount)');
    return const [];
  }
}

BudgetView _view({
  String id = 'b1',
  double amount = 1000000,
  double spent = 0,
}) {
  return BudgetView(
    budget: BudgetEntity(
      id: id,
      idaccount: 7,
      amount: amount,
      spent: spent,
      startDate: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    ),
  );
}

void main() {
  late _FakeRepository repo;
  late BudgetCubit cubit;

  setUp(() {
    repo = _FakeRepository();
    cubit = BudgetCubit(repository: repo);
  });

  tearDown(() => cubit.close());

  group('Chưa đăng nhập thì không đọc, không ghi', () {
    test('watchBudgets(null) báo lỗi và không gọi repository', () {
      cubit.watchBudgets(null);

      expect(cubit.state, isA<BudgetError>());
      expect(repo.calls, isEmpty,
          reason: 'Không được đọc dữ liệu bằng một mã tài khoản đoán ra.');
    });

    test('watchBudgets(0) cũng bị chặn', () {
      cubit.watchBudgets(0);
      expect(cubit.state, isA<BudgetError>());
      expect(repo.calls, isEmpty);
    });

    test('addBudget khi chưa đăng nhập không ghi gì', () async {
      await cubit.addBudget(idaccount: null, amount: 500000);

      expect(cubit.state, isA<BudgetError>());
      expect(repo.calls, isEmpty,
          reason: 'Ghi ngân sách dưới danh nghĩa idaccount = 1 là ghi vào tài '
              'khoản admin thật.');
    });

    test('loadEditor khi chưa đăng nhập không đọc danh mục', () async {
      await cubit.loadEditor(null);
      expect(cubit.state, isA<BudgetError>());
      expect(repo.calls, isEmpty);
    });
  });

  group('Cộng tổng', () {
    test('tổng hạn mức và tổng đã chi cộng từ mọi ngân sách', () async {
      repo.budgets = [
        _view(id: 'b1', amount: 1000000, spent: 300000),
        _view(id: 'b2', amount: 2000000, spent: 500000),
      ];

      await cubit.loadBudgets(7);

      final state = cubit.state as BudgetLoaded;
      expect(state.totalAmount, 3000000);
      expect(state.totalSpent, 800000);
      expect(state.totalRemaining, 2200000);
    });

    test('tiêu vượt: percentSpent cắt trần ở 1.0, totalRemaining vẫn âm',
        () async {
      repo.budgets = [_view(amount: 1000000, spent: 1500000)];

      await cubit.loadBudgets(7);

      final state = cubit.state as BudgetLoaded;
      expect(state.percentSpent, 1.0,
          reason: 'Thanh tiến trình tổng không được tràn ra ngoài khung.');
      expect(state.totalRemaining, -500000,
          reason: 'Nhưng số tiền thì phải nói thật là đã âm.');
    });

    test('chưa có ngân sách nào thì percentSpent là 0, không phải NaN',
        () async {
      await cubit.loadBudgets(7);

      final state = cubit.state as BudgetLoaded;
      expect(state.isEmpty, isTrue);
      expect(state.percentSpent, 0.0,
          reason: 'Chia 0 cho 0 ra NaN sẽ làm FractionallySizedBox ném lỗi.');
    });
  });

  group('Thông báo lỗi cho người dùng', () {
    test('ArgumentError chỉ hiện phần lời nhắn, không kèm tên tham số',
        () async {
      repo.throwOnAdd =
          ArgumentError.value(0, 'amount', 'Hạn mức phải lớn hơn 0');

      await cubit.addBudget(idaccount: 7, amount: 0);

      final state = cubit.state as BudgetError;
      expect(state.message, 'Hạn mức phải lớn hơn 0');
      expect(state.message, isNot(contains('amount')),
          reason: 'ArgumentError.toString() in ra cả tên tham số và giá trị — '
              'không phải thứ để đưa thẳng cho người dùng đọc.');
    });
  });

  group('Sau khi ghi', () {
    test('tạo xong phát BudgetSaved kèm lời nhắn', () async {
      await cubit.addBudget(idaccount: 7, amount: 500000);

      expect(cubit.state, isA<BudgetSaved>());
      expect((cubit.state as BudgetSaved).message, contains('Đã tạo'));
      expect(repo.calls, contains('addBudget(7)'));
    });

    test('xoá xong phát BudgetSaved', () async {
      await cubit.deleteBudget('b1');

      expect(cubit.state, isA<BudgetSaved>());
      expect(repo.calls, contains('deleteBudget(b1)'));
    });
  });

  group('Trang cấu hình', () {
    test('mở để tạo mới thì editing là null', () async {
      await cubit.loadEditor(7);

      final state = cubit.state as BudgetEditorReady;
      expect(state.isCreating, isTrue);
      expect(state.editing, isNull);
    });

    test('mở ngân sách đã bị xoá thì báo lỗi thay vì form trống', () async {
      await cubit.loadEditor(7, budgetId: 'khong-ton-tai');

      expect(cubit.state, isA<BudgetError>(),
          reason: 'Form trống sẽ dụ người dùng nhập lại rồi bấm Lưu, và thay '
              'đổi đó không gắn vào bản ghi nào.');
    });

    test('mở ngân sách có thật thì nạp đúng bản ghi', () async {
      repo.budgets = [_view(id: 'b1', amount: 750000)];

      await cubit.loadEditor(7, budgetId: 'b1');

      final state = cubit.state as BudgetEditorReady;
      expect(state.isCreating, isFalse);
      expect(state.editing!.amount, 750000);
    });
  });
}
