/// Nguồn dữ liệu Tầng 2: thu nhập 3 tháng phải là `thuNhapCua` (không đếm tiền
/// đi vay), cờ Cố định đọc từ bảng danh mục, phản hồi cũ từ bảng v24.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/tai_phan_bo_nguon.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository giả: chỉ `suggestAmount` được dùng ở đây.
class _Repo implements BudgetRepository {
  final Map<String, double?> goiY;
  _Repo(this.goiY);

  @override
  Future<double?> suggestAmount(int idaccount, String categoryId,
          {DateTime? now}) async =>
      goiY[categoryId];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _cat(AppDatabase db, String id, String ten,
        {String classify = 'chi', bool coDinh = false}) =>
    db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          idaccount: 7,
          name: ten,
          classify: classify,
          aiCoDinh: Value(coDinh),
          updatedAt: DateTime(2026, 1, 1),
        ));

/// `transactions.wallet_id` có khoá ngoại tới `wallets` (PRAGMA foreign_keys ON
/// ở `beforeOpen`), nên phải có ví trước.
Future<void> _vi(AppDatabase db) => db.into(db.wallets).insert(
      WalletsCompanion.insert(
        id: 'w',
        idaccount: 7,
        name: 'Tiền mặt',
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

Future<void> _tx(AppDatabase db, String id, DateTime ngay, double soTien,
        {required String loai, String? cat}) =>
    db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          walletId: 'w',
          idaccount: 7,
          categoryId: Value(cat),
          amount: soTien,
          type: loai,
          date: ngay,
          updatedAt: ngay,
        ));

BudgetView _ns(String id, String cat) => BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: cat,
        amount: 1000000,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 21);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('coDinh = tập categoryId có cờ, bỏ hàng đã xoá mềm', () async {
    await _cat(db, 'nha', 'Tiền nhà', coDinh: true);
    await _cat(db, 'an', 'Ăn uống');
    await _cat(db, 'cu', 'Cũ', coDinh: true);
    await db.categoryDao.softDelete('cu');
    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);
    expect(d.coDinh, {'nha'});
  });

  // ⚠️ Nhóm ca thu nhập viết lại ngày 2026-09-21. Bản cũ mã hoá cửa sổ "ba
  // tháng lịch liền trước", và cửa sổ ấy RỖNG trên mọi dữ liệu thật (giao dịch
  // sớm nhất trong CSDL là 02/09/2026), nên `thuNhapMoiThang` luôn bằng 0 —
  // phép neo ngưỡng theo thu nhập vì thế chưa từng có hiệu lực.

  test('thu nhập suy từ cửa sổ cuộn; tiền ĐI VAY không tính', () async {
    await _vi(db);
    await _cat(db, 'luong', 'Lương', classify: 'thu');
    await _cat(db, 'divay', 'Đi vay', classify: 'vay_no');
    // Giao dịch sớm nhất 01/09 → cửa sổ 20 ngày tính tới 21/09.
    await _tx(db, 'moc', DateTime(2026, 9, 1), 10000000,
        loai: 'thu', cat: 'luong');
    await _tx(db, 'vay', DateTime(2026, 9, 10), 5000000,
        loai: 'thu', cat: 'divay');

    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);

    expect(d.thuNhapMoiThang, closeTo(15000000, 1),
        reason: '10.000.000 trong 20 ngày → 10tr / 20 × 30 = 15tr. Khoản đi '
            'vay 5.000.000 phải bị loại — bẫy A8 #8; tính cả nó sẽ ra 22,5tr');
  });

  test('không giao dịch → thu nhập 0, không lỗi', () async {
    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);
    expect(d.thuNhapMoiThang, 0);
  });

  test('tài khoản trẻ hơn 14 ngày → thu nhập 0, không phải số bịa', () async {
    await _vi(db);
    await _cat(db, 'luong', 'Lương', classify: 'thu');
    await _tx(db, 'moi', DateTime(2026, 9, 18), 10000000,
        loai: 'thu', cat: 'luong');

    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);

    expect(d.thuNhapMoiThang, 0,
        reason: 'ba ngày dữ liệu mà suy ra một mức tháng thì ra 100 triệu — '
            'và phép neo ngưỡng sẽ tin con số ấy');
  });

  test('thu nhập cũ hơn 90 ngày không được đếm, mẫu số kẹp ở 90', () async {
    await _vi(db);
    await _cat(db, 'luong', 'Lương', classify: 'thu');
    await _tx(db, 'xua', DateTime(2026, 1, 1), 90000000,
        loai: 'thu', cat: 'luong');
    await _tx(db, 'trong', DateTime(2026, 9, 5), 10000000,
        loai: 'thu', cat: 'luong');

    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);

    expect(d.thuNhapMoiThang, closeTo(3333333, 1),
        reason: 'chỉ 10tr nằm trong 90 ngày → 10tr / 90 × 30. Khoản 90tr của '
            'tháng 1 nằm ngoài cửa sổ, và mẫu số bị kẹp ở 90 chứ không kéo dài '
            'tới tận mốc ấy');
  });

  test(
      'mucThangTheoNganSach hỏi suggestAmount theo categoryId, khoá là budget.id',
      () async {
    final d =
        await TaiPhanBoNguonImpl(db: db, budgets: _Repo({'c-an': 2000000}))
            .nap(7, [_ns('b1', 'c-an'), _ns('b2', 'c-gt')], now);
    expect(d.mucThangTheoNganSach, {'b1': 2000000, 'b2': null});
  });

  test('phản hồi cũ đọc từ bảng v24', () async {
    await db.aiFeedbackDao.ghi(AiRebalancingFeedbacksCompanion.insert(
      id: 'f1',
      idaccount: 7,
      createdAt: DateTime(2026, 8, 3),
      deficitBudgetId: 'an',
      donorBudgetId: 'ms',
      donorCategoryId: 'c-ms',
      suggestedAmount: 300000,
      actualAmount: 300000,
      action: 'accepted',
      periodFrom: DateTime(2026, 8, 1),
      periodTo: DateTime(2026, 9, 1),
    ));
    final d = await TaiPhanBoNguonImpl(db: db, budgets: _Repo({}))
        .nap(7, const [], now);
    expect(d.phanHoi.single.donorBudgetId, 'ms');
    expect(d.phanHoi.single.action, 'accepted');
    expect(d.phanHoi.single.periodFrom, DateTime(2026, 8, 1));
  });
}
