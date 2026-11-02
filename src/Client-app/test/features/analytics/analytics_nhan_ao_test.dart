/// Nhãn ảo Góp / Rút quỹ gia đình ở thống kê cá nhân và thu nhập không gồm tiền rút (`02A` mục 7.2, Task 10 đợt 1B).
///
/// Hai ngã đừng nhầm: mã ảo (`categoryIdThongKe`) chỉ để GOM NHÃN; cờ `KhoanThuChi.laRutQuy` mới quyết thu nhập. Sai thì
/// im lặng: Trang Phân tích vẫn vẽ, chỉ là thu nhập phồng lên đúng bằng số tiền rút về.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/data/repositories/analytics_repository.dart';
import 'package:flowmoney/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:flowmoney/features/analytics/domain/dong_tien_tu_do.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:flowmoney/features/transaction/domain/danh_muc_ao_quy.dart';

void main() {
  final ky = Ky.thang(2026, 9);
  final ngay = DateTime(2026, 9, 5);

  KhoanThuChi khoan(
    double soTien, {
    String loai = 'thu',
    String? categoryId,
    String? classify,
    String? ten,
    bool laRutQuy = false,
  }) =>
      KhoanThuChi(
        ngay: ngay,
        soTien: soTien,
        loai: loai,
        categoryId: categoryId,
        classify: classify,
        tenDanhMuc: ten,
        laRutQuy: laRutQuy,
      );

  group('thu nhập không gồm tiền rút quỹ', () {
    test('thu nhập trừ nửa rút, tổng thu vẫn gồm', () {
      final ds = [khoan(1000000), khoan(500000, categoryId: kDanhMucAoRutQuy, laRutQuy: true)];
      final vn = chuoiVayNo(ds, ky: ky, soKy: 1).single;
      final tong = tongThuChi(ds, from: ky.from, to: ky.to);
      expect(tong.thu, 1500000, reason: 'tổng thu gồm tiền rút về, 02A mục 7.2');
      expect(thuNhapCua(tong: tong, vayNo: vn), 1000000, reason: 'tiền quay về không phải tiền kiếm được');
    });

    test('nửa rút đã gắn danh mục thật vẫn không vào thu nhập', () {
      final ds = [
        khoan(1000000),
        khoan(500000, categoryId: 'c_luong', classify: 'thu', ten: 'Lương', laRutQuy: true),
      ];
      final vn = chuoiVayNo(ds, ky: ky, soKy: 1).single;
      final tong = tongThuChi(ds, from: ky.from, to: ky.to);
      expect(vn.rutQuy, 500000);
      expect(thuNhapCua(tong: tong, vayNo: vn), 1000000,
          reason: 'cờ laRutQuy quyết, không phải mã ảo: có danh mục thật vẫn là tiền quay về');
    });

    test('nửa rút gắn danh mục vay nợ chỉ trừ thu nhập MỘT lần', () {
      final ds = [
        khoan(1000000),
        khoan(500000, categoryId: 'c_vay', classify: 'vay_no', ten: 'Đi vay', laRutQuy: true),
      ];
      final vn = chuoiVayNo(ds, ky: ky, soKy: 1).single;
      final tong = tongThuChi(ds, from: ky.from, to: ky.to);
      expect(vn.rutQuy, 500000);
      expect(vn.diVay, 0, reason: 'không `continue` sau khi cộng rutQuy là trừ hai lần ở thuNhapCua');
      expect(thuNhapCua(tong: tong, vayNo: vn), 1000000);
    });

    test('rút không làm biểu đồ vay nợ hiện lên', () {
      final vn = chuoiVayNo([khoan(500000, categoryId: kDanhMucAoRutQuy, laRutQuy: true)], ky: ky, soKy: 1).single;
      expect(vn.rutQuy, 500000);
      expect(vn.rong, isTrue, reason: 'rutQuy không tính vào rong');
    });

    test('khoản thu thường không có cờ không bị trừ', () {
      final ds = [khoan(700000, categoryId: kDanhMucAoRutQuy)];
      final vn = chuoiVayNo(ds, ky: ky, soKy: 1).single;
      expect(vn.rutQuy, 0, reason: 'mã ảo không quyết thu nhập; chỉ cờ');
    });
  });

  group('trên CSDL', () {
    late AppDatabase db;
    late BudgetRepository budgets;
    late AnalyticsRepository repo;
    final now = DateTime(2026, 9, 8, 12);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      budgets = BudgetRepositoryImpl(
        localDataSource: BudgetLocalDataSourceImpl(db: db),
        clock: () => now,
      );
      repo = AnalyticsRepositoryImpl(db: db, budgetRepository: budgets);
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Tiền mặt',
        balance: const Value(10000000.0),
        updatedAt: now,
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_an',
        idaccount: 1,
        name: 'Ăn uống',
        classify: 'chi',
        updatedAt: now,
      ));
    });

    tearDown(() => db.close());

    Future<void> giaoDich(
      String id,
      double soTien, {
      String loai = 'chi',
      String? danhMuc,
      String? cap,
    }) =>
        db.transactionDao.insert(TransactionsCompanion.insert(
          id: id,
          idaccount: 1,
          walletId: 'w1',
          categoryId: Value(danhMuc),
          amount: soTien,
          type: loai,
          date: DateTime(2026, 9, 3),
          updatedAt: now,
          fundPairId: Value(cap),
        ));

    test('chi theo danh mục có lát Góp quỹ gia đình, không phải Chưa phân loại', () async {
      await giaoDich('g', 300000, cap: 'p1');
      final tk = await repo.watchKy(1, ky: ky, now: now).first;
      expect(tk.danhMuc.map((d) => d.ten), [kTenGopQuyGiaDinh]);
      expect(tk.danhMuc.single.categoryId, kDanhMucAoGopQuy);
      expect(tk.danhMuc.single.mauHex, isNotNull);
      expect(tk.topChi.single.tenDanhMuc, kTenGopQuyGiaDinh,
          reason: 'báo cáo / danh sách dùng cùng nhãn ảo, không "Danh mục đã xoá"');
    });

    test('lát Thu có Rút quỹ gia đình và thu nhập loại nó ra', () async {
      await giaoDich('l', 1000000, loai: 'thu');
      await giaoDich('r', 400000, loai: 'thu', cap: 'p2');
      final tk = await repo.watchKy(1, ky: ky, now: now).first;
      final thu = tk.danhMucTheoLat['thu']!;
      expect(thu.map((d) => d.ten), contains(kTenRutQuyGiaDinh));
      expect(tk.tong.thu, 1400000);
      expect(thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last), 1000000,
          reason: 'đường đầy đủ qua repository: dungKhoan phải gắn laRutQuy');
    });

    test('nửa góp có danh mục thật giữ danh mục', () async {
      await giaoDich('g', 300000, danhMuc: 'c_an', cap: 'p1');
      final tk = await repo.watchKy(1, ky: ky, now: now).first;
      expect(tk.danhMuc.single.categoryId, 'c_an');
      expect(tk.danhMuc.single.ten, 'Ăn uống');
    });

    test('thẻ tổng không đổi: nửa góp vẫn tính chi', () async {
      await giaoDich('g', 300000, cap: 'p1');
      final tk = await repo.watchKy(1, ky: ky, now: now).first;
      expect(tk.tong.chi, 300000);
    });

    test('ngân sách theo danh mục không tính: mã ảo không khớp ngân sách nào', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        recurrence: true,
        timeRecurrence: 'Month',
      );
      await giaoDich('g', 300000, cap: 'p1');
      final tk = await repo.watchKy(1, ky: ky, now: now).first;
      final gop = tk.danhMuc.firstWhere((d) => d.categoryId == kDanhMucAoGopQuy);
      expect(gop.nganSachHanMuc, isNull);
    });
  });

  test('DiemVayNo mặc định rutQuy 0', () {
    expect(DiemVayNo(ky: ky).rutQuy, 0);
  });
}
