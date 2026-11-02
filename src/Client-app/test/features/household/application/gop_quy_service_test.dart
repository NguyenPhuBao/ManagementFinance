/// `GopQuyService` — ghi / sửa / xoá một cặp góp, rút của gia đình (gia đình 1A, Task 8; `docs/Family/02A` mục 5–6).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/home/domain/thu_chi_thang.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/transaction/domain/khoan_vao_thong_ke.dart';
import 'package:flowmoney/features/transaction/domain/transaction_filter.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

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
    expect(sync.syncScheduled, isTrue, reason: 'phải xin đồng bộ');
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
    // Nửa của nhà chèn trước; nửa riêng (ví vr) bị trigger chặn ở lần chèn thứ hai — nếu không chung giao tác thì nửa nhà sót lại.
    // ⚠️ Chỉ chặn hàng CÓ MÃ CẶP: chặn mọi hàng của `vr` thì cả khoản mở sổ của ví (neo) cũng bị chặn và ca đỏ vì lý do khác
    // lý do nó nói.
    await db.customStatement(
        "CREATE TRIGGER chan_nua_rieng BEFORE INSERT ON transactions WHEN NEW.wallet_id = 'vr' AND NEW.fund_pair_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'x'); END");
    await expectLater(
        s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1, viRiengId: 'vr', ngay: ngay),
        throwsA(anything));
    expect(await cacNuaCap(), isEmpty, reason: 'hai nửa phải cùng một giao tác — không được sót nửa của nhà');
    expect(await soDu('vn'), 1000000);
    expect(await soDu('vr'), 5000000);
  });

  group('chốt đầu vào của _ghi / sua: từ chối, không ghi gì', () {
    Future<void> khongGhi(Future<Object?> Function() lam) async {
      await expectLater(lam(), throwsA(isA<CacheException>()));
      expect(await cacNuaCap(), isEmpty);
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
    }

    Future<Object?> gopVoi({String chung = 'vn', String? rieng = 'vr', double tien = 1000, int nha = 7}) =>
        s.gop(idNha: nha, idaccount: 10, viChungId: chung, tenViChung: 'T', soTien: tien, viRiengId: rieng, ngay: ngay);

    Future<void> xoaMem(String id) =>
        (db.update(db.wallets)..where((w) => w.id.equals(id))).write(WalletsCompanion(deletedAt: Value(moc)));

    test('ví chung không có', () => khongGhi(() => gopVoi(chung: 'khong-co')));
    test('ví chung đã xoá mềm', () async {
      await xoaMem('vn');
      await khongGhi(() => gopVoi());
    });
    test('ví chung thuộc nhà khác', () => khongGhi(() => gopVoi(nha: 8)));
    test('ví "chung" thực ra là ví riêng', () => khongGhi(() => gopVoi(chung: 'vr', rieng: null)));
    test('ví riêng không có', () => khongGhi(() => gopVoi(rieng: 'khong-co')));
    test('ví riêng đã xoá mềm', () async {
      await xoaMem('vr');
      await khongGhi(() => gopVoi());
    });
    test('ví riêng là ví của nhà', () => khongGhi(() => gopVoi(rieng: 'vn')));
    test('số tiền 0', () => khongGhi(() => gopVoi(tien: 0)));
    test('số tiền âm', () => khongGhi(() => gopVoi(tien: -5)));
    test(
        'rút: số tiền 0 cũng bị từ chối',
        () => khongGhi(() =>
            s.rut(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 0, viRiengId: 'vr', ngay: ngay)));
    test('sửa với số tiền <= 0 ném và không đổi gì', () async {
      final p = await s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1000, viRiengId: 'vr', ngay: ngay);
      await expectLater(s.sua(maCap: p, soTien: 0, ngay: ngay, ghiChu: ''), throwsA(isA<CacheException>()));
      await expectLater(s.sua(maCap: p, soTien: -1, ngay: ngay, ghiChu: ''), throwsA(isA<CacheException>()));
      expect((await s.docCap(p)).nha!.amount, 1000);
    });
  });

  group('giao tác của sua / xoa', () {
    Future<String> capMoi() =>
        s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);

    // Chặn theo PHẠM VI (`idhousehold`), không theo id nửa nào: ca không dựa vào thứ tự hai nửa trong vòng lặp. Chặn lần lượt
    // từng nửa — nửa nào được ghi SAU nửa kia thì nửa kia phải lùi lại cùng giao tác.
    Future<void> chanNua({required bool nuaNha}) => db.customStatement(
        'CREATE TRIGGER chan_nua BEFORE UPDATE ON transactions WHEN NEW.fund_pair_id IS NOT NULL AND NEW.idhousehold IS '
        "${nuaNha ? 'NOT NULL' : 'NULL'} BEGIN SELECT RAISE(ABORT,'x'); END");

    for (final nuaNha in [true, false]) {
      final ten = nuaNha ? 'nửa nhà' : 'nửa riêng';
      final kia = nuaNha ? 'nửa riêng' : 'nửa nhà';
      test('sua: $ten lỗi thì $kia nguyên, số dư nguyên', () async {
        final p = await capMoi();
        final truoc = await s.docCap(p);
        await chanNua(nuaNha: nuaNha);
        await expectLater(s.sua(maCap: p, soTien: 1, ngay: ngay, ghiChu: 'z'), throwsA(anything));
        final sau = await s.docCap(p);
        expect(sau.rieng!.amount, 2000000, reason: 'hàng đã sửa trước trong vòng lặp phải lùi lại cùng giao tác');
        expect(sau.nha!.amount, 2000000);
        expect(sau.rieng!.note, truoc.rieng!.note);
        expect(await soDu('vr'), 3000000);
        expect(await soDu('vn'), 3000000);
      });

      test('xoa: $ten lỗi thì $kia nguyên, số dư nguyên', () async {
        final p = await capMoi();
        await chanNua(nuaNha: nuaNha);
        await expectLater(s.xoa(p), throwsA(anything));
        final sau = await s.docCap(p);
        expect(sau.rieng, isNotNull, reason: 'hàng đã xoá mềm trước phải lùi lại cùng giao tác');
        expect(sau.nha, isNotNull);
        expect(await soDu('vr'), 3000000);
        expect(await soDu('vn'), 3000000);
      });
    }

    test('xin đồng bộ đúng một lần ở sua và ở xoa', () async {
      final p = await capMoi();
      soLanHen = 0;
      await s.sua(maCap: p, soTien: 1000, ngay: ngay, ghiChu: '');
      expect(soLanHen, 1, reason: 'thiếu thì nửa sửa nằm pending mãi');
      await s.xoa(p);
      expect(soLanHen, 2);
    });
  });

  group('ví chung do người khác tạo (idaccount 99) — Thành viên góp', () {
    // Số hàng khoản mở sổ CỦA ví v99 (theo ví + ghi chú, không theo id: id tất định từ id ví nên đếm theo id luôn ra ≤ 1).
    Future<int> demNeo() async => (await db.select(db.transactions).get())
        .where((h) => h.walletId == 'v99' && h.note == ghiChuMoSo())
        .length;

    test('ví chung CHƯA có neo trên máy (mới kéo về, số dư lưu khác 0): góp, sửa, xoá KHÔNG tự đặt neo', () async {
      // Ví vừa về mang số dư lưu 1.000.000 mà sổ trên máy chưa có neo: nếu máy này (phiên 10, KHÔNG phải người tạo) tự đặt
      // neo thì sinh khoản mở sổ 1.000.000 của người khác — đếm hàng trước / sau mới thấy (ví khớp sổ thì phép vá no-op).
      await (db.delete(db.transactions)..where((h) => h.id.equals(idKhoanMoSo('v99')))).go();
      expect(await demNeo(), 0, reason: 'tiền đề');
      final p = await s.gop(
          idNha: 7, idaccount: 10, viChungId: 'v99', tenViChung: 'Quỹ chung', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
      expect(await demNeo(), 0, reason: 'sau góp: neo chỉ máy người tạo đặt, máy khác nhận qua kéo về (G113 nợ 1)');
      expect(await soDu('v99'), 2000000, reason: 'số dư suy từ sổ: chỉ có khoản góp');
      await s.sua(maCap: p, soTien: 500000, ngay: ngay, ghiChu: '');
      expect(await demNeo(), 0, reason: 'sau sửa');
      await s.xoa(p);
      expect(await demNeo(), 0, reason: 'sau xoá');
      expect(await soDu('vr'), 5000000);
    });

    setUp(() async {
      await db.walletDao.insert(WalletsCompanion.insert(
          id: 'v99', idaccount: 99, name: 'Quỹ chung', balance: const Value(1000000), idhousehold: const Value(7), updatedAt: moc));
      // Neo do máy người tạo đặt, về qua kéo về — máy này (phiên 10) không được tự đặt thêm.
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: idKhoanMoSo('v99'),
          walletId: 'v99',
          idaccount: 99,
          idhousehold: const Value(7),
          amount: 1000000,
          type: 'thu',
          note: Value(ghiChuMoSo()),
          date: moc,
          updatedAt: moc));
    });

    test('góp, sửa, xoá: không sinh neo mới, số dư hai ví đúng', () async {
      final p = await s.gop(
          idNha: 7, idaccount: 10, viChungId: 'v99', tenViChung: 'Quỹ chung', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
      expect(await demNeo(), 1, reason: 'sau góp: vẫn đúng một khoản mở sổ (của người tạo)');
      expect(await soDu('v99'), 3000000);
      expect(await soDu('vr'), 3000000);
      await s.sua(maCap: p, soTien: 500000, ngay: ngay, ghiChu: '');
      expect(await demNeo(), 1, reason: 'sau sửa');
      expect(await soDu('v99'), 1500000);
      expect(await soDu('vr'), 4500000);
      await s.xoa(p);
      expect(await demNeo(), 1, reason: 'sau xoá');
      expect(await soDu('v99'), 1000000);
      expect(await soDu('vr'), 5000000);
    });
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

  test('sua và xoa trả false khi mã không còn hàng nào, true khi có', () async {
    expect(await s.sua(maCap: 'la', soTien: 1, ngay: DateTime(2026), ghiChu: ''), isFalse,
        reason: 'cặp đã bị gỡ ở máy khác: tầng trên phải biết để báo, không coi là đã sửa');
    expect(await s.xoa('la'), isFalse);
    expect(soLanHen, 0, reason: 'không làm gì thì không hẹn đồng bộ');

    final p = await s.gop(idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'T', soTien: 1000, viRiengId: 'vr', ngay: ngay);
    expect(await s.sua(maCap: p, soTien: 2000, ngay: ngay, ghiChu: 'x'), isTrue);
    expect(await s.xoa(p), isTrue);
    expect(await s.xoa(p), isFalse, reason: 'xoá lần hai: cả hai nửa đã xoá mềm, docCap không thấy nữa');
  });
}
