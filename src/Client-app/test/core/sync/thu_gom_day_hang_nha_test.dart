/// Gia đình đợt 1A (spec 2026-11-01 mục 7.1) — `ThuGomThaoTacDay` thu gom cả hàng của NHÀ do người khác ghi.
///
/// Hàng của nhà mang `idaccount` của người GHI. Chủ nhà sửa khoản của Thành viên (hay Chủ mới sửa ví của Chủ cũ) thì hàng
/// `pending` vẫn mang `idaccount` người kia; lọc "hàng của tôi" là bản sửa nằm chờ mãi, không bao giờ lên server.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/core/sync/thu_gom_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sync_engine_thu.dart';

const _toi = 10;
const _nguoiKhac = 20;
const _nha = 7;
const _nhaKhac = 8;
const _dmToi = 'bbbbbbbb-0000-4000-8000-000000000001';
const _dmHo = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final ngay = DateTime(2026, 11, 1);

  ThuGomThaoTacDay thuGom({int? nha}) => ThuGomThaoTacDay(
        db: db,
        viBiGiu: congViBiGiuThat(db),
        now: () => ngay,
        taiKhoanPhien: () => _toi,
        nhaPhien: () => nha,
      );

  Future<List<SyncOperation>> thu({int? nha}) => thuGom(nha: nha).collectPendingOps(_toi);

  Future<void> vi(String id, int acc, int? nha, {String sync = 'pending'}) => db.walletDao.insert(WalletsCompanion.insert(
      id: id, idaccount: acc, idhousehold: Value(nha), name: 'Ví $id', syncStatus: Value(sync), updatedAt: ngay));

  Future<void> gd(String id, int acc, int? nha, {String vi = 'v1', String? danhMuc, String sync = 'pending'}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: acc,
        idhousehold: Value(nha),
        categoryId: Value(danhMuc),
        amount: 1000,
        type: 'chi',
        date: ngay,
        syncStatus: Value(sync),
        updatedAt: ngay,
      ));

  Future<void> mt(String id, int acc, int? nha) => db.goalDao.insert(GoalsCompanion.insert(
      id: id,
      idaccount: acc,
      idhousehold: Value(nha),
      name: 'MT $id',
      targetAmount: 1000,
      targetDate: ngay,
      updatedAt: ngay));

  Future<void> ns(String id, int acc, int? nha) => db.budgetDao.insert(BudgetsCompanion.insert(
      id: id, idaccount: acc, idhousehold: Value(nha), amount: 1000, startDate: ngay, updatedAt: ngay));

  Future<void> dm(String id, int acc, int? nha, {String sync = 'pending'}) =>
      db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: acc,
          idhousehold: Value(nha),
          name: 'DM $id',
          classify: 'chi',
          syncStatus: Value(sync),
          updatedAt: ngay));

  Iterable<SyncOperation> cua(List<SyncOperation> ops, String id) => ops.where((o) => o.localId == id);

  group('giao dịch', () {
    test('Chủ nhà sửa khoản của Thành viên: hàng pending có idaccount người khác vẫn được thu gom', () async {
      await vi('v1', _nguoiKhac, _nha, sync: 'synced');
      await gd('g', _nguoiKhac, _nha);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'g'), hasLength(1),
          reason: 'lọc idaccount = tôi là bản sửa của Chủ nhà nằm pending mãi, không lên server');
    });

    test('hàng của nhà KHÁC không bị thu gom', () async {
      await vi('v1', _nguoiKhac, _nhaKhac, sync: 'synced');
      await gd('k', _nguoiKhac, _nhaKhac);
      expect(cua(await thu(nha: _nha), 'k'), isEmpty, reason: 'chỉ nhà tôi đang ở mới được mở rộng phạm vi');
    });

    test('không có nhà: chỉ hàng của tôi như trước', () async {
      await vi('v1', _nguoiKhac, _nha, sync: 'synced');
      await gd('g', _nguoiKhac, _nha);
      await gd('rieng', _toi, null);
      final ops = await thu(nha: null);
      expect(cua(ops, 'g'), isEmpty, reason: 'không biết nhà thì không mở rộng (isolate nền, kho chưa nạp)');
      expect(cua(ops, 'rieng'), hasLength(1));
    });

    test('hàng riêng của người khác (không thuộc nhà) không bị thu gom dù tôi đang ở nhà', () async {
      await vi('v1', _nguoiKhac, null, sync: 'synced');
      await gd('xa', _nguoiKhac, null);
      expect(cua(await thu(nha: _nha), 'xa'), isEmpty);
    });

    test('payload giữ idaccount người ghi', () async {
      await vi('v1', _nguoiKhac, _nha, sync: 'synced');
      await gd('g', _nguoiKhac, _nha);
      final ops = await thu(nha: _nha);
      final p = cua(ops, 'g').single.payload;
      expect(p['idaccount'], _nguoiKhac,
          reason: 'server giữ người ghi; đổi sang phiên là mất quyền của người ghi');
      expect(p['idhousehold'], _nha);
    });
  });

  group('ví / mục tiêu / ngân sách / danh mục', () {
    test('Chủ mới sửa ví của Chủ cũ', () async {
      await vi('vn', _nguoiKhac, _nha);
      await vi('vk', _nguoiKhac, _nhaKhac);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'vn'), hasLength(1), reason: 'ví chung do người khác tạo, tôi sửa hộ');
      expect(cua(ops, 'vn').single.payload['idaccount'], _nguoiKhac);
      expect(cua(ops, 'vk'), isEmpty);
      expect(cua(await thu(nha: null), 'vn'), isEmpty);
    });

    test('mục tiêu của nhà do người khác tạo', () async {
      await mt('mn', _nguoiKhac, _nha);
      await mt('mk', _nguoiKhac, _nhaKhac);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'mn'), hasLength(1));
      expect(cua(ops, 'mn').single.payload['idaccount'], _nguoiKhac);
      expect(cua(ops, 'mk'), isEmpty);
      expect(cua(await thu(nha: null), 'mn'), isEmpty);
    });

    test('ngân sách của nhà do người khác tạo', () async {
      await ns('nn', _nguoiKhac, _nha);
      await ns('nk', _nguoiKhac, _nhaKhac);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'nn'), hasLength(1));
      expect(cua(ops, 'nn').single.payload['idaccount'], _nguoiKhac);
      expect(cua(ops, 'nk'), isEmpty);
      expect(cua(await thu(nha: null), 'nn'), isEmpty);
    });

    test('Thành viên sửa danh mục người khác tạo', () async {
      await dm('dn', _nguoiKhac, _nha);
      await dm('dk', _nguoiKhac, _nhaKhac);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'dn'), hasLength(1), reason: '`getSyncableCategories` lọc idaccount = tôi thì bản sửa không lên');
      expect(cua(ops, 'dn').single.payload['idaccount'], _nguoiKhac);
      expect(cua(ops, 'dk'), isEmpty);
      expect(cua(await thu(nha: null), 'dn'), isEmpty);
    });
  });

  group('khối 1b: danh mục gửi kèm', () {
    test('khoản của nhà trỏ danh mục của nhà do TÔI tạo: payload danh mục mang idhousehold của nhà', () async {
      await vi('v1', _nguoiKhac, _nha, sync: 'synced');
      await dm(_dmToi, _toi, _nha, sync: 'synced');
      await gd('g', _nguoiKhac, _nha, danhMuc: _dmToi);
      final ops = await thu(nha: _nha);
      expect(cua(ops, 'g'), hasLength(1));
      final c = cua(ops, _dmToi);
      expect(c, hasLength(1),
          reason: 'khoản đi mà danh mục chưa lên server là vỡ khoá ngoại — 1b phải gửi kèm khi khoản vào được lô');
      expect(c.single.payload['idhousehold'], _nha, reason: 'thiếu là danh mục của nhà lên server thành danh mục riêng');
      expect(c.single.payload['idaccount'], _toi);
    });

    test('danh mục do người khác tạo không vào 1b (đã có trên server)', () async {
      await vi('v1', _nguoiKhac, _nha, sync: 'synced');
      await dm(_dmHo, _nguoiKhac, _nha, sync: 'synced');
      await gd('g', _nguoiKhac, _nha, danhMuc: _dmHo);
      final ops = await thu(nha: _nha);
      expect(cua(ops, _dmHo), isEmpty,
          reason: 'người tạo đã đẩy nó; 1b chỉ bổ sung danh mục của chính phiên (`cat.idaccount != currentAccount`)');
    });
  });
}
