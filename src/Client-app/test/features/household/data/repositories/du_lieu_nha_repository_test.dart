/// `DuLieuNhaRepository` — đọc / ghi ví chung và khoản của nhà (gia đình 1A, Task 7).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

class _SyncEngineGia implements SyncEngine {
  int soLanHen = 0;
  @override
  void scheduleSync() => soLanHen++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Đặt neo luôn ném — mô phỏng tiến trình chết / `database is locked` giữa insert ví và đặt neo.
class _SoDuNemLoi extends SoDuViService {
  _SoDuNemLoi(AppDatabase db) : super(db: db, taiKhoanPhien: () => 10);
  @override
  Future<void> datNeoNhieuVi(Iterable<String> walletIds) async => throw StateError('chết giữa chừng');
}

void main() {
  late AppDatabase db;
  late DuLieuNhaRepositoryImpl repo;
  late _SyncEngineGia sync;
  final moc = DateTime(2026, 11, 1);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _SyncEngineGia();
    repo = DuLieuNhaRepositoryImpl(
      db: db,
      localDataSource: WalletLocalDataSourceImpl(db: db),
      // Ví nhà chỉ máy người tạo đặt neo (`datNeoNhieuVi`): thiếu nguồn phiên là neo không bao giờ được đặt.
      soDuVi: SoDuViService(db: db, taiKhoanPhien: () => 10),
      syncEngine: sync,
    );
  });
  tearDown(() => db.close());

  Future<void> themVi(String id,
          {int idaccount = 10,
          int? nha,
          String ten = 'Ví',
          String status = 'active',
          bool daXoa = false,
          bool macDinh = false}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: idaccount,
        name: ten,
        idhousehold: Value(nha),
        status: Value(status),
        isDefault: Value(macDinh),
        deletedAt: Value(daXoa ? moc : null),
        updatedAt: moc,
      ));

  Future<void> themKhoan(String id, String vi,
          {int idaccount = 10,
          int? nha,
          String? sang,
          DateTime? ngay,
          DateTime? sua,
          bool daXoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: idaccount,
        idhousehold: Value(nha),
        walletTransfer: Value(sang),
        amount: 1000,
        type: sang == null ? 'chi' : 'transfer',
        date: ngay ?? moc,
        deletedAt: Value(daXoa ? moc : null),
        updatedAt: sua ?? moc,
      ));

  Future<WalletEntity> taoVi(String ten, {int nha = 7, double soDu = 0}) =>
      repo.taoViChung(
          idNha: nha,
          idaccount: 10,
          ten: ten,
          loai: 'cash',
          soDuBanDau: soDu,
          icon: 'w',
          mau: '#000000');

  test('theoDoiKhoan: mọi khoản của nhà, không lẫn khoản riêng, kể cả của người khác', () async {
    await themVi('chung', nha: 7);
    await themVi('rieng');
    await themKhoan('k-toi', 'chung', nha: 7);
    await themKhoan('k-nguoi-khac', 'chung', idaccount: 11, nha: 7);
    await themKhoan('k-rieng', 'rieng');
    await themKhoan('k-nha-khac', 'chung', nha: 8);
    await themKhoan('k-da-xoa', 'chung', nha: 7, daXoa: true);

    final ds = await repo.theoDoiKhoan(7).first;
    expect(ds.map((k) => k.id).toSet(), {'k-toi', 'k-nguoi-khac'},
        reason: 'lọc theo NHÀ chứ không theo tài khoản; khoản riêng, khoản nhà khác và khoản đã xoá mềm không được lọt');
  });

  test('theoDoiKhoan: ngày mới trước, cùng ngày thì sửa gần nhất trước', () async {
    await themVi('chung', nha: 7);
    await themKhoan('cu', 'chung', nha: 7, ngay: DateTime(2026, 10, 1), sua: DateTime(2026, 11, 1));
    await themKhoan('moi-sua-som', 'chung', nha: 7, ngay: DateTime(2026, 10, 5), sua: DateTime(2026, 10, 5));
    await themKhoan('moi-sua-muon', 'chung', nha: 7, ngay: DateTime(2026, 10, 5), sua: DateTime(2026, 10, 6));

    final ds = await repo.theoDoiKhoan(7).first;
    expect(ds.map((k) => k.id).toList(), ['moi-sua-muon', 'moi-sua-som', 'cu'],
        reason: 'thứ tự `date` giảm dần rồi `updatedAt` giảm dần');
  });

  test('theoDoiKhoan có walletId: gồm khoản chuyển đến ví ấy, không lọt khoản ví khác', () async {
    await themVi('a', nha: 7, ten: 'A');
    await themVi('b', nha: 7, ten: 'B');
    await themVi('c', nha: 7, ten: 'C');
    await themKhoan('chi-a', 'a', nha: 7);
    await themKhoan('chuyen-b-sang-a', 'b', nha: 7, sang: 'a');
    await themKhoan('chi-c', 'c', nha: 7);

    final ds = await repo.theoDoiKhoan(7, walletId: 'a').first;
    expect(ds.map((k) => k.id).toSet(), {'chi-a', 'chuyen-b-sang-a'},
        reason: 'khoản chuyển ĐẾN ví cũng là khoản của ví (walletTransfer)');
  });

  test('taoViChung: mang idhousehold, không mặc định, không tính vào tổng, idaccount là người tạo', () async {
    final v = await taoVi('Tiền chợ', soDu: 500000);
    final h = (await db.walletDao.getById(v.id))!;
    expect(h.idhousehold, 7);
    expect(h.idaccount, 10);
    expect(h.isDefault, isFalse);
    expect(h.includeInTotal, isFalse, reason: 'tổng tài sản cá nhân không gồm ví chung');
    expect(sync.soLanHen, 1, reason: 'ghi xong phải hẹn đồng bộ');
  });

  test('taoViChung có số dư: neo mang idhousehold, số dư đúng', () async {
    final v = await taoVi('A', soDu: 500000);
    final neo = await db.transactionDao.getById(idKhoanMoSo(v.id));
    expect(neo, isNotNull, reason: 'thiếu nguồn phiên hoặc thiếu bước neo thì không có khoản mở sổ');
    expect(neo!.idhousehold, 7, reason: 'neo NULL nhà làm dọn nhà vỡ khoá ngoại, G113 lỗ hổng 3');
    expect((await db.walletDao.getById(v.id))!.balance, 500000);
  });

  test('taoViChung: đặt neo hỏng giữa chừng thì KHÔNG còn ví mồ côi thiếu khoản mở sổ (một giao tác)', () async {
    final hong = DuLieuNhaRepositoryImpl(
      db: db,
      localDataSource: WalletLocalDataSourceImpl(db: db),
      soDuVi: _SoDuNemLoi(db),
      syncEngine: sync,
    );
    await expectLater(
      hong.taoViChung(
          idNha: 7, idaccount: 10, ten: 'Mồ côi', loai: 'cash', soDuBanDau: 500000, icon: 'wallet', mau: '#000000'),
      throwsA(isA<StateError>()),
    );
    expect(await db.walletDao.getViNha(7), isEmpty,
        reason: 'tiến trình chết giữa insert ví và đặt neo: ví ở lại với số dư 500.000 mà không có khoản mở sổ, tính lại '
            'sau này đưa số dư về 0 — mất số dư ban đầu (insert + neo phải cùng một giao tác)');
    expect(sync.soLanHen, 0, reason: 'chưa tạo được thì không hẹn đồng bộ');
  });

  test('tên trùng trong nhà bị từ chối, trùng với ví riêng thì được, và ngược lại', () async {
    await themVi('rieng', ten: 'Tiền chợ');
    await taoVi('Tiền chợ');
    expect(await db.walletDao.getViNha(7), hasLength(1));

    await expectLater(taoVi('  tiền CHỢ '), throwsA(isA<CacheException>()),
        reason: 'index uq_wallet_household_name_active: trùng tên TRONG nhà');
    // Nhà khác thì được.
    await taoVi('Tiền chợ', nha: 8);

    // Chiều ngược: ví riêng trùng tên ví chung vẫn được.
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'rieng-2', idaccount: 10, name: 'Tiền chợ', updatedAt: moc));
    final ds = await WalletLocalDataSourceImpl(db: db).getAll(10);
    expect(ds.where((w) => w.name == 'Tiền chợ'), hasLength(2));
  });

  test('tên trùng: ví xoá mềm không giữ chỗ, ví lưu trữ vẫn giữ', () async {
    await themVi('da-xoa', nha: 7, ten: 'Đã xoá', daXoa: true);
    await taoVi('Đã xoá');

    await themVi('luu-tru', nha: 7, ten: 'Cất đi', status: 'inactive');
    await expectLater(taoVi('Cất đi'), throwsA(isA<CacheException>()),
        reason: 'bất biến ②: ví lưu trữ vẫn nằm trong index của server');
  });

  test('viChungDangDung bỏ ví lưu trữ và ví đã xoá; ví riêng và nhà khác không lọt', () async {
    await themVi('on', nha: 7, ten: 'On');
    await themVi('luu', nha: 7, ten: 'Luu', status: 'inactive');
    await themVi('xoa', nha: 7, ten: 'Xoa', daXoa: true);
    await themVi('nha-khac', nha: 8, ten: 'NhaKhac');
    await themVi('rieng', ten: 'Rieng');

    expect((await repo.viChungDangDung(7)).map((w) => w.id), ['on']);
    expect((await repo.theoDoiViChung(7).first).map((w) => w.id).toSet(), {'on', 'luu'},
        reason: 'theoDoiViChung giữ ví lưu trữ để còn bỏ lưu trữ được, bỏ ví đã xoá');
    expect((await repo.viChungDangDung(7)).single.idhousehold, 7,
        reason: 'WalletEntity phải mang idhousehold');
  });

  test('sửa ví chung giữ idhousehold và ép không mặc định, không tính vào tổng', () async {
    final v = await taoVi('Cũ');
    // Ví đã đồng bộ, giờ sửa cũ: để `pending` / `updatedAt` / hẹn đồng bộ chứng minh được chính lần sửa này làm ra.
    await db.walletDao.markSynced(v.id);
    final cu = DateTime(2020, 1, 1);
    await (db.update(db.wallets)..where((t) => t.id.equals(v.id)))
        .write(WalletsCompanion(updatedAt: Value(cu)));
    final doc = (await repo.viChungDangDung(7)).single;
    expect(doc.syncStatus, 'synced', reason: 'tiền đề của ca');

    // Không đổi tên: đổi tên đi qua `ThaViBiGiu` làm mới `updatedAt` và che mất vế `updatedAt` của `suaViChung`.
    await repo.suaViChung(doc.copyWith(icon: 'moi', isDefault: true, includeInTotal: true));

    final h = (await db.walletDao.getById(v.id))!;
    expect(h.icon, 'moi');
    expect(h.idhousehold, 7);
    expect(h.isDefault, isFalse,
        reason: 'ví nhà mang cờ mặc định đẩy lên vỡ chk_wallet_household_not_default, kẹt hàng đợi');
    expect(h.includeInTotal, isFalse);
    expect(h.syncStatus, 'pending', reason: 'sửa phải vào hàng đợi đẩy');
    expect(h.updatedAt.isAfter(cu), isTrue, reason: 'LWW: giờ sửa phải mới hơn');
    expect(sync.soLanHen, 2, reason: 'tạo 1 lần + sửa 1 lần');
  });

  test('sửa ví chung KHÔNG đè số dư bằng số cũ trên entity (bất biến ⑥), không sinh neo', () async {
    final v = await taoVi('A', soDu: 500000);
    final entityCu = (await repo.viChungDangDung(7)).single; // form mở lúc số dư 500.000
    await db.walletDao.updateBalance(v.id, 800000, cucBo: true); // lượt kéo về đổi số dư giữa chừng

    await repo.suaViChung(entityCu.copyWith(name: 'A2'));

    expect((await db.walletDao.getById(v.id))!.balance, 800000,
        reason: 'số dư chỉ SoDuViService ghi; ghi lại số cũ là lần ghi kế sinh neo `thu` pending cho cả nhà');
    final neo = await db.transactionDao.getById(idKhoanMoSo(v.id));
    expect(neo!.amount, 500000, reason: 'neo vẫn là khoản mở sổ ban đầu, không có neo thứ hai / không đổi');
    expect(await db.transactionDao.tongTheoVi(v.id), 500000);
  });

  test('sửa ví chung: số dư ghi chen giữa lúc đọc và lúc lưu không bị đè (giao tác)', () async {
    final v = await taoVi('A', soDu: 500000);
    final entityCu = (await repo.viChungDangDung(7)).single;

    // Không await: `getById` của suaViChung đã xếp hàng trước, `updateBalance` xếp sau nó — chen vào giữa đọc và ghi
    // nếu không có giao tác. Có giao tác thì Drift giữ lệnh ngoài giao tác lại tới khi xong.
    final sua = repo.suaViChung(entityCu.copyWith(name: 'A2'));
    final doiSo = db.walletDao.updateBalance(v.id, 900000, cucBo: true);
    await Future.wait([sua, doiSo]);

    expect((await db.walletDao.getById(v.id))!.balance, 900000,
        reason: 'số dư mới (ghi chen) phải thắng; số cũ quay lại là lần ghi kế sinh neo pending cho cả nhà');
    expect((await db.walletDao.getById(v.id))!.name, 'A2', reason: 'đổi tên đi qua ThaViBiGiu = giao tác lồng, vẫn ghi được');
  });

  test('suaViChung từ chối ví riêng, ví không có, và ví thuộc nhà khác — không ghi gì', () async {
    await themVi('rieng', ten: 'Riêng');
    final rieng = WalletEntity.fromDrift((await db.walletDao.getById('rieng'))!);
    await expectLater(repo.suaViChung(rieng.copyWith(name: 'Đổi', idhousehold: 7)),
        throwsA(isA<CacheException>()),
        reason: 'ví riêng không được sửa qua đường ví chung');
    expect((await db.walletDao.getById('rieng'))!.name, 'Riêng');

    // Ví riêng giữ `idhousehold` null: canh vế `hang.idhousehold == null`.
    await expectLater(repo.suaViChung(rieng.copyWith(name: 'Đổi')), throwsA(isA<CacheException>()),
        reason: 'ví riêng, entity cũng không mang nhà');
    expect((await db.walletDao.getById('rieng'))!.name, 'Riêng');

    final v = await taoVi('Chung');
    // Tên khác 'Chung' để lỗi không đến từ chốt trùng tên; so nội dung lỗi.
    await expectLater(
        repo.suaViChung(v.copyWith(id: 'khong-co', name: 'Khác hẳn')),
        throwsA(isA<CacheException>().having((e) => e.message, 'message', contains('Không tìm thấy'))));
    await themVi('xoa', nha: 7, ten: 'Đã xoá', daXoa: true);
    final xoa = WalletEntity.fromDrift((await db.walletDao.getById('xoa'))!);
    await expectLater(repo.suaViChung(xoa.copyWith(name: 'Hồi sinh')),
        throwsA(isA<CacheException>().having((e) => e.message, 'message', contains('Không tìm thấy'))),
        reason: 'getById trả cả hàng xoá mềm; sửa ví đã xoá không được ghi');
    expect((await db.walletDao.getById('xoa'))!.name, 'Đã xoá');
    await expectLater(repo.suaViChung(v.copyWith(name: 'Đổi', idhousehold: 8)),
        throwsA(isA<CacheException>()),
        reason: 'ví của nhà 7 không được đổi sang nhà 8');
    expect((await db.walletDao.getById(v.id))!.name, 'Chung');
    expect((await db.walletDao.getById(v.id))!.idhousehold, 7);
  });

  group('lối đọc / ghi của 1B', () {
    test('viChungChoForm: ví lưu trữ chỉ hiện khi ở giuLai, ví ưu tiên đứng đầu', () async {
      await themVi('A', nha: 7, ten: 'A');
      await themVi('B', nha: 7, ten: 'B');
      await themVi('C', nha: 7, ten: 'C', status: 'inactive');
      await themVi('D', nha: 8, ten: 'D');
      final mo = await repo.viChungChoForm(7, uuTien: 'B');
      expect(mo.map((v) => v.id), ['B', 'A'], reason: 'ví lưu trữ và ví nhà khác không vào bộ chọn');
      final sua = await repo.viChungChoForm(7, giuLai: {'C'});
      expect(sua.map((v) => v.id).toSet(), {'A', 'B', 'C'},
          reason: 'sửa khoản trên ví đã lưu trữ mà ví vắng là form đổi ví im lặng');
      final uuTienChet = await repo.viChungChoForm(7, uuTien: 'C');
      expect(uuTienChet.map((v) => v.id), isNot(contains('C')),
          reason: 'ví ưu tiên đã lưu trữ thì bỏ qua, form chọn ví đầu');
    });

    test('suaViChung giữ status của hàng, form mở lâu không bỏ lưu trữ', () async {
      final cu = await taoVi('Cũ');
      await repo.luuTruViChung(idNha: 7, id: cu.id, luuTru: true);
      await repo.suaViChung(cu.copyWith(name: 'Mới'));
      final hang = (await db.walletDao.getById(cu.id))!;
      expect(hang.status, 'inactive', reason: 'entity cũ mang status active; ghi đè là bỏ lưu trữ im lặng');
      expect(hang.name, 'Mới');
    });

    test('luuTruViChung: đổi status, hẹn đồng bộ, KHÔNG bị chốt ví hoạt động cuối cùng', () async {
      final v = await taoVi('Duy nhất');
      sync.soLanHen = 0;
      await repo.luuTruViChung(idNha: 7, id: v.id, luuTru: true);
      expect((await db.walletDao.getById(v.id))!.status, 'inactive',
          reason: 'ví chung duy nhất vẫn lưu trữ được: chốt "ví cuối" của ví riêng đếm ví của tài khoản');
      expect((await db.walletDao.getById(v.id))!.syncStatus, 'pending');
      expect(sync.soLanHen, 1);
      await repo.luuTruViChung(idNha: 7, id: v.id, luuTru: false);
      expect((await db.walletDao.getById(v.id))!.status, 'active');
    });

    test('luuTruViChung từ chối ví không thuộc nhà', () async {
      await themVi('rieng');
      await themVi('nha-khac', nha: 8);
      await themVi('xoa', nha: 7, daXoa: true);
      for (final id in ['rieng', 'nha-khac', 'xoa', 'khong-co']) {
        await expectLater(repo.luuTruViChung(idNha: 7, id: id, luuTru: true), throwsA(isA<CacheException>()),
            reason: 'ví $id không phải ví sống của nhà 7');
      }
      expect((await db.walletDao.getById('rieng'))!.status, 'active');
      expect((await db.walletDao.getById('nha-khac'))!.status, 'active');
    });

    test('xoaViChung: còn số dư hoặc còn giao dịch thì từ chối, ví trống thì xoá mềm', () async {
      final coSoDu = await taoVi('Có tiền', soDu: 100000);
      await expectLater(
          repo.xoaViChung(idNha: 7, id: coSoDu.id),
          throwsA(isA<CacheException>().having((e) => e.message, 'message', contains('lưu trữ'))),
          reason: 'câu phải chỉ lối sang lưu trữ');
      expect((await db.walletDao.getById(coSoDu.id))!.deletedAt, isNull);

      await themVi('co-gd', nha: 7, ten: 'Có giao dịch');
      await themKhoan('k1', 'co-gd', nha: 7);
      await expectLater(repo.xoaViChung(idNha: 7, id: 'co-gd'), throwsA(isA<CacheException>()),
          reason: 'số dư 0 nhưng đã có giao dịch: lịch sử phải được giữ');
      expect((await db.walletDao.getById('co-gd'))!.deletedAt, isNull);

      final trong = await taoVi('Trống');
      sync.soLanHen = 0;
      await repo.xoaViChung(idNha: 7, id: trong.id);
      final h = (await db.walletDao.getById(trong.id))!;
      expect(h.deletedAt, isNotNull);
      expect(h.syncStatus, 'pending');
      expect(sync.soLanHen, 1);

      await themVi('rieng');
      await expectLater(repo.xoaViChung(idNha: 7, id: 'rieng'), throwsA(isA<CacheException>()),
          reason: 'ví riêng không xoá qua đường ví chung');
    });

    test('napCayDanhMuc: nhóm, con, chưa nhóm của đúng nhà, đúng classify', () async {
      Future<void> dm(String id, {int? nha, String classify = 'chi', bool nhom = false, String? cha, bool xoa = false}) =>
          db.categoryDao.insert(CategoriesCompanion.insert(
            id: id,
            idaccount: 10,
            name: id,
            classify: classify,
            idhousehold: Value(nha),
            isGroup: Value(nhom),
            parentId: Value(cha),
            deletedAt: Value(xoa ? moc : null),
            updatedAt: moc,
          ));
      await dm('g', nha: 7, nhom: true);
      await dm('con', nha: 7, cha: 'g');
      await dm('le', nha: 7);
      await dm('mo-coi', nha: 7, cha: 'nhom-khong-co');
      await dm('thu', nha: 7, classify: 'thu');
      await dm('nha-khac', nha: 8);
      await dm('rieng');
      await dm('da-xoa', nha: 7, xoa: true);

      final cay = await repo.napCayDanhMuc(7, 'chi');
      expect(cay.groups.map((g) => g.group.id), ['g']);
      expect(cay.groups.single.children.map((c) => c.id), ['con']);
      expect(cay.ungroupedChildren.map((c) => c.id).toSet(), {'le', 'mo-coi'},
          reason: 'con của nhóm không còn trong nhà đứng ở "chưa nhóm"');
      expect(cay.defaultChildren, isEmpty);
      expect(cay.dangTamNgung, isEmpty);
      expect(cay.groups.single.group.idhousehold, 7, reason: 'Entity phải mang nhà để màn Sửa chốt phạm vi (ruling I-2)');

      final thu = await repo.napCayDanhMuc(7, 'thu');
      expect(thu.ungroupedChildren.map((c) => c.id), ['thu']);

      final theoDoi = await repo.theoDoiCayDanhMuc(7, 'chi').first;
      expect(theoDoi.groups.map((g) => g.group.id), ['g'], reason: 'luồng theo dõi cùng cây với phép đọc một lần');
    });

    group('hangChuaDay', () {
      Future<void> khoanCho(String id, String vi,
              {int idaccount = 20, int nha = 7, String loai = 'chi', String? cap, String st = 'pending', bool xoa = false}) =>
          db.transactionDao.insert(TransactionsCompanion.insert(
            id: id,
            walletId: vi,
            idaccount: idaccount,
            idhousehold: Value(nha),
            fundPairId: Value(cap),
            amount: 1000,
            type: loai,
            date: moc,
            syncStatus: Value(st),
            deletedAt: Value(xoa ? moc : null),
            updatedAt: moc,
          ));

      test('phân loại góp, rút, khoản, ví, danh mục, mục tiêu', () async {
        await themVi('v7', nha: 7);
        await db.walletDao.insert(WalletsCompanion.insert(
            id: 'v8', idaccount: 20, name: 'v8', idhousehold: const Value(8), updatedAt: moc, syncStatus: const Value('pending')));
        await khoanCho('chi-thuong', 'v7');
        await khoanCho('gop', 'v7', loai: 'thu', cap: 'cap-1');
        await khoanCho('rut', 'v7', loai: 'chi', cap: 'cap-2');
        await khoanCho('da-dong-bo', 'v7', st: 'synced');
        await khoanCho('nha-khac', 'v8', nha: 8);
        await db.categoryDao.insert(CategoriesCompanion.insert(
            id: 'dm', idaccount: 20, name: 'dm', classify: 'chi', idhousehold: const Value(7), updatedAt: moc));
        await db.goalDao.insert(GoalsCompanion(
            id: const Value('mt'),
            idaccount: const Value(20),
            name: const Value('mt'),
            targetAmount: const Value(1),
            targetDate: Value(moc),
            idhousehold: const Value(7),
            syncStatus: const Value('pending'),
            updatedAt: Value(moc)));

        final h = await repo.hangChuaDay(7, idaccount: 20);
        // `themVi('v7')` mặc định đã `pending`, nên ví đếm 1.
        expect((h.khoan, h.gop, h.rut, h.vi, h.danhMuc, h.khac), (1, 1, 1, 1, 1, 1));
        expect(h.rong, isFalse);
        expect(h.coTienTraVe, isTrue);
        expect(await db.demHangChuaDayCuaNha(7), h.khoan + h.gop + h.rut + h.vi + h.danhMuc + h.khac,
            reason: 'tổng sáu loại phải bằng phép đếm cũ của cổng Rời nhà');
      });

      test('nửa góp pending của người khác đếm vào khoan, không vào gop', () async {
        await themVi('v7', nha: 7);
        await db.walletDao.markSynced('v7');
        // Chủ (20) xoá hộ offline nửa góp do tài khoản 10 ghi: lệnh xoá pending vẫn mang mã cặp.
        await khoanCho('gop-cua-10', 'v7', idaccount: 10, loai: 'thu', cap: 'cap-1', xoa: true);
        final h = await repo.hangChuaDay(7, idaccount: 20);
        expect((h.khoan, h.gop, h.coTienTraVe), (1, 0, false),
            reason: 'traVeKhiBoNha chỉ trả nửa của tôi; hộp nói được trả tiền là sai');
      });

      test('không phiên: mọi hàng vào khoan', () async {
        await themVi('v7', nha: 7);
        await db.walletDao.markSynced('v7');
        await khoanCho('gop', 'v7', loai: 'thu', cap: 'c1');
        await khoanCho('rut', 'v7', loai: 'chi', cap: 'c2');
        final h = await repo.hangChuaDay(7, idaccount: null);
        expect((h.khoan, h.gop, h.rut), (2, 0, 0));
      });
    });
  });
}
