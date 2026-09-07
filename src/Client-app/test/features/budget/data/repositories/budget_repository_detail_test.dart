/// Dữ liệu cho trang chi tiết ngân sách và cho hai chỗ "ngân sách chạm vào
/// nơi khác": form thêm giao dịch (mục ngân sách đang chạy) và form ngân sách
/// (gợi ý hạn mức).
///
/// Vì sao cần: các phép tính này đều là "cộng những giao dịch nằm trong một
/// khoảng ngày". Lệch biên một ngày là sai âm thầm — không exception, chỉ là
/// con số hơi khác — nên biên kỳ được kiểm bằng giao dịch đặt **đúng** mốc.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';

void main() {
  const idaccount = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const anUong = '22222222-2222-4222-8222-222222222222';
  const muaSam = '33333333-3333-4333-8333-333333333333';

  final now = DateTime(2026, 6, 15, 12);

  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(db: db),
      syncEngine: null,
      clock: () => now,
    );

    await db.walletDao.insert(WalletsCompanion(
      id: const Value(walletId),
      idaccount: const Value(idaccount),
      name: const Value('Tiền mặt'),
      balance: const Value(10000000),
      updatedAt: Value(now),
    ));
    for (final (id, name) in [(anUong, 'Ăn uống'), (muaSam, 'Mua sắm')]) {
      await db.categoryDao.insert(CategoriesCompanion(
        id: Value(id),
        idaccount: const Value(idaccount),
        name: Value(name),
        classify: const Value('chi'),
        updatedAt: Value(now),
      ));
    }
  });

  tearDown(() => db.close());

  Future<void> ghiGiaoDich({
    required String id,
    required double amount,
    required DateTime date,
    String type = 'chi',
    String? categoryId = anUong,
  }) {
    return db.transactionDao.insert(TransactionsCompanion(
      id: Value(id),
      idaccount: const Value(idaccount),
      walletId: const Value(walletId),
      categoryId: Value(categoryId),
      amount: Value(amount),
      type: Value(type),
      date: Value(date),
      updatedAt: Value(now),
    ));
  }

  Future<BudgetEntity> taoNganSach({
    String categoryId = anUong,
    double amount = 5000000,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
  }) {
    return repo.addBudget(
      idaccount: idaccount,
      amount: amount,
      categoryId: categoryId,
      startDate: startDate ?? DateTime(2026, 3, 1),
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: BudgetRecurrence.month,
    );
  }

  group('getPeriodHistory', () {
    test('mỗi kỳ mang số đã chi của riêng kỳ ấy, cũ trước mới sau', () async {
      final b = await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 100000, date: DateTime(2026, 4, 10));
      await ghiGiaoDich(id: 't2', amount: 250000, date: DateTime(2026, 5, 20));
      await ghiGiaoDich(id: 't3', amount: 50000, date: DateTime(2026, 6, 2));
      // Danh mục khác không được lẫn vào.
      await ghiGiaoDich(
          id: 't4', amount: 999999, date: DateTime(2026, 5, 5), categoryId: muaSam);

      final ky = await repo.getPeriodHistory(b.id, count: 6, now: now);

      expect(ky.map((k) => k.from.month).toList(), [3, 4, 5, 6]);
      expect(ky.map((k) => k.spent).toList(), [0, 100000, 250000, 50000]);
      expect(ky.every((k) => k.amount == 5000000), isTrue,
          reason: 'Không có nơi lưu hạn mức cũ — lịch sử dùng hạn mức hiện tại. '
              'Giới hạn có chủ ý, ghi ở PROJECT_CONTEXT.');
    });

    test('giao dịch đúng 00:00 ngày đầu kỳ sau chỉ thuộc kỳ sau', () async {
      final b = await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 100000, date: DateTime(2026, 6, 1));

      final ky = await repo.getPeriodHistory(b.id, count: 6, now: now);
      final thangNam = ky.firstWhere((k) => k.from.month == 5);
      final thangSau = ky.firstWhere((k) => k.from.month == 6);

      expect(thangNam.spent, 0,
          reason: 'Bộ chọn ngày trả về 00:00, nên khoản ghi ngày 1/6 nằm đúng '
              'mốc `to` của tháng 5. Biên `to` là biên MỞ; đếm vào cả hai kỳ '
              'là một khoản chi bị tính hai lần.');
      expect(thangSau.spent, 100000);
    });

    test('ngân sách không tồn tại thì trả rỗng', () async {
      expect(await repo.getPeriodHistory('khong-co', count: 6, now: now),
          isEmpty);
    });
  });

  group('getPeriodTransactions', () {
    test('chỉ khoản chi của danh mục trong kỳ hiện tại, mới nhất trước',
        () async {
      final b = await taoNganSach();
      await ghiGiaoDich(id: 'cu', amount: 10, date: DateTime(2026, 5, 30));
      await ghiGiaoDich(id: 'a', amount: 20, date: DateTime(2026, 6, 3));
      await ghiGiaoDich(id: 'b', amount: 30, date: DateTime(2026, 6, 10));
      await ghiGiaoDich(
          id: 'thu', amount: 40, date: DateTime(2026, 6, 5), type: 'thu');
      await ghiGiaoDich(
          id: 'khac', amount: 50, date: DateTime(2026, 6, 5), categoryId: muaSam);

      final rows = await repo.getPeriodTransactions(b.id, now: now);

      expect(rows.map((t) => t.id).toList(), ['b', 'a']);
    });
  });

  group('activeBudgetForCategory', () {
    test('trả ngân sách đang chạy của danh mục, kèm số đã chi', () async {
      await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 120000, date: DateTime(2026, 6, 3));

      final view = await repo.activeBudgetForCategory(idaccount, anUong, now: now);

      expect(view, isNotNull);
      expect(view!.budget.spent, 120000);
      expect(view.categoryName, 'Ăn uống');
    });

    test('danh mục không có ngân sách thì null', () async {
      await taoNganSach();
      expect(await repo.activeBudgetForCategory(idaccount, muaSam, now: now),
          isNull);
    });

    test('ngân sách đã hết hạn không tính', () async {
      await taoNganSach(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 2, 1),
      );
      expect(await repo.activeBudgetForCategory(idaccount, anUong, now: now),
          isNull,
          reason: 'Cảnh báo theo một ngân sách đã chết là nhiễu.');
    });
  });

  group('suggestAmount', () {
    test('trung bình chi của 3 tháng dương lịch trước, bỏ tháng này', () async {
      await ghiGiaoDich(id: 'feb', amount: 5000000, date: DateTime(2026, 2, 20));
      await ghiGiaoDich(id: 'mar', amount: 1200000, date: DateTime(2026, 3, 10));
      await ghiGiaoDich(id: 'apr', amount: 900000, date: DateTime(2026, 4, 10));
      await ghiGiaoDich(id: 'may', amount: 1500000, date: DateTime(2026, 5, 10));
      await ghiGiaoDich(id: 'jun', amount: 300000, date: DateTime(2026, 6, 10));

      final goiY = await repo.suggestAmount(idaccount, anUong, now: now);

      expect(goiY, 1200000,
          reason: '(1,2 + 0,9 + 1,5) / 3 = 1,2 triệu. Tháng 2 nằm ngoài cửa sổ; '
              'tháng 6 chưa hết nên không đại diện.');
    });

    test('làm tròn LÊN bội 10.000', () async {
      await ghiGiaoDich(id: 'mar', amount: 1000001, date: DateTime(2026, 3, 10));

      final goiY = await repo.suggestAmount(idaccount, anUong, now: now);

      expect(goiY, 340000,
          reason: '1.000.001 / 3 = 333.333,67 → 340.000. Làm tròn xuống thì '
              'gợi ý thấp hơn thực chi.');
    });

    test('không có khoản chi nào trong 3 tháng thì null', () async {
      await ghiGiaoDich(id: 'jun', amount: 300000, date: DateTime(2026, 6, 10));
      expect(await repo.suggestAmount(idaccount, anUong, now: now), isNull);
    });
  });
}
