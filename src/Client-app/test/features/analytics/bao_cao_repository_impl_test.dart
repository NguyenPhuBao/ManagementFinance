/// Repository của trang Xuất báo cáo trên CSDL Drift trong bộ nhớ.
///
/// Canh chừng điều gì: tầng thuần (`bao_cao_xuat_test.dart`) đã kiểm phép lọc
/// và phép cộng; tệp này kiểm phần **nối** — hàng Drift có đổi đúng sang dòng
/// thuần không, tên ví và tên danh mục có tra đúng không **kể cả khi hàng ấy đã
/// xoá mềm**, và tiêu đề mỗi dòng lấy từ đâu. Sai ở đây không ném lỗi: tờ báo
/// cáo vẫn in ra, chỉ là in tên khác hoặc thiếu dòng.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/data/bao_cao_repository.dart';
import 'package:flowmoney/features/analytics/data/bao_cao_repository_impl.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository budgets;
  late BaoCaoRepository repo;

  final now = DateTime(2026, 9, 8, 12);
  final locThang9 =
      LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    budgets = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(db: db),
      clock: () => now,
    );
    repo = BaoCaoRepositoryImpl(
        db: db, budgetRepository: budgets, clock: () => now);

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
      icon: const Value('restaurant'),
      colour: const Value('#F25F5C'),
      updatedAt: now,
    ));
  });

  tearDown(() => db.close());

  Future<void> giaoDich({
    required String id,
    required DateTime ngay,
    double soTien = 100000,
    String loai = 'chi',
    String? danhMuc = 'c_an',
    String vi = 'w1',
    String ghiChu = '',
    int idaccount = 1,
  }) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: idaccount,
        categoryId: Value(danhMuc),
        amount: soTien,
        type: loai,
        note: Value(ghiChu),
        date: ngay,
        updatedAt: now,
      ));

  group('layBaoCao — đổi hàng Drift sang dòng thuần', () {
    test('tra đúng tên ví, tên danh mục, màu và biểu tượng', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), ghiChu: 'Ăn trưa');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      final d = bc.nhom.single.dong.single;

      expect(d.tenVi, 'Tiền mặt');
      expect(d.tenDanhMuc, 'Ăn uống');
      expect(d.mauHex, '#F25F5C');
      expect(d.icon, 'restaurant');
      expect(d.tieuDe, 'Ăn trưa');
    });

    test('không ghi chú thì tiêu đề lấy tên danh mục', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), ghiChu: '');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.nhom.single.dong.single.tieuDe, 'Ăn uống',
          reason: 'Ghi chú rỗng là mặc định của cột. Để trống thì dòng báo cáo '
              'chỉ còn số tiền, không biết là khoản gì.');
    });

    test('khoản chưa phân loại mang nhãn "Chưa phân loại"', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), danhMuc: null);

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.nhom.single.dong.single.tenDanhMuc, 'Chưa phân loại');
    });

    test('danh mục đã xoá mềm vẫn giữ TÊN THẬT', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5));
      await db.categoryDao.softDelete('c_an');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.nhom.single.dong.single.tenDanhMuc, 'Ăn uống',
          reason: 'Cùng luật với trang Phân tích: tên vẫn nằm trong hàng, và '
              '"Ăn uống" có ích hơn "Danh mục đã xoá". Lọc `deletedAt` khi tra '
              'tên là 5 danh mục mặc định bị xoá mềm hôm 2026-09-07 kéo theo '
              'cả một trang báo cáo mất tên.');
    });

    test('ví đã xoá mềm vẫn giữ TÊN THẬT', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5));
      await db.walletDao.softDelete('w1');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.nhom.single.dong.single.tenVi, 'Tiền mặt');
    });

    test('id danh mục không còn hàng nào thì nói thẳng là đã xoá', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), danhMuc: 'c_bay_gio');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.nhom.single.dong.single.tenDanhMuc, 'Danh mục đã xoá',
          reason: 'Ba ca phải ra ba chữ khác nhau: có danh mục / chưa phân '
              'loại / id trỏ vào hàng chưa từng đồng bộ về máy này.');
    });
  });

  group('layBaoCao — phạm vi dữ liệu', () {
    test('không lấy giao dịch của tài khoản khác', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), idaccount: 1);
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 6), idaccount: 2);

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.soGiaoDich, 1,
          reason: 'Quy tắc 2: `idaccount` chỉ đến từ phiên đăng nhập. Trộn hai '
              'tài khoản trong một tờ báo cáo là rò dữ liệu người khác.');
    });

    test('giao dịch đã xoá mềm không vào báo cáo', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5));
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 6));
      await db.transactionDao.softDelete('t2');

      final bc = await repo.layBaoCao(1, loc: locThang9);
      expect(bc.soGiaoDich, 1);
    });

    test('bộ lọc ví đi xuống tới tầng thuần', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ngân hàng',
        balance: const Value(0),
        updatedAt: now,
      ));
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), vi: 'w1');
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 6), vi: 'w2');

      final bc = await repo.layBaoCao(1,
          loc: LocBaoCao(
              from: locThang9.from, to: locThang9.to, walletId: 'w2'));
      expect(bc.soGiaoDich, 1);
      expect(bc.nhom.single.dong.single.tenVi, 'Ngân hàng');
    });
  });

  group('dòng tiền', () {
    test('số dư cuối kỳ suy từ TỔNG số dư ví hiện tại', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ngân hàng',
        balance: const Value(5000000.0),
        updatedAt: now,
      ));
      // w1 = 10.000.000 (setUp) + w2 = 5.000.000 → 15.000.000
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), soTien: 200000);
      await giaoDich(id: 't2', ngay: DateTime(2026, 10, 9), soTien: 500000);

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.dongTien!.cuoiKy, 15500000,
          reason: 'Số dư hiện tại đã trừ khoản chi 500k của tháng 10, nên số '
              'dư cuối tháng 9 phải cộng lại. Lấy thẳng số dư hiện tại là tờ '
              'báo cáo tháng 9 mang số của hôm nay.');
      expect(bc.dongTien!.dauKy, 15700000);
    });

    test('ví ĐÃ LƯU TRỮ không tính vào số dư hiện tại', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Thẻ cũ',
        balance: const Value(9000000.0),
        updatedAt: now,
      ));
      await db.walletDao.setStatus('w2', luuTru: true);

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.dongTien!.cuoiKy, 10000000,
          reason: 'Lưu trữ ví là đóng băng nó, và nửa quan trọng nhất của việc '
              'ấy là số dư thôi phình tổng tài sản. Báo cáo phải khớp với con '
              'số người dùng thấy ở trang chủ và màn Quản lý ví.');
    });

    test('ví tắt "Tính vào tổng tài sản" không tính vào số dư hiện tại',
        () async {
      // Lỗi có thật trước bản này: `getTotalBalance` lọc cờ ấy đúng, nhưng
      // trang chủ và báo cáo cộng `fold` trần trên mọi ví — nên cùng một app
      // hiện HAI con số khác nhau cho cùng một thứ, không màn nào nói ra.
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ví chung của nhóm',
        balance: const Value(9000000.0),
        includeInTotal: const Value(false),
        updatedAt: now,
      ));

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.dongTien!.cuoiKy, 10000000,
          reason: 'Người dùng đã cố ý loại ví này khỏi tổng tài sản. Cộng nó '
              'vào "số dư cuối kỳ" là tờ báo cáo nói ngược màn Quản lý ví.');
    });

    test('ví đã xoá mềm không tính vào số dư hiện tại', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ví cũ',
        balance: const Value(9000000.0),
        updatedAt: now,
      ));
      await db.walletDao.softDelete('w2');

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.dongTien!.cuoiKy, 10000000,
          reason: 'Số dư trên báo cáo phải khớp với số tiền người dùng thấy ở '
              'trang chủ; trang ấy cũng bỏ ví đã xoá.');
    });
  });

  group('ngân sách của kỳ', () {
    test('ngân sách đang chạy vào báo cáo kèm hạn mức và số đã chi', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        recurrence: true,
        timeRecurrence: 'Month',
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), soTien: 320000);

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.nganSach.single.ten, 'Ăn uống');
      expect(bc.nganSach.single.hanMuc, 1000000);
      expect(bc.nganSach.single.daChi, 320000);
      expect(bc.nganSach.single.vuot, isFalse);
    });

    test('ngân sách ĐÃ HẾT HẠN trước kỳ thì không lên báo cáo', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        recurrence: false,
        timeRecurrence: null,
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 5), soTien: 100000);

      final bc = await repo.layBaoCao(1, loc: locThang9);

      expect(bc.nganSach, isEmpty,
          reason: 'Một ngân sách chết từ tháng 6 mà vẫn hiện trên báo cáo '
              'tháng 9 là so với một hạn mức không còn tồn tại — cùng bẫy đã '
              'đóng ở trang Phân tích.');
    });
  });

  group('danh sách cho bộ lọc', () {
    test('ví: chỉ ví còn sống của đúng tài khoản', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ngân hàng',
        balance: const Value(0),
        updatedAt: now,
      ));
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w9',
        idaccount: 2,
        name: 'Ví người khác',
        balance: const Value(0),
        updatedAt: now,
      ));
      await db.walletDao.softDelete('w2');

      final ds = await repo.watchVi(1).first;
      expect(ds.map((v) => v.ten).toList(), ['Tiền mặt'],
          reason: 'Chip lọc là thứ người dùng chọn TỪ BÂY GIỜ — ví đã xoá '
              'không còn là lựa chọn, dù giao dịch cũ vẫn giữ tên nó.');
    });

    test('danh mục: chỉ danh mục còn sống của đúng tài khoản', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_xe',
        idaccount: 1,
        name: 'Di chuyển',
        classify: 'chi',
        updatedAt: now,
      ));
      await db.categoryDao.softDelete('c_xe');

      final ds = await repo.watchDanhMuc(1).first;
      expect(ds.map((c) => c.ten).toList(), ['Ăn uống']);
    });
  });
}
