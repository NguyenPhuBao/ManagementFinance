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
    // ⚠️ Nhóm này viết lại ngày 2026-09-21. Bản cũ mã hoá cửa sổ "ba tháng
    // dương lịch trước", và phép đo cho thấy cửa sổ ấy **rỗng trên mọi dữ liệu
    // thật**: giao dịch sớm nhất trong toàn bộ CSDL là 02/09/2026, nên hàm trả
    // `null` cho mọi danh mục, mọi tài khoản — gợi ý hạn mức trong form tạo
    // ngân sách chưa từng hiện một con số nào kể từ 2026-09-06.
    //
    // Cửa sổ nay cuộn theo ngày (`cuaSoNhinLai`), và mức tháng suy ra bằng
    // `tổng / số ngày × 30`.

    test('tài khoản trẻ hơn 14 ngày thì chưa gợi ý gì', () async {
      await ghiGiaoDich(
          id: 'moi', amount: 500000, date: DateTime(2026, 6, 10, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        isNull,
        reason: 'năm ngày dữ liệu không đủ để hứa một mức "mỗi tháng"',
      );
    });

    test('suy mức tháng từ cửa sổ thật', () async {
      await ghiGiaoDich(
          id: 'moc', amount: 100000, date: DateTime(2026, 5, 26, 12));
      await ghiGiaoDich(
          id: 'sau', amount: 100000, date: DateTime(2026, 6, 10, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        300000,
        reason: '200.000 trong cửa sổ 20 ngày → 200.000 / 20 × 30 = 300.000',
      );
    });

    test('làm tròn LÊN bội 10.000', () async {
      await ghiGiaoDich(
          id: 'moc', amount: 1000, date: DateTime(2026, 5, 26, 12));
      await ghiGiaoDich(
          id: 'sau', amount: 200000, date: DateTime(2026, 6, 10, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        310000,
        reason: '201.000 / 20 × 30 = 301.500 → 310.000. Làm tròn xuống thì gợi '
            'ý thấp hơn thực chi.',
      );
    });

    test('⚠️ mẫu số là tuổi TÀI KHOẢN, không phải tuổi danh mục', () async {
      // Tài khoản có dữ liệu từ 20 ngày trước, nhưng danh mục này mới phát
      // sinh HÔM QUA.
      await ghiGiaoDich(
          id: 'khac',
          amount: 50000,
          date: DateTime(2026, 5, 26, 12),
          categoryId: muaSam);
      await ghiGiaoDich(
          id: 'hom-qua', amount: 300000, date: DateTime(2026, 6, 14, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        450000,
        reason: '300.000 / 20 ngày × 30 = 450.000. Lấy tuổi của DANH MỤC làm '
            'mẫu số (1 ngày) sẽ ra 9.000.000 — phồng 20 lần, và con số ấy '
            'trông hoàn toàn hợp lý',
      );
    });

    test('cửa sổ kẹp ở 90 ngày: chi cũ hơn thế không được đếm', () async {
      await ghiGiaoDich(
          id: 'xua', amount: 9000000, date: DateTime(2026, 1, 1, 12));
      await ghiGiaoDich(
          id: 'trong', amount: 300000, date: DateTime(2026, 6, 10, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        100000,
        reason: 'chỉ 300.000 nằm trong 90 ngày → 300.000 / 90 × 30 = 100.000. '
            'Khoản 9 triệu của tháng 1 nằm ngoài cửa sổ, và mẫu số bị kẹp ở 90 '
            'chứ không kéo dài tới tận mốc ấy',
      );
    });

    test('⚠️ giao dịch ghi ngày TƯƠNG LAI không được đếm', () async {
      await ghiGiaoDich(
          id: 'moc', amount: 200000, date: DateTime(2026, 5, 26, 12));
      await ghiGiaoDich(
          id: 'mai-sau', amount: 9000000, date: DateTime(2026, 7, 1, 12));

      expect(
        await repo.suggestAmount(idaccount, anUong, now: now),
        300000,
        reason: 'CSDL thật có khoản trích mục tiêu ghi ngày tương lai. Cửa sổ '
            'hở đầu sau sẽ nuốt tiền CHƯA TIÊU vào một con số nói về quá khứ',
      );
    });

    test('danh mục không chi đồng nào thì null, không phải 0', () async {
      await ghiGiaoDich(
          id: 'moc', amount: 200000, date: DateTime(2026, 5, 26, 12));

      expect(
        await repo.suggestAmount(idaccount, muaSam, now: now),
        isNull,
        reason: '`null` là "không có gì để gợi ý"; một số 0 ở ô hạn mức là một '
            'gợi ý sai',
      );
    });
  });
}
