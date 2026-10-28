/// "Đã chi" của ngân sách đi qua `khoanVaoThongKe` — cùng luật với Trang chủ / Phân tích / Sổ giao dịch (người dùng chốt
/// 2026-10-19; báo cáo soát kiến trúc 2026-10-18 mục 6). Trước đó ngân sách TỔNG cộng cả khoản *Điều chỉnh số dư*, *Số dư
/// ban đầu* và nửa chi của cặp nạp mục tiêu kiểu cũ, nên nói đã chi nhiều hơn Trang chủ — im lặng.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart' show kGhiChuNapMucTieu;
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart' show tienToDieuChinh;
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart' show tienToMoSo;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idaccount = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const anUong = '22222222-2222-4222-8222-222222222222';
  final now = DateTime(2026, 6, 15, 12);
  final tu = DateTime(2026, 6, 1);
  final den = DateTime(2026, 7, 1);

  late AppDatabase db;
  late BudgetLocalDataSourceImpl ds;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = BudgetLocalDataSourceImpl(db: db);
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(walletId),
      idaccount: const Value(idaccount),
      name: const Value('Tiền mặt'),
      balance: const Value(0),
      updatedAt: Value(now),
    ));
    await db.categoryDao.insert(CategoriesCompanion(
      id: const Value(anUong),
      idaccount: const Value(idaccount),
      name: const Value('Ăn uống'),
      classify: const Value('chi'),
      updatedAt: Value(now),
    ));
  });

  tearDown(() => db.close());

  test('⭐ getExpenseCategories bỏ bản sao ẩn theo khuôn (spec 2026-10-27 mục 4)', () async {
    final moc = DateTime(2026, 10, 10);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'kx', name: 'Thử khuôn', idaccount: 0, classify: 'chi', isDefault: const Value(true),
        isDeleted: const Value(true), deletedAt: Value(DateTime.utc(2026, 10, 28)), updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'sx', name: 'Thử khuôn', idaccount: idaccount, classify: 'chi', updatedAt: moc));
    final ids = (await ds.getExpenseCategories(idaccount)).map((c) => c.id).toList();
    expect(ids, isNot(contains('sx')),
        reason: 'Form ngân sách và thẻ "Chưa đặt ngân sách" không được mời người dùng chọn danh mục admin đã ngừng.');
    expect(ids, contains(anUong), reason: 'Danh mục thường của tài khoản vẫn phải có mặt — kết quả rỗng không chứng minh gì.');
  });

  Future<void> ghiChi(String id, double amount, {String? categoryId, String note = ''}) =>
      db.transactionDao.insert(TransactionsCompanion(
        id: Value(id),
        idaccount: const Value(idaccount),
        walletId: const Value(walletId),
        categoryId: Value(categoryId),
        amount: Value(amount),
        type: const Value('chi'),
        note: Value(note),
        date: Value(now),
        updatedAt: Value(now),
      ));

  Future<void> ghiBonLoai() async {
    await ghiChi('pho', 100000, categoryId: anUong, note: 'Phở');
    await ghiChi('dieu-chinh', 50000, note: '$tienToDieuChinh: Tiền mặt');
    await ghiChi('mo-so', 20000, note: tienToMoSo);
    await ghiChi('nap-cu', 30000, note: '${kGhiChuNapMucTieu}MuaXe');
    await ghiChi('an-vat', 40000, note: 'Ăn vặt'); // không danh mục, ghi chú tự gõ → VẪN tính
  }

  test('ngân sách TỔNG: bỏ điều chỉnh số dư, số dư ban đầu, nửa chi cặp nạp mục tiêu kiểu cũ', () async {
    await ghiBonLoai();
    final rows = await ds.getExpenses(idaccount: idaccount, categoryId: null, from: tu, to: den);
    expect(rows.map((t) => t.id).toSet(), {'pho', 'an-vat'},
        reason: 'Ngân sách tổng phải nói đúng số "chi tháng này" của Trang chủ — cùng khoanVaoThongKe.');
    expect(await ds.sumExpenses(idaccount: idaccount, categoryId: null, from: tu, to: den), 140000);
  });

  test('ngân sách theo DANH MỤC không đổi (ba loại bị loại đều không có danh mục)', () async {
    await ghiBonLoai();
    expect(await ds.sumExpenses(idaccount: idaccount, categoryId: anUong, from: tu, to: den), 100000);
  });
}
