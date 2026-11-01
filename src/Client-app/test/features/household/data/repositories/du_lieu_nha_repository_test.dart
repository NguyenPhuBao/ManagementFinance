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

  test('suaViChung từ chối ví riêng, ví không có, và ví thuộc nhà khác — không ghi gì', () async {
    await themVi('rieng', ten: 'Riêng');
    final rieng = WalletEntity.fromDrift((await db.walletDao.getById('rieng'))!);
    await expectLater(repo.suaViChung(rieng.copyWith(name: 'Đổi', idhousehold: 7)),
        throwsA(isA<CacheException>()),
        reason: 'ví riêng không được sửa qua đường ví chung');
    expect((await db.walletDao.getById('rieng'))!.name, 'Riêng');

    final v = await taoVi('Chung');
    await expectLater(repo.suaViChung(v.copyWith(id: 'khong-co')), throwsA(isA<CacheException>()));
    await expectLater(repo.suaViChung(v.copyWith(name: 'Đổi', idhousehold: 8)),
        throwsA(isA<CacheException>()),
        reason: 'ví của nhà 7 không được đổi sang nhà 8');
    expect((await db.walletDao.getById(v.id))!.name, 'Chung');
    expect((await db.walletDao.getById(v.id))!.idhousehold, 7);
  });
}
