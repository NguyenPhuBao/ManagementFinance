/// `GopQuyService` — ghi / sửa / xoá một cặp góp, rút của gia đình (gia đình 1A, Task 8; `docs/Family/02A` mục 5–6).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/home/domain/thu_chi_thang.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/domain/ghi_chu_gop_quy.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/transaction/domain/khoan_vao_thong_ke.dart';
import 'package:flowmoney/features/transaction/domain/transaction_filter.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

import '../../transaction/data/repositories/transaction_repository_test.dart' show DummySyncEngine;

void main() {
  late AppDatabase db;
  late GopQuyService s;
  late DummySyncEngine sync;
  var soLanHen = 0;
  final ngay = DateTime(2026, 11, 1, 9);
  final moc = DateTime(2026, 10, 1);

  Future<void> themVi(String id, String ten, {required double soDu, int? nha}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: 10,
        name: ten,
        balance: Value(soDu),
        idhousehold: Value(nha),
        updatedAt: moc,
      ));

  setUp(() async {
    soLanHen = 0;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = DummySyncEngine();
    final soDuVi = SoDuViService(db: db, taiKhoanPhien: () => 10);
    s = GopQuyService(
      giaoDich: TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSourceImpl(db),
        syncEngine: sync,
        soDuVi: soDuVi,
      ),
      db: db,
      soDuVi: soDuVi,
      henDongBo: () => soLanHen++,
    );
    await themVi('vr', 'Ví MB', soDu: 5000000);
    await themVi('vn', 'Tiền chợ', soDu: 1000000, nha: 7);
  });
  tearDown(() => db.close());

  Future<double> soDu(String id) async => (await db.walletDao.getById(id))!.balance;

  Future<List<Transaction>> cacNuaCap() async =>
      [for (final h in await db.select(db.transactions).get()) if (h.fundPairId != null) h];

  test('góp từ ví riêng: hai nửa, chung mã cặp, đúng phạm vi và chiều tiền', () async {
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    final cap = await s.docCap(p);
    expect(cap.rieng!.idhousehold, isNull);
    expect(cap.rieng!.type, 'chi');
    expect(cap.rieng!.walletId, 'vr');
    expect(cap.rieng!.note, 'Góp quỹ · Tiền chợ');
    expect(cap.nha!.idhousehold, 7);
    expect(cap.nha!.type, 'thu');
    expect(cap.nha!.walletId, 'vn');
    expect(cap.rieng!.idaccount, 10);
    expect(cap.nha!.idaccount, 10);
    expect(cap.rieng!.fundPairId, p, reason: 'hai nửa chung một mã cặp');
    expect(cap.nha!.fundPairId, p);
    expect(cap.rieng!.syncStatus, 'pending');
    expect(cap.nha!.syncStatus, 'pending');
    expect(cap.nha!.date, ngay);
    expect(cap.rieng!.date, ngay);
  });

  test('ghi chú người dùng nối sau tiền tố ở nửa riêng, nửa nhà giữ nguyên chữ người dùng', () async {
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 1000, viRiengId: 'vr', ngay: ngay, ghiChu: 'tháng 11');
    final cap = await s.docCap(p);
    expect(cap.rieng!.note, 'Góp quỹ · Tiền chợ · tháng 11');
    expect(cap.nha!.note, 'tháng 11');
  });

  test('số dư hai ví đổi đúng', () async {
    await s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    expect(await soDu('vr'), 3000000, reason: 'ví riêng bị trừ');
    expect(await soDu('vn'), 3000000, reason: 'ví chung được cộng');
    expect(soLanHen + (sync.syncScheduled ? 1 : 0), greaterThan(0), reason: 'phải xin đồng bộ');
  });

  test('tiền mặt trao tay: chỉ nửa của nhà, vẫn mang mã cặp', () async {
    final p = await s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1000, ngay: ngay);
    final cap = await s.docCap(p);
    expect(cap.rieng, isNull);
    expect(cap.nha!.fundPairId, p);
    expect(await soDu('vr'), 5000000, reason: 'không ví riêng nào bị đụng');
    expect(await soDu('vn'), 1001000);
  });

  test('rút: nửa nhà chi, nửa riêng thu, ghi chú Rút quỹ', () async {
    final p = await s.rut(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 400000, viRiengId: 'vr', ngay: ngay);
    final cap = await s.docCap(p);
    expect(cap.nha!.type, 'chi');
    expect(cap.nha!.idhousehold, 7);
    expect(cap.nha!.walletId, 'vn');
    expect(cap.rieng!.type, 'thu');
    expect(cap.rieng!.idhousehold, isNull);
    expect(cap.rieng!.walletId, 'vr');
    expect(cap.rieng!.note, 'Rút quỹ · Tiền chợ');
    expect(await soDu('vn'), 600000);
    expect(await soDu('vr'), 5400000);
  });

  test('lỗi giữa chừng không để lại nửa nào và số dư không đổi', () async {
    // Ví riêng không tồn tại: khoá ngoại ném ở nửa thứ hai, SAU khi nửa của nhà đã chèn.
    await expectLater(
        s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1, viRiengId: 'khong-co', ngay: ngay),
        throwsA(anything));
    expect(await cacNuaCap(), isEmpty, reason: 'hai nửa phải cùng một giao tác — không được sót nửa của nhà');
    expect(await soDu('vn'), 1000000);
    expect(await soDu('vr'), 5000000);
  });

  test('sửa đổi cả hai nửa, pending, updatedAt mới, số dư tính lại', () async {
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    final truoc = await s.docCap(p);
    // Drift lưu giờ theo giây: hạ mốc cũ xuống tháng trước thay vì chờ mili giây.
    for (final h in [truoc.rieng!, truoc.nha!]) {
      await db.transactionDao.updateRow(h.id, TransactionsCompanion(updatedAt: Value(moc), syncStatus: const Value('synced')));
    }
    final truocRieng = (await s.docCap(p)).rieng!;
    final truocNha = (await s.docCap(p)).nha!;

    final ngayMoi = DateTime(2026, 11, 3);
    await s.sua(maCap: p, soTien: 500000, ngay: ngayMoi, ghiChu: 'đợt hai');
    final sau = await s.docCap(p);
    for (final h in [sau.rieng!, sau.nha!]) {
      expect(h.amount, 500000);
      expect(h.date, ngayMoi);
      expect(h.syncStatus, 'pending', reason: 'sửa xong phải chờ đẩy lại');
      expect(h.fundPairId, p, reason: 'sửa không được làm mất mã cặp');
    }
    expect(sau.nha!.idhousehold, 7, reason: 'sửa không được biến khoản của nhà thành khoản riêng');
    expect(sau.rieng!.idhousehold, isNull);
    expect(sau.nha!.note, 'đợt hai');
    expect(sau.rieng!.note, 'Góp quỹ · Tiền chợ · đợt hai');
    expect(sau.rieng!.updatedAt.isAfter(truocRieng.updatedAt), isTrue);
    expect(sau.nha!.updatedAt.isAfter(truocNha.updatedAt), isTrue);
    expect(await soDu('vr'), 4500000);
    expect(await soDu('vn'), 1500000);
  });

  test('sửa với tên ví chung chứa dấu phân cách · vẫn dựng lại đúng tiền tố', () async {
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'vx', idaccount: 10, name: 'Chợ · Gạo', idhousehold: const Value(7), updatedAt: moc));
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vx', tenViChung: 'Chợ · Gạo', soTien: 1000, viRiengId: 'vr', ngay: ngay, ghiChu: 'a');
    await s.sua(maCap: p, soTien: 2000, ngay: ngay, ghiChu: 'b');
    expect((await s.docCap(p)).rieng!.note, 'Góp quỹ · Chợ · Gạo · b');
    await s.sua(maCap: p, soTien: 2000, ngay: ngay, ghiChu: '');
    expect((await s.docCap(p)).rieng!.note, 'Góp quỹ · Chợ · Gạo',
        reason: 'tách ghi chú theo dấu · sẽ cắt sai tên ví có dấu ấy');
  });

  test('sửa cặp rút giữ tiền tố Rút quỹ', () async {
    final p = await s.rut(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 100, viRiengId: 'vr', ngay: ngay);
    await s.sua(maCap: p, soTien: 200, ngay: ngay, ghiChu: 'x');
    expect((await s.docCap(p)).rieng!.note, 'Rút quỹ · Tiền chợ · x');
  });

  test('xoá mềm cả hai nửa, hai ví tính lại, pending', () async {
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    final cap = await s.docCap(p);
    await s.xoa(p);
    final sau = await s.docCap(p);
    expect(sau.rieng, isNull);
    expect(sau.nha, isNull, reason: 'xoá cặp phải gỡ CẢ nửa của nhà, không để quỹ giữ tiền mồ côi');
    for (final id in [cap.rieng!.id, cap.nha!.id]) {
      final h = (await db.transactionDao.getById(id))!;
      expect(h.isDeleted, isTrue);
      expect(h.syncStatus, 'pending');
    }
    expect(await soDu('vr'), 5000000);
    expect(await soDu('vn'), 1000000);
  });

  test('xoá khi máy chỉ còn nửa của nhà (Chủ nhà xoá hộ): xoá nửa ấy', () async {
    final p = await s.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    final cap = await s.docCap(p);
    await db.transactionDao.softDelete(cap.rieng!.id);
    await s.xoa(p);
    expect((await s.docCap(p)).nha, isNull);
  });

  test('sửa khi máy chỉ còn nửa của nhà: đổi nửa ấy, không ném', () async {
    final p = await s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1000, ngay: ngay);
    await s.sua(maCap: p, soTien: 3000, ngay: ngay, ghiChu: 'k');
    final cap = await s.docCap(p);
    expect(cap.nha!.amount, 3000);
    expect(cap.nha!.note, 'k');
    expect(await soDu('vn'), 1003000);
  });

  group('không rò sang số liệu cá nhân (spec mục 12)', () {
    Future<List<TransactionEntity>> soCaNhan() async =>
        [for (final h in await db.transactionDao.getAll(10)) TransactionEntity.fromDrift(h)];

    test('góp: Sổ giao dịch = Trang chủ, nửa riêng là một khoản chi, nửa nhà không hiện', () async {
      final p = await s.gop(
          idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
      final ds = await soCaNhan();
      expect(ds.where((t) => t.fundPairId == p).map((t) => t.idhousehold), [null],
          reason: 'chỉ nửa riêng có mặt trong phép đọc cá nhân; nửa của nhà phải ở lại phạm vi nhà');
      expect(ds.every((t) => t.idhousehold == null), isTrue);
      final nuaRieng = ds.singleWhere((t) => t.fundPairId == p);
      expect(nuaRieng.note, 'Góp quỹ · Tiền chợ');
      expect(khoanVaoThongKe(loai: nuaRieng.type, categoryId: nuaRieng.categoryId, ghiChu: nuaRieng.note), isTrue,
          reason: 'nửa riêng tính như khoản chi cá nhân (quyết định #14)');
      final soGiaoDich = summarizeTransactions(ds);
      final trangChu = thuChiThangCua(ds, ngay);
      expect(soGiaoDich.expense, trangChu.chi);
      expect(soGiaoDich.income, trangChu.thu);
      expect(soGiaoDich.expense, 2000000, reason: 'đúng một lần: nửa của nhà không được cộng thêm');
      expect(soGiaoDich.income, 0, reason: 'nửa thu của nhà không được thành thu nhập cá nhân; neo mở sổ bị loại');
    });

    test('rút: nửa riêng là một khoản thu cá nhân', () async {
      await s.rut(
          idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 300000, viRiengId: 'vr', ngay: ngay);
      final ds = await soCaNhan();
      final soGiaoDich = summarizeTransactions(ds);
      final trangChu = thuChiThangCua(ds, ngay);
      expect(soGiaoDich.income, trangChu.thu);
      expect(soGiaoDich.income, 300000);
      expect(soGiaoDich.expense, 0, reason: 'nửa chi của nhà không được thành chi cá nhân');
      expect(ds.singleWhere((t) => t.fundPairId != null).note, 'Rút quỹ · Tiền chợ');
    });
  });

  test('tiền tố dùng chung với hằng của domain', () {
    expect(ghiChuNuaRieng(gop: true, tenViChung: 'A'), '${kTienToGopQuy}A');
    expect(ghiChuNuaRieng(gop: false, tenViChung: 'A', ghiChu: 'x'), '${kTienToRutQuy}A · x');
  });
}
