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

  // ── Spec phân quyền client 2026-10-08 mục 4.2 — đóng lỗi 2 và 3 của mã backend viết sẵn ──

  Future<void> danhMuc(String id, String ten,
          {int idaccount = 10, bool macDinh = false, String classify = 'chi', bool xoa = false}) =>
      db.categoryDao.insert(CategoriesCompanion.insert(
        id: id,
        idaccount: idaccount,
        name: ten,
        classify: classify,
        isDefault: Value(macDinh),
        deletedAt: xoa ? Value(now) : const Value.absent(),
        updatedAt: now,
      ));

  test('⭐ 13 bản sao danh mục mặc định KHÔNG tính là danh mục riêng (lỗi 2)', () async {
    const ten = [
      'Ăn uống', 'Di chuyển', 'Giáo dục', 'Giải trí', 'Hóa đơn', 'Mua sắm', 'Nhà cửa',
      'Y tế', 'Lương', 'Thưởng', 'Đầu tư', 'Cho vay', 'Đi vay',
    ];
    for (var i = 0; i < ten.length; i++) {
      await danhMuc('khuon_$i', ten[i], idaccount: 0, macDinh: true);
      await danhMuc('sao_$i', ten[i]); // seeder: bản sao isDefault = false
    }
    await danhMuc('rieng_1', 'Nuôi mèo');
    await danhMuc('rieng_2', 'Cà phê sáng');
    expect(await dem().dem(LoaiTran.danhMucRieng, 10), 2,
        reason: 'Đếm cả 13 bản sao thì trần 5 chặn mọi tài khoản Basic tạo danh mục nào.');
  });

  test('danh mục cùng tên khuôn nhưng KHÁC phân loại là danh mục riêng; đã xoá mềm không tính',
      () async {
    await danhMuc('khuon', 'Ăn uống', idaccount: 0, macDinh: true);
    await danhMuc('thu_an_uong', 'Ăn uống', classify: 'thu');
    await danhMuc('da_xoa', 'Xe máy', xoa: true);
    expect(await dem().dem(LoaiTran.danhMucRieng, 10), 1);
  });

  Future<void> hoaDon(String id, {String pay = 'Pending', bool daTra = false, String? truoc}) =>
      db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: 10,
        name: 'HĐ $id',
        amount: 100,
        dueDate: now,
        isPaid: Value(daTra),
        payStatus: Value(pay),
        generatedFromBillId: truoc == null ? const Value.absent() : Value(truoc),
        updatedAt: now,
      ));

  test('⭐ kỳ Skipped (bỏ qua) KHÔNG tính là hoá đơn đang mở (lỗi 3)', () async {
    await hoaDon('bo_qua', pay: 'Skipped');
    await hoaDon('ky_sau', truoc: 'bo_qua');
    expect(await dem().dem(LoaiTran.hoaDon, 10), 1);
  });

  test('chuỗi hoá đơn lặp đã trả kỳ cũ, kỳ mới mở → 1', () async {
    await hoaDon('ky_1', pay: 'Payed', daTra: true);
    await hoaDon('ky_2', truoc: 'ky_1');
    await hoaDon('qua_han', pay: 'Overdue');
    expect(await dem().dem(LoaiTran.hoaDon, 10), 2,
        reason: 'quá hạn vẫn còn phải trả — vẫn chiếm chỗ');
  });

  test('DemDangHoatDong là một NguonDemDangHoatDong (để router tiêm bản giả)',
      () {
    expect(dem(), isA<NguonDemDangHoatDong>());
  });
}
