/// Repository của trang Phân tích trên CSDL Drift trong bộ nhớ.
///
/// Canh chừng điều gì: tầng thuần đã kiểm phép tính; tệp này kiểm phần **nối**
/// — hàng Drift có được đổi đúng sang khoản thuần không (kể cả `categoryId`
/// null và `'transfer'`), tên/biểu tượng danh mục có tra đúng không, "% ngân
/// sách" có bám đúng ngân sách đang chạy của danh mục không, và stream có phát
/// lại khi ghi thêm giao dịch không. Mọi thứ ở đây sai đều im lặng: trang vẫn
/// vẽ, chỉ là vẽ số khác.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository_impl.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository budgets;
  late AnalyticsRepository repo;

  /// Đồng hồ cố định: 08/09/2026 trưa. Tháng đang xem là tháng 9.
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
      icon: const Value('restaurant'),
      colour: const Value('#F25F5C'),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c_xe',
      idaccount: 1,
      name: 'Di chuyển',
      classify: 'chi',
      updatedAt: now,
    ));
  });

  tearDown(() => db.close());

  Future<void> giaoDich({
    required String id,
    required DateTime ngay,
    required double soTien,
    String loai = 'chi',
    String? danhMuc = 'c_an',
    int idaccount = 1,
  }) {
    return db.transactionDao.insert(TransactionsCompanion.insert(
      id: id,
      idaccount: idaccount,
      walletId: 'w1',
      categoryId: Value(danhMuc),
      amount: soTien,
      type: loai,
      date: ngay,
      updatedAt: now,
    ));
  }

  Future<ThongKeThang> lanDau({int nam = 2026, int thang = 9}) =>
      repo.watchThang(1, nam: nam, thang: thang, now: now).first;

  group('đổi hàng Drift sang thống kê', () {
    test('tổng thu/chi, tháng trước, và phần trăm so sánh', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 5000000, loai: 'thu', danhMuc: null);
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 300000);
      await giaoDich(id: 't3', ngay: DateTime(2026, 8, 20), soTien: 200000);
      await giaoDich(id: 't4', ngay: DateTime(2026, 8, 21), soTien: 4000000, loai: 'thu', danhMuc: null);

      final tk = await lanDau();

      expect(tk.nam, 2026);
      expect(tk.thang, 9);
      expect(tk.tong.thu, 5000000);
      expect(tk.tong.chi, 300000);
      expect(tk.tongTruoc.thu, 4000000);
      expect(tk.tongTruoc.chi, 200000);
      expect(tk.thuSoVoiTruoc, closeTo(25, 0.001));
      expect(tk.chiSoVoiTruoc, closeTo(50, 0.001));
    });

    test('transfer không vào thu lẫn chi, kể cả khi mang danh mục', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 900000, loai: 'transfer');
      final tk = await lanDau();
      expect(tk.tong.thu, 0);
      expect(tk.tong.chi, 0);
      expect(tk.danhMuc, isEmpty);
    });

    test('KHÔNG đọc giao dịch của tài khoản khác', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 999999, idaccount: 2);
      final tk = await lanDau();
      expect(tk.tong.chi, 0,
          reason: 'Cách ly theo idaccount là quy tắc 2 của CLAUDE.md. Trang '
              'thống kê lộ số của người khác là lỗi nặng nhất có thể có ở '
              'đây.');
    });

    test('tháng không có gì thì rỗng, không ném', () async {
      final tk = await lanDau(thang: 3);
      expect(tk.rong, isTrue);
      expect(tk.thuSoVoiTruoc, isNull);
    });
  });

  group('dòng danh mục', () {
    test('tra tên, biểu tượng, màu; sắp giảm dần', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 100000, danhMuc: 'c_an');
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 400000, danhMuc: 'c_xe');

      final tk = await lanDau();

      expect(tk.danhMuc.map((d) => d.ten), ['Di chuyển', 'Ăn uống']);
      expect(tk.danhMuc.last.icon, 'restaurant');
      expect(tk.danhMuc.last.mauHex, '#F25F5C');
      expect(tk.danhMuc.first.tiLeTongChi, closeTo(0.8, 1e-9));
    });

    test('danh mục ĐÃ XOÁ MỀM vẫn giữ tên thật', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_cu',
        idaccount: 1,
        name: 'Chi khác',
        classify: 'chi',
        deletedAt: Value(now),
        updatedAt: now,
      ));
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 100000, danhMuc: 'c_cu');

      final tk = await lanDau();

      expect(tk.danhMuc.single.ten, 'Chi khác',
          reason: 'Trên máy thật, 5 danh mục mặc định bị xoá mềm hôm '
              '2026-09-07 làm cả một lát donut mang tên "Danh mục đã xoá" '
              'trong khi tên thật còn nguyên trong hàng. `categoryDao.watchAll` '
              'lọc `deletedAt` nên repository phải tự truy vấn.');
    });

    test('khoản không danh mục thành "Chưa phân loại", danh mục lạ thành "Danh mục đã xoá"',
        () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 100000, danhMuc: null);
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 50000, danhMuc: 'khong_ton_tai');

      final tk = await lanDau();

      expect(tk.danhMuc.map((d) => d.ten), ['Chưa phân loại', 'Danh mục đã xoá'],
          reason: 'Hai ca khác nhau, hai chữ khác nhau. Gộp làm một là người '
              'dùng không biết mình cần phân loại hay đã lỡ xoá danh mục.');
      expect(tk.danhMuc.first.categoryId, isNull);
    });
  });

  group('phần trăm ngân sách', () {
    test('danh mục có ngân sách đang chạy → mang hạn mức và số đã chi', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        recurrence: true,
        timeRecurrence: 'Month',
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 320000, danhMuc: 'c_an');
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 10000, danhMuc: 'c_xe');

      final tk = await lanDau();

      final an = tk.danhMuc.firstWhere((d) => d.categoryId == 'c_an');
      expect(an.nganSachHanMuc, 1000000);
      expect(an.nganSachDaChi, 320000);
      expect(an.tiLeNganSach, closeTo(0.32, 1e-9));

      final xe = tk.danhMuc.firstWhere((d) => d.categoryId == 'c_xe');
      expect(xe.nganSachHanMuc, isNull,
          reason: 'Không bịa ngân sách cho danh mục chưa đặt. Giao diện đổi '
              'nhãn sang "% tổng chi" khi thấy null.');
    });

    test('ngân sách ĐÃ HẾT HẠN trước tháng đang xem thì không tính', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
        recurrence: false,
        timeRecurrence: null,
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 100000, danhMuc: 'c_an');

      final tk = await lanDau();

      expect(tk.danhMuc.single.nganSachHanMuc, isNull,
          reason: 'Một ngân sách chết từ tháng 6 mà vẫn ra "10% ngân sách" ở '
              'tháng 9 là so với một hạn mức không còn tồn tại.');
    });
  });

  group('stream', () {
    test('ghi thêm giao dịch thì phát lại số mới', () async {
      final ds = <ThongKeThang>[];
      final sub = repo.watchThang(1, nam: 2026, thang: 9, now: now).listen(ds.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 70000);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(ds.last.tong.chi, 70000,
          reason: 'Trang chủ nghe stream nên ghi một khoản là số nhúc nhích '
              'ngay; trang Phân tích đứng im tới khi mở lại là hai màn hình '
              'nói hai con số về cùng một tháng.');
    });
  });
}
