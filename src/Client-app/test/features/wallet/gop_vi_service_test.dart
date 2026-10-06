/// G63 — `GopViService`: thi hành ĐÚNG kế hoạch gộp, trong một giao tác (spec mục 6.2; bẫy 1, 4, 5, 6).
///
/// Số liệu: P mở sổ 3.400.000; R mở sổ 1.000.000, thu 500.000, chi 250.000, nhận chuyển 100.000 từ P và 50.000 từ X;
/// X mở sổ 200.000. Tổng sổ R = 1.400.000, P = 3.300.000 → sau gộp P = 3.300.000 + 1.400.000 − 1.000.000 = 3.700.000
/// (đối chiếu tay: 3.400.000 + 500.000 − 250.000 + 50.000).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/wallet/data/services/gop_vi_service.dart';
import 'package:flowmoney/features/wallet/data/services/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

const acc = 7;
const idP = 'aaaaaaaa-0000-4000-8000-00000000000p';
const idR = 'aaaaaaaa-0000-4000-8000-00000000000r';
const idX = 'aaaaaaaa-0000-4000-8000-00000000000x';

class _SoDuNem extends SoDuViService {
  _SoDuNem(AppDatabase db) : super(db: db);
  @override
  Future<void> tinhLaiSoDu(String walletId) async => throw StateError('hỏng giữa chừng — thử hoàn nguyên');
}

void main() {
  late AppDatabase db;
  late InMemoryViTheoNguonStore bang;
  late int soLanHenDongBo;
  late GopViService svc;
  final ngay = DateTime(2026, 10, 5);

  Future<void> vi(String id, String ten, {String type = 'bank', bool macDinh = false, String status = 'active'}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: acc,
        name: ten,
        type: Value(type),
        isDefault: Value(macDinh),
        status: Value(status),
        updatedAt: ngay,
      ));

  Future<void> gd(String id, String w, String loai, double tien, {String? nhan, String? ghiChu}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: w,
        idaccount: acc,
        amount: tien,
        type: loai,
        date: ngay,
        walletTransfer: Value(nhan),
        note: Value(ghiChu ?? ''),
        syncStatus: const Value('synced'),
        updatedAt: ngay,
      ));

  Future<void> dungDuLieu({
    String loaiP = 'bank',
    bool rMacDinh = false,
    String statusP = 'active',
    bool pCoNeo = true,
  }) async {
    await vi(idP, 'Ví MB Bank', type: loaiP, status: statusP);
    await vi(idR, 'Ví MB Bank', macDinh: rMacDinh);
    await vi(idX, 'Tiền mặt', type: 'cash');
    await db.walletDao.danhDauTrungTen(idR);
    if (pCoNeo) await gd(idKhoanMoSo(idP), idP, 'thu', 3400000, ghiChu: tienToMoSo);
    await gd(idKhoanMoSo(idR), idR, 'thu', 1000000, ghiChu: tienToMoSo);
    await gd(idKhoanMoSo(idX), idX, 'thu', 200000, ghiChu: tienToMoSo);
    await gd('tx1', idR, 'thu', 500000);
    await gd('tx2', idR, 'chi', 250000);
    await gd('t3', idP, 'transfer', 100000, nhan: idR);
    await gd('t4', idX, 'transfer', 50000, nhan: idR);
    await db.billDao.insert(BillsCompanion.insert(
        id: 'b1',
        idaccount: acc,
        name: 'Tiền điện',
        amount: 300000,
        dueDate: ngay,
        walletId: const Value(idR),
        syncStatus: const Value('synced'),
        updatedAt: ngay));
    await db.goalDao.insert(GoalsCompanion.insert(
        id: 'g1',
        idaccount: acc,
        name: 'Mua xe',
        targetAmount: 50000000,
        targetDate: DateTime(2027, 1, 1),
        walletId: const Value(idP),
        autoDepositWalletId: const Value(idR),
        autoDepositAmount: const Value(100000),
        autoDepositLastRun: Value(ngay),
        syncStatus: const Value('synced'),
        updatedAt: ngay));
    await db.goalDao.insert(GoalsCompanion.insert(
        id: 'g2',
        idaccount: acc,
        name: 'Du lịch',
        targetAmount: 9000000,
        targetDate: DateTime(2027, 1, 1),
        walletId: const Value(idR),
        syncStatus: const Value('synced'),
        updatedAt: ngay));
    await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: 'n-r',
        idaccount: acc,
        kind: NotificationKind.walletLowBalance.name,
        dedupeKey: 'walletLow:$idR:20261005',
        title: 'Số dư ví sắp cạn',
        body: 'Ví MB Bank chỉ còn ít tiền.',
        severity: 'warning',
        subjectType: const Value('wallet'),
        subjectId: const Value(idR),
        createdAt: ngay));
    bang.values[acc] = {'MB Bank|1234': idR, 'MoMo|': idX};
    await SoDuViService(db: db).tinhLaiNhieuVi({idP, idR, idX});
    // Lần bị từ chối để lại mốc chặn theo giờ — `gop` phải gỡ nó (bẫy 1).
    await db.walletDao.markSyncBlocked(idR, DateTime(2030), 'Tên ví đã tồn tại');
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bang = InMemoryViTheoNguonStore();
    soLanHenDongBo = 0;
    svc = GopViService(db: db, soDuVi: SoDuViService(db: db), viTheoNguon: bang, henDongBo: () => soLanHenDongBo++);
  });
  tearDown(() => db.close());

  test('lập kế hoạch đọc đúng sổ: số dư sau gộp 3.700.000', () async {
    await dungDuLieu();
    final kh = await svc.lapKeHoach(idViBo: idR, idViGiu: idP);
    expect(kh.soDuSauGop, 3700000);
    expect(kh.giaoDichDoiVi, unorderedEquals(['tx1', 'tx2', 't4']));
    expect(kh.khoanChuyenNoiBo, ['t3']);
    expect(kh.idKhoanMoSoBo, idKhoanMoSo(idR));
    expect(kh.hoaDonDoiVi, ['b1']);
  });

  test('⭐ gộp: số dư P đúng con số của kế hoạch (bẫy 4, 6) và ví thứ ba không đổi', () async {
    await dungDuLieu();
    final kh = await svc.lapKeHoach(idViBo: idR, idViGiu: idP);

    await svc.gop(kh);

    expect(((await db.walletDao.getById(idP))!.balance - kh.soDuSauGop).abs(), lessThan(0.5));
    expect((await db.walletDao.getById(idX))!.balance, 150000);
  });

  test('⭐ gộp: từng bước 1–9', () async {
    await dungDuLieu();
    await svc.gop(await svc.lapKeHoach(idViBo: idR, idViGiu: idP));

    final tx1 = (await db.transactionDao.getById('tx1'))!;
    expect(tx1.walletId, idP);
    expect(tx1.syncStatus, 'pending');
    expect((await db.transactionDao.getById('tx2'))!.walletId, idP);
    expect((await db.transactionDao.getById('t4'))!.walletTransfer, idP, reason: 'vai ví nhận cũng chuyển');
    expect((await db.transactionDao.getById(idKhoanMoSo(idR)))!.deletedAt, isNotNull, reason: 'bước 2');
    expect((await db.transactionDao.getById('t3'))!.deletedAt, isNotNull, reason: 'bước 3 — chuyển nội bộ');
    expect((await db.billDao.getById('b1'))!.walletId, idP);
    final g1 = (await db.goalDao.getById('g1'))!;
    expect(g1.autoDepositWalletId, isNull, reason: 'nguồn trích trùng ví nhận → tắt trích, ba cột cùng NULL');
    expect(g1.autoDepositAmount, isNull);
    expect(g1.autoDepositLastRun, isNull);
    expect((await db.goalDao.getById('g2'))!.walletId, idP);
    expect(await bang.doc(acc, 'MB Bank', '1234'), idP, reason: 'bước 5');
    expect(await bang.doc(acc, 'MoMo', null), idX);
    final r = (await db.walletDao.getById(idR))!;
    expect(r.deletedAt, isNotNull, reason: 'bước 6');
    expect(r.biTuChoiTrungTen, isFalse);
    expect(r.syncBlockedUntil, isNull, reason: 'lệnh xoá R phải lên ngay, không chờ mốc chặn (bẫy 1)');
    final n = (await db.notificationDao.getAll(acc)).single;
    expect(n.dismissedAt, isNotNull, reason: 'bước 9 — thông báo không được trỏ vào ví đã gộp');
    expect(soLanHenDongBo, 1);
  });

  test('⭐ P CHƯA có khoản mở sổ mà số dư khác sổ → số dư sau gộp vẫn đúng con số của kế hoạch (bẫy 6)', () async {
    await dungDuLieu(pCoNeo: false);
    // Chỉ trong test: dựng một ví mà số dư (3.400.000) không nằm trong sổ (sổ P chỉ có −100.000 của t3).
    await db.walletDao.updateBalance(idP, 3400000);

    final kh = await svc.lapKeHoach(idViBo: idR, idViGiu: idP);
    expect(kh.soDuSauGop, 3800000,
        reason: 'lapKeHoach vật chất hoá neo của P (3.500.000) TRƯỚC khi đọc sổ: 3.400.000 + 1.400.000 − 1.000.000.');

    await svc.gop(kh);
    expect(((await db.walletDao.getById(idP))!.balance - 3800000).abs(), lessThan(0.5),
        reason: 'Đặt neo SAU khi dời sổ là neo hấp thụ luôn sổ vừa dời — số dư lệch, im lặng.');
  });

  test('cờ mặc định của R chuyển sang P; máy còn đúng một ví mặc định', () async {
    await dungDuLieu(rMacDinh: true);
    await svc.gop(await svc.lapKeHoach(idViBo: idR, idViGiu: idP));
    expect((await db.walletDao.getById(idP))!.isDefault, isTrue);
    expect((await db.walletDao.getAll(acc)).where((w) => w.isDefault), hasLength(1));
  });

  test('⭐ kế hoạch CŨ (có khoản mới ghi vào R sau khi lập) → từ chối, không đổi gì', () async {
    await dungDuLieu();
    final kh = await svc.lapKeHoach(idViBo: idR, idViGiu: idP);
    await gd('tx-moi', idR, 'chi', 1000);

    await expectLater(svc.gop(kh), throwsA(isA<KeHoachGopCuException>()));

    expect((await db.walletDao.getById(idR))!.deletedAt, isNull);
    expect((await db.transactionDao.getById('tx1'))!.walletId, idR);
  });

  test('⭐ lỗi giữa chừng → hoàn nguyên cả giao tác', () async {
    await dungDuLieu();
    final hong = GopViService(db: db, soDuVi: _SoDuNem(db), viTheoNguon: bang);
    final kh = await hong.lapKeHoach(idViBo: idR, idViGiu: idP);

    await expectLater(hong.gop(kh), throwsA(isA<StateError>()));

    expect((await db.transactionDao.getById('tx1'))!.walletId, idR);
    expect((await db.walletDao.getById(idR))!.deletedAt, isNull);
    expect(await bang.doc(acc, 'MB Bank', '1234'), idR, reason: 'bảng nguồn → ví chỉ ghi SAU khi giao tác xong');
  });

  test('ví liên kết ngân hàng → không gộp', () async {
    await dungDuLieu(loaiP: 'banking');
    final kh = await svc.lapKeHoach(idViBo: idR, idViGiu: idP);
    expect(kh.coTheGop, isFalse);
    await expectLater(svc.gop(kh), throwsA(isA<StateError>()));
  });
}
