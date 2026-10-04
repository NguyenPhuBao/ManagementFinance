/// Đọc nhịp chi từ CSDL (dự án C việc hai, spec mục 4.1–4.2 và 7.2): đúng định
/// nghĩa "đã chi" của thẻ ngân sách, lùi cả về trước ngày tạo, đọc MỘT lần.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Đếm số lượt đọc khoản chi — canh "đọc MỘT lần cho mọi ngân sách".
class _DemDoc implements BudgetLocalDataSource {
  _DemDoc(this.goc);
  final BudgetLocalDataSource goc;
  var soLanDocChi = 0;

  @override
  Future<List<Transaction>> getExpenses({
    required int idaccount,
    required String? categoryId,
    required DateTime from,
    required DateTime to,
  }) {
    soLanDocChi++;
    return goc.getExpenses(
        idaccount: idaccount, categoryId: categoryId, from: from, to: to);
  }

  @override
  Future<DateTime?> mocGiaoDichDauTien(int idaccount) =>
      goc.mocGiaoDichDauTien(idaccount);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  const idaccount = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const nhaO = '22222222-2222-4222-8222-222222222222';
  const anUong = '33333333-3333-4333-8333-333333333333';
  final now = DateTime(2026, 11, 6, 12);

  late AppDatabase db;
  late _DemDoc dem;
  late BudgetRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dem = _DemDoc(BudgetLocalDataSourceImpl(db: db));
    repo = BudgetRepositoryImpl(
        localDataSource: dem, syncEngine: null, clock: () => now);
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(walletId),
      idaccount: const Value(idaccount),
      name: const Value('Tiền mặt'),
      balance: const Value(10000000),
      updatedAt: Value(now),
    ));
    for (final (id, ten) in [(nhaO, 'Nhà ở'), (anUong, 'Ăn uống')]) {
      await db.categoryDao.insert(CategoriesCompanion(
        id: Value(id),
        idaccount: const Value(idaccount),
        name: Value(ten),
        classify: const Value('chi'),
        updatedAt: Value(now),
      ));
    }
  });
  tearDown(() => db.close());

  var dem0 = 0;
  Future<void> ghi(DateTime ngay, double tien,
          {String? cat = nhaO, String loai = 'chi'}) =>
      db.transactionDao.insert(TransactionsCompanion(
        id: Value('t${dem0++}'),
        idaccount: const Value(idaccount),
        walletId: const Value(walletId),
        categoryId: Value(cat),
        amount: Value(tien),
        type: Value(loai),
        date: Value(ngay),
        updatedAt: Value(now),
      ));

  /// Ba kỳ 8–10/2026 mẫu Nhà ở (4.000.000 ngày 1 + 200.000 ngày 10, 20, 28).
  Future<void> baKyNhaO() async {
    for (final t in [8, 9, 10]) {
      await ghi(DateTime(2026, t, 1), 4000000);
      for (final n in [10, 20, 28]) {
        await ghi(DateTime(2026, t, n), 200000);
      }
    }
  }

  BudgetEntity nganSach(String? cat, {DateTime? start}) => BudgetEntity(
        id: 'b-${cat ?? 'tong'}',
        idaccount: idaccount,
        categoryId: cat,
        amount: 5000000,
        startDate: start ?? DateTime(2026, 10, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: now,
      );

  test('⭐ học cả kỳ TRƯỚC ngày tạo ngân sách (tạo 01/10, học 8–10)', () async {
    await baKyNhaO();
    final n = (await repo
        .nhipChiTheoNganSach(idaccount, [nganSach(nhaO)], now: now))['b-$nhaO']!;
    expect(n.soKy, 3);
    expect(n.tongTheoKy, [4600000, 4600000, 4600000]);
    final x = viTriTrongKy(DateTime(2026, 11, 1), DateTime(2026, 12, 1), now);
    expect(n.conChiMoiKhi(x), closeTo(600000, 1e-6));
  });

  test('chỉ khoản CHI đúng danh mục — khoản thu và danh mục khác không vào',
      () async {
    await baKyNhaO();
    await ghi(DateTime(2026, 8, 15), 9000000, loai: 'thu');
    await ghi(DateTime(2026, 8, 15), 1000000, cat: anUong);
    final n = (await repo
        .nhipChiTheoNganSach(idaccount, [nganSach(nhaO)], now: now))['b-$nhaO']!;
    expect(n.tongTheoKy, [4600000, 4600000, 4600000]);
  });

  test('ngân sách TỔNG (categoryId null) gom mọi danh mục chi', () async {
    await baKyNhaO();
    await ghi(DateTime(2026, 8, 15), 1000000, cat: anUong);
    final n = (await repo
        .nhipChiTheoNganSach(idaccount, [nganSach(null)], now: now))['b-tong']!;
    expect(n.tongTheoKy, [5600000, 4600000, 4600000]);
  });

  test('khoản đúng 00:00 ngày đầu kỳ sau thuộc kỳ sau (biên to mở)', () async {
    await baKyNhaO();
    await ghi(DateTime(2026, 9, 1), 50000); // thuộc kỳ 9, không thuộc kỳ 8
    final n = (await repo
        .nhipChiTheoNganSach(idaccount, [nganSach(nhaO)], now: now))['b-$nhaO']!;
    expect(n.tongTheoKy, [4600000, 4650000, 4600000]);
  });

  test('kỳ bắt đầu trước giao dịch đầu tiên bị bỏ → chỉ còn 2 kỳ → null',
      () async {
    for (final t in [8, 9, 10]) {
      await ghi(DateTime(2026, t, 2), 4000000); // giao dịch đầu tiên 02/08
    }
    final kq =
        await repo.nhipChiTheoNganSach(idaccount, [nganSach(nhaO)], now: now);
    expect(kq.containsKey('b-$nhaO'), isTrue);
    expect(kq['b-$nhaO'], isNull);
  });

  test('chưa có giao dịch nào → mọi ngân sách null, không lỗi', () async {
    final kq = await repo.nhipChiTheoNganSach(
        idaccount, [nganSach(nhaO), nganSach(anUong)], now: now);
    expect(kq, {'b-$nhaO': null, 'b-$anUong': null});
  });

  test('⭐ đọc khoản chi MỘT lần cho mọi ngân sách', () async {
    await baKyNhaO();
    await repo.nhipChiTheoNganSach(
        idaccount, [nganSach(nhaO), nganSach(anUong), nganSach(null)],
        now: now);
    expect(dem.soLanDocChi, 1);
  });

  test('danh sách rỗng → {} và không đọc gì', () async {
    expect(await repo.nhipChiTheoNganSach(idaccount, const [], now: now),
        isEmpty);
    expect(dem.soLanDocChi, 0);
  });
}
