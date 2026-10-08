/// `DemDangHoatDong` — số bản ghi ĐANG HOẠT ĐỘNG mỗi loại, đầu vào `dangCo`
/// của `conTaoDuoc` (spec Premium 6.7): ví chưa xoá và không lưu trữ; ngân sách
/// chưa xoá và chưa hết hạn (lặp thì không bao giờ hết hạn); mục tiêu chưa xoá
/// và chưa đạt. Lưu trữ một ví / hoàn thành một mục tiêu là nhả một chỗ.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/premium/data/dem_dang_hoat_dong.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 6, 10);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  DemDangHoatDong dem() => DemDangHoatDong(db: db, clock: () => now);

  // Xoá mềm của dự án là cột `deletedAt` (DAO lọc `deletedAt.isNull()`), không
  // phải cờ `isDeleted` — đặt cờ không thôi thì ví vẫn được đếm.
  Future<void> vi(String ten, {String? status, bool xoa = false}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: 'w_$ten',
        idaccount: 10,
        name: ten,
        updatedAt: now,
        status: status == null ? const Value.absent() : Value(status),
        deletedAt: xoa ? Value(now) : const Value.absent(),
      ));

  test('ví: đếm chưa xoá và KHÔNG lưu trữ; tài khoản khác không đếm', () async {
    await vi('A');
    await vi('B', status: 'inactive');
    await vi('C', xoa: true);
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w_k', idaccount: 99, name: 'K', updatedAt: now));
    expect(await dem().dem(LoaiTran.vi, 10), 1);
  });

  test('ngân sách: chưa xoá và chưa hết hạn; ngân sách lặp không bao giờ hết hạn',
      () async {
    // ⚠️ Ngân sách KHÔNG lặp hết hạn ở cuối kỳ đầu (`expiresAt = min(mocKy(0),
    // endDate)`) — tạo 01/09 không lặp thì tới 06/10 đã hết hạn thật, dù
    // endDate 31/12. Fixture "còn hạn" phải bắt đầu trong kỳ hiện tại.
    Future<void> ns(String id,
            {required DateTime startDate,
            DateTime? endDate,
            bool recurrence = false}) =>
        db.budgetDao.insert(BudgetEntity(
          id: id,
          idaccount: 10,
          amount: 1,
          startDate: startDate,
          endDate: endDate,
          recurrence: recurrence,
          updatedAt: now,
        ).toCompanion());
    await ns('lap', startDate: DateTime(2026, 9, 1), recurrence: true);
    await ns('con',
        startDate: DateTime(2026, 10, 1), endDate: DateTime(2026, 12, 31));
    await ns('het',
        startDate: DateTime(2026, 9, 1), endDate: DateTime(2026, 10, 1));
    expect(await dem().dem(LoaiTran.nganSach, 10), 2);
  });

  test('mục tiêu: chưa xoá và chưa đạt (cờ hoặc đủ tiền)', () async {
    Future<void> mt(String id, {double hienCo = 0, bool xong = false}) =>
        db.goalDao.insert(GoalEntity(
          id: id,
          idaccount: 10,
          name: id,
          targetAmount: 100,
          currentAmount: hienCo,
          targetDate: DateTime(2027, 1, 1),
          isCompleted: xong,
          updatedAt: now,
        ).toCompanion());
    await mt('dang');
    await mt('co', xong: true);
    await mt('du', hienCo: 100);
    expect(await dem().dem(LoaiTran.mucTieu, 10), 1);
  });

  test('hóa đơn: chưa xoá và chưa trả; đã trả / tài khoản khác không đếm', () async {
    await db.billDao.insert(BillsCompanion.insert(
      id: 'b_chua',
      idaccount: 10,
      name: 'Điện',
      amount: 100,
      dueDate: now,
      updatedAt: now,
    ));
    await db.billDao.insert(BillsCompanion.insert(
      id: 'b_da_tra',
      idaccount: 10,
      name: 'Nước',
      amount: 50,
      dueDate: now,
      isPaid: const Value(true),
      payStatus: const Value('Payed'),
      updatedAt: now,
    ));
    await db.billDao.insert(BillsCompanion.insert(
      id: 'b_khac',
      idaccount: 99,
      name: 'Internet',
      amount: 200,
      dueDate: now,
      updatedAt: now,
    ));
    expect(await dem().dem(LoaiTran.hoaDon, 10), 1);
  });

  test('danh mục riêng: chỉ đếm danh mục của user (isDefault = false)', () async {
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'cat_1',
      idaccount: 10,
      name: 'Mặc định ăn uống',
      classify: 'chi',
      isDefault: const Value(true),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'cat_2',
      idaccount: 10,
      name: 'Riêng: Nuôi mèo',
      classify: 'chi',
      isDefault: const Value(false),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'cat_3',
      idaccount: 99,
      name: 'Riêng tài khoản khác',
      classify: 'chi',
      isDefault: const Value(false),
      updatedAt: now,
    ));
    expect(await dem().dem(LoaiTran.danhMucRieng, 10), 1);
  });

  test('DemDangHoatDong là một NguonDemDangHoatDong (để router tiêm bản giả)',
      () {
    expect(dem(), isA<NguonDemDangHoatDong>());
  });
}
