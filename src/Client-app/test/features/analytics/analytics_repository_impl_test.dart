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
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
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
    String vi = 'w1',
  }) {
    return db.transactionDao.insert(TransactionsCompanion.insert(
      id: id,
      idaccount: idaccount,
      walletId: vi,
      categoryId: Value(danhMuc),
      amount: soTien,
      type: loai,
      date: ngay,
      updatedAt: now,
    ));
  }

  Future<ThongKeKy> lanDau({int nam = 2026, int thang = 9}) =>
      repo.watchKy(1, ky: Ky.thang(nam, thang), now: now).first;

  /// Cùng đường với [lanDau] nhưng cho **kỳ bất kỳ** — dùng cho các ca đơn vị
  /// khác tháng, nơi luật ngân sách đổi (mục 7 spec P1).
  Future<ThongKeKy> lanDauKy(Ky ky) => repo.watchKy(1, ky: ky, now: now).first;

  group('đổi hàng Drift sang thống kê', () {
    test('tổng thu/chi, tháng trước, và phần trăm so sánh', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 5000000, loai: 'thu', danhMuc: null);
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 300000);
      await giaoDich(id: 't3', ngay: DateTime(2026, 8, 20), soTien: 200000);
      await giaoDich(id: 't4', ngay: DateTime(2026, 8, 21), soTien: 4000000, loai: 'thu', danhMuc: null);

      final tk = await lanDau();

      expect(tk.ky, Ky.thang(2026, 9));
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

    // ⚠️ Luật thêm 2026-09-15 (P1, mục 7 spec). `BudgetView.spent` đếm theo kỳ
    // của CHÍNH ngân sách ấy, không theo kỳ đang xem. Xem một tuần mà thanh vẽ
    // mức chi cả tháng là đặt hai kỳ khác nhau lên cùng một tỉ lệ — sai IM
    // LẶNG, con số trông rất hợp lý.
    test('kỳ TUẦN thì không gắn ngân sách vào dòng nào', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        recurrence: true,
        timeRecurrence: 'Month',
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 15), soTien: 320000, danhMuc: 'c_an');

      final tk = await lanDauKy(Ky.tuan(DateTime(2026, 9, 17)));

      expect(tk.danhMuc, isNotEmpty, reason: 'tuần này có khoản chi thật');
      expect(
        tk.danhMuc.every((d) => d.nganSachHanMuc == null),
        isTrue,
        reason: 'hạn mức tháng cạnh số liệu một tuần là so hai kỳ khác nhau; '
            'dòng phải rơi về nhãn "% tổng chi"',
      );
    });

    test('kỳ NĂM cũng không gắn ngân sách', () async {
      await budgets.addBudget(
        idaccount: 1,
        categoryId: 'c_an',
        amount: 1000000,
        startDate: DateTime(2026, 1, 1),
        endDate: null,
        recurrence: true,
        timeRecurrence: 'Month',
      );
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 320000, danhMuc: 'c_an');

      final tk = await lanDauKy(Ky.nam(2026));

      expect(tk.danhMuc.every((d) => d.nganSachHanMuc == null), isTrue);
    });

    test('kỳ THÁNG vẫn gắn ngân sách như cũ — luật chỉ siết đơn vị khác', () async {
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

      final tk = await lanDauKy(Ky.thang(2026, 9));

      expect(tk.danhMuc.single.nganSachHanMuc, 1000000);
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

  group('chuỗi xu hướng', () {
    test('sáu điểm, cũ nhất trước, mang số thật của cả tháng ở xa', () async {
      await giaoDich(id: 't_xa', ngay: DateTime(2026, 4, 10), soTien: 800000);
      await giaoDich(id: 't_nay', ngay: DateTime(2026, 9, 3), soTien: 300000);

      final tk = await lanDau();

      expect(tk.chuoi.length, 6);
      expect(tk.chuoi.first.ky, Ky.thang(2026, 4));
      expect(tk.chuoi.last.ky, Ky.thang(2026, 9));
      expect(tk.chuoi.first.tong.chi, 800000,
          reason: 'Chuỗi nhìn xa hơn hai tháng mà `tong`/`tongTruoc` cần. Lọc '
              '`txs` theo tháng đang xem trước khi dựng chuỗi là điểm đầu '
              'rỗng trong khi dữ liệu vẫn nằm nguyên trong CSDL — biểu đồ '
              'phẳng lì mà không lỗi nào báo.');
      expect(tk.chuoi.last.tong.chi, 300000);
    });

    test('KHÔNG lấy giao dịch của tài khoản khác vào chuỗi', () async {
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 5, 5), soTien: 999999, idaccount: 2);
      final tk = await lanDau();
      expect(tk.chuoi.every((d) => d.tong.chi == 0 && d.tong.thu == 0), isTrue,
          reason: 'Cách ly theo idaccount phải đúng ở MỌI đường ra số, không '
              'riêng thẻ tổng. Biểu đồ là chỗ dễ quên nhất vì nó đọc lại cùng '
              'danh sách giao dịch.');
    });
  });

  group('stream', () {
    test('ghi thêm giao dịch thì phát lại số mới', () async {
      final ds = <ThongKeKy>[];
      final sub = repo.watchKy(1, ky: Ky.thang(2026, 9), now: now).listen(ds.add);
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

  group('phân loại dòng tiền', () {
    /// Danh mục vay/nợ, mặc định **đã xoá mềm** — đó là ca đáng canh: giao
    /// dịch cũ vẫn trỏ vào nó, và repository cố ý đọc cả hàng đã xoá mềm.
    Future<void> danhMucVayNo({bool daXoa = true}) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: 'c_no',
          idaccount: 1,
          name: 'Trả nợ',
          classify: 'vay_no',
          isDeleted: Value(daXoa),
          deletedAt: daXoa ? Value(DateTime(2026, 9, 1)) : const Value.absent(),
          updatedAt: now,
        ));

    test('classify lấy từ danh mục, kể cả danh mục đã xoá mềm', () async {
      await danhMucVayNo();
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 9, 15), soTien: 1000, danhMuc: 'c_no');

      final tk = await lanDau();

      expect(tk.latPhanLoai.single.phanLoai, 'vay_no',
          reason: 'Giao dịch cũ trỏ vào danh mục đã xoá vẫn phải giữ đúng '
              'phân loại — cùng lý do repository đọc cả hàng đã xoá mềm để '
              'giữ TÊN. Rơi về "chi" là vòng tròn nói sai tỷ trọng.');
    });

    test('lát chi KHÔNG gộp khoản chi gắn danh mục vay/nợ', () async {
      await danhMucVayNo();
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(
          id: 't2', ngay: DateTime(2026, 9, 3), soTien: 100000, danhMuc: 'c_no');

      final tk = await lanDau();

      expect(tk.tong.chi, 400000, reason: 'Thẻ đầu trang vẫn tính theo type');
      expect(tk.latPhanLoai.firstWhere((l) => l.phanLoai == 'chi').soTien,
          300000,
          reason: 'Lát Chi cố ý khác Tổng chi — §2.1 spec');
      expect(tk.latPhanLoai.firstWhere((l) => l.phanLoai == 'vay_no').soTien,
          100000);
    });

    test('danhMucCua trả danh mục của đúng lát, đã tra tên và biểu tượng',
        () async {
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(
          id: 't2',
          ngay: DateTime(2026, 9, 3),
          soTien: 900000,
          loai: 'thu',
          danhMuc: null);

      final tk = await lanDau();

      expect(tk.danhMucCua('chi').single.ten, 'Ăn uống');
      expect(tk.danhMucCua('chi').single.icon, 'restaurant');
      expect(tk.danhMucCua('thu').single.ten, 'Chưa phân loại');
      expect(tk.danhMucCua('vay_no'), isEmpty);
    });

    test('ngân sách chỉ gắn vào lát chi', () async {
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(
          id: 't2',
          ngay: DateTime(2026, 9, 3),
          soTien: 900000,
          loai: 'thu',
          danhMuc: null);

      final tk = await lanDau();

      expect(tk.danhMucCua('thu').single.coNganSach, isFalse,
          reason: 'BudgetRepository không có khái niệm ngân sách thu — gắn vào '
              'lát thu là hiện một hạn mức không tồn tại');
    });

    test('chuoiDanhMuc có khoá cho mỗi danh mục phát sinh trong 6 tháng',
        () async {
      await giaoDich(
          id: 't1', ngay: DateTime(2026, 7, 10), soTien: 100000, danhMuc: 'c_an');
      await giaoDich(
          id: 't2', ngay: DateTime(2026, 9, 10), soTien: 300000, danhMuc: 'c_an');

      final tk = await lanDau();

      expect(tk.chuoiDanhMuc.keys, contains('c_an'));
      expect(tk.chuoiDanhMuc['c_an']!.length, 6);
      expect(tk.chuoiDanhMuc['c_an']!.last.tong.chi, 300000);
      expect(tk.chuoiDanhMuc.keys, isNot(contains('c_xe')),
          reason: 'Danh mục không phát sinh thì không có chip xu hướng');
    });
  });

  // ── Bốn khối mượn từ trang Báo cáo (P2, 2026-09-15) ──────────────────────
  //
  // Trang Phân tích vốn nghèo hơn trang Báo cáo một cách vô lý: cùng dữ liệu,
  // cùng tầng domain, mà không có số liệu nhanh, phân bổ theo ví, top 5 hay
  // dòng tiền. Bốn phép tính nay là hàm thuần dùng chung ở `bao_cao_xuat.dart`
  // — bộ ca này canh việc repository **nối đúng** vào chúng.
  group('bốn khối mượn từ trang Báo cáo', () {
    test('số liệu nhanh: chi mỗi ngày chia cho số ngày CỦA KỲ', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 10), soTien: 600000, danhMuc: 'c_an');

      final tk = await lanDau();

      expect(tk.soLieu.chiMoiNgay, 900000 / 30,
          reason: 'tháng 9 có 30 ngày, không phải 2 ngày có giao dịch');
      expect(tk.soLieu.ngayChiNhieuNhat, DateTime(2026, 9, 10));
      expect(tk.soLieu.chiNgayNhieuNhat, 600000);
      expect(tk.soLieu.khoanChiLonNhat?.id, 't2');
    });

    test('phân bổ theo ví mang tên ví, giảm dần theo chi', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w2',
        idaccount: 1,
        name: 'Ngân hàng',
        balance: const Value(5000000.0),
        updatedAt: now,
      ));
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(id: 't2', ngay: DateTime(2026, 9, 3), soTien: 900000, danhMuc: 'c_an', vi: 'w2');

      final tk = await lanDau();

      expect(tk.theoVi.length, 2);
      expect(tk.theoVi.first.ten, 'Ngân hàng', reason: 'ví chi nhiều đứng trước');
      expect(tk.theoVi.first.chi, 900000);
      expect(tk.theoVi.last.ten, 'Tiền mặt');
      expect(tk.theoVi.last.soGiaoDich, 1);
    });

    test('top khoản chi cắt 5 và sắp giảm dần', () async {
      for (var i = 1; i <= 7; i++) {
        await giaoDich(
            id: 't$i', ngay: DateTime(2026, 9, i), soTien: 100000.0 * i, danhMuc: 'c_an');
      }

      final tk = await lanDau();

      expect(tk.topChi.length, 5);
      expect(tk.topChi.first.soTien, 700000);
      expect(tk.topChi.first.tenDanhMuc, 'Ăn uống',
          reason: 'tên danh mục phải được tra sẵn ở repository');
    });

    test('dòng tiền suy ngược từ tổng số dư ví', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');
      await giaoDich(id: 't2', ngay: DateTime(2026, 10, 5), soTien: 200000, danhMuc: 'c_an');

      final tk = await lanDau();

      // Ví w1 có 10.000.000. Sau kỳ có một khoản chi 200.000, nên cuối kỳ
      // phải là 10.200.000; trong kỳ chi 300.000 nên đầu kỳ là 10.500.000.
      expect(tk.dongTien!.cuoiKy, 10200000);
      expect(tk.dongTien!.dauKy, 10500000);
      expect(tk.dongTien!.thayDoi, -300000);
    });

    test('ví KHÔNG tính vào tổng thì không vào số dư cuối kỳ', () async {
      // Cùng luật với trang chủ và trang Báo cáo: `viTinhVaoTong`.
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w_ngoai',
        idaccount: 1,
        name: 'Ví không tính',
        balance: const Value(7000000.0),
        includeInTotal: const Value(false),
        updatedAt: now,
      ));

      final tk = await lanDau();

      expect(tk.dongTien!.cuoiKy, 10000000,
          reason: 'ví người dùng đã loại khỏi tổng không được phình con số');
    });
  });

  // ── Hai biểu đồ vay/nợ — A8 #4 và #5 (2026-09-15) ────────────────────────
  group('chuỗi vay/nợ', () {
    setUp(() async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_chovay',
        idaccount: 1,
        name: 'Cho vay',
        classify: 'vay_no',
        updatedAt: now,
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_thuno',
        idaccount: 1,
        name: 'Thu nợ',
        classify: 'vay_no',
        updatedAt: now,
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'c_tuydat',
        idaccount: 1,
        name: 'Nợ Bảo',
        classify: 'vay_no',
        updatedAt: now,
      ));
    });

    test('repository tra TÊN danh mục để đọc vai', () async {
      await giaoDich(id: 'v1', ngay: DateTime(2026, 9, 2), soTien: 500000, danhMuc: 'c_chovay');
      await giaoDich(id: 'v2', ngay: DateTime(2026, 9, 3), soTien: 200000, loai: 'thu', danhMuc: 'c_thuno');

      final tk = await lanDau();

      expect(tk.chuoiVayNo.length, 6);
      expect(tk.chuoiVayNo.last.choVay, 500000,
          reason: 'vai đọc từ tên, mà tên chỉ repository mới tra được');
      expect(tk.chuoiVayNo.last.thuNo, 200000);
    });

    test('danh mục tự đặt tên rơi vào "khác", tách theo chiều tiền', () async {
      await giaoDich(id: 'v1', ngay: DateTime(2026, 9, 2), soTien: 111000, danhMuc: 'c_tuydat');

      final tk = await lanDau();

      expect(tk.chuoiVayNo.last.khacRa, 111000);
      expect(tk.chuoiVayNo.last.choVay, 0);
    });

    test('khoản chi thường không lọt vào chuỗi vay/nợ', () async {
      await giaoDich(id: 't1', ngay: DateTime(2026, 9, 2), soTien: 300000, danhMuc: 'c_an');

      final tk = await lanDau();

      expect(tk.chuoiVayNo.every((d) => d.rong), isTrue);
    });
  });
}
