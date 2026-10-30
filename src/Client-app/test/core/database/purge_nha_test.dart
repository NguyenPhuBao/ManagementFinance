/// Hai đường dọn dữ liệu của gia đình ở tầng CSDL (spec 2026-10-23 mục 4.6), TÁCH BẠCH:
/// 1. Đổi tài khoản trên máy — `purgeDataForOtherAccounts(keep, nhaGiu:)`: giữ hàng của nhà mà tài khoản MỚI đang ở dù
///    người tạo là ai; xoá hàng của nhà khác, kể cả hàng chính `keep` đã ghi vào nhà cũ.
/// 2. Rời nhà / bị mời ra / nhà giải tán — `xoaHangCuaNha(nha)`: chỉ hàng của đúng nhà ấy (bản sao cục bộ; server giữ
///    nguyên hoặc đã xoá mềm — không trái quy tắc 5).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

const _toi = 10;
const _cu = 11; // người đăng nhập trước trên máy này
const _nha = 5; // nhà của tôi
const _nhaKhac = 7;

void main() {
  late AppDatabase db;
  final ngay = DateTime(2026, 10, 20);

  Future<void> vi(String id, int acc, {int? nha}) => db.walletDao.insert(WalletsCompanion(
      id: Value(id), idaccount: Value(acc), name: Value(id), idhousehold: Value(nha), updatedAt: Value(ngay)));
  Future<void> gd(String id, String viId, int acc, {int? nha}) => db.transactionDao.insert(TransactionsCompanion(
      id: Value(id),
      idaccount: Value(acc),
      walletId: Value(viId),
      amount: const Value(1),
      type: const Value('chi'),
      date: Value(ngay),
      idhousehold: Value(nha),
      updatedAt: Value(ngay)));
  Future<void> dm(String id, int acc, {int? nha, bool macDinh = false}) =>
      db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: acc,
          name: id,
          classify: 'chi',
          isDefault: Value(macDinh),
          idhousehold: Value(nha),
          updatedAt: ngay));

  Future<void> ns(String id, int acc, {int? nha}) => db.budgetDao.insert(BudgetsCompanion(
      id: Value(id),
      idaccount: Value(acc),
      amount: const Value(1),
      startDate: Value(ngay),
      idhousehold: Value(nha),
      updatedAt: Value(ngay)));
  Future<void> mt(String id, int acc, {int? nha}) => db.goalDao.insert(GoalsCompanion(
      id: Value(id),
      idaccount: Value(acc),
      name: Value(id),
      targetAmount: const Value(1),
      targetDate: Value(ngay),
      idhousehold: Value(nha),
      updatedAt: Value(ngay)));
  Future<void> nhom(String id, int acc, String con, String cha) =>
      db.into(db.categoryGroupMemberships).insert(CategoryGroupMembershipsCompanion.insert(
          id: id, idaccount: acc, groupId: cha, categoryId: con, createdAt: ngay, updatedAt: ngay));

  Future<Set<String>> idNs() async => (await db.select(db.budgets).get()).map((b) => b.id).toSet();
  Future<Set<String>> idMt() async => (await db.select(db.goals).get()).map((g) => g.id).toSet();
  Future<Set<String>> idVi() async => (await db.select(db.wallets).get()).map((w) => w.id).toSet();
  Future<Set<String>> idGd() async => (await db.select(db.transactions).get()).map((t) => t.id).toSet();
  // CSDL thử tự gieo bộ danh mục mặc định `cat_*` (idaccount 0) — chỉ xét hàng do ca dựng (`dm-`).
  Future<Set<String>> idDm() async =>
      (await db.select(db.categories).get()).map((c) => c.id).where((id) => id.startsWith('dm-')).toSet();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await vi('vi-toi', _toi);
    await vi('vi-cu', _cu);
    await vi('vi-nha-cu-tao', _cu, nha: _nha); // nhà của tôi, người khác tạo
    await vi('vi-nha-khac-toi-tao', _toi, nha: _nhaKhac); // nhà cũ tôi đã rời
    await gd('gd-toi', 'vi-toi', _toi);
    await gd('gd-nha', 'vi-nha-cu-tao', _cu, nha: _nha);
    await gd('gd-nha-khac', 'vi-nha-khac-toi-tao', _toi, nha: _nhaKhac);
    await dm('dm-mac-dinh', 0, macDinh: true);
    await dm('dm-toi', _toi);
    await dm('dm-nha', _cu, nha: _nha);
    await dm('dm-nha-khac', _toi, nha: _nhaKhac);
    // Ngân sách + mục tiêu: riêng của tôi · riêng của người cũ · của nhà tôi (người cũ tạo) · của nhà đã rời.
    await ns('ns-toi', _toi);
    await ns('ns-cu', _cu);
    await ns('ns-nha-cu-tao', _cu, nha: _nha);
    await ns('ns-nha-khac-toi-tao', _toi, nha: _nhaKhac);
    await mt('mt-toi', _toi);
    await mt('mt-cu', _cu);
    await mt('mt-nha-cu-tao', _cu, nha: _nha);
    await mt('mt-nha-khac-toi-tao', _toi, nha: _nhaKhac);
  });
  tearDown(() => db.close());

  group('purgeDataForOtherAccounts', () {
    test('giữ hàng riêng của tài khoản mới + hàng của nhà đang ở; xoá phần còn lại', () async {
      await db.purgeDataForOtherAccounts(_toi, nhaGiu: _nha);
      expect(await idVi(), {'vi-toi', 'vi-nha-cu-tao'});
      expect(await idGd(), {'gd-toi', 'gd-nha'});
      expect(await idDm(), {'dm-mac-dinh', 'dm-toi', 'dm-nha'},
          reason: 'danh mục mặc định (idaccount 0) là khuôn dùng chung — giữ như trước');
      expect(await idNs(), {'ns-toi', 'ns-nha-cu-tao'},
          reason: 'ngân sách riêng của tôi KHÔNG được mất mỗi lần mở app (kể cả hàng pending chưa lên server)');
      expect(await idMt(), {'mt-toi', 'mt-nha-cu-tao'});
    });

    test('⚠️ hàng RIÊNG của tài khoản cũ bị xoá dù nhaGiu có giá trị (NULL trong phép so)', () async {
      await db.purgeDataForOtherAccounts(_toi, nhaGiu: _nha);
      expect(await idVi(), isNot(contains('vi-cu')),
          reason:
              '`idhousehold = 5` trên hàng NULL là NULL; thiếu vế isNotNull() thì NOT(… OR NULL) = NULL và hàng của '
              'người đăng nhập trước THOÁT phép xoá');
      expect(await idNs(), isNot(contains('ns-cu')), reason: 'cùng bẫy NULL ở ngân sách');
      expect(await idMt(), isNot(contains('mt-cu')), reason: 'cùng bẫy NULL ở mục tiêu');
    });

    test('chưa biết nhà của tài khoản mới (nhaGiu null) → xoá mọi hàng của nhà', () async {
      await db.purgeDataForOtherAccounts(_toi);
      expect(await idVi(), {'vi-toi'});
      expect(await idGd(), {'gd-toi'});
      expect(await idDm(), {'dm-mac-dinh', 'dm-toi'});
      expect(await idNs(), {'ns-toi'});
      expect(await idMt(), {'mt-toi'});
    });
  });

  group('xoaHangCuaNha', () {
    test('chỉ xoá hàng của đúng nhà ấy, ở cả năm bảng, kèm từ khoá của danh mục nhà', () async {
      // Quan hệ nhóm: con là danh mục nhà · cha là danh mục nhà · cả hai ngoài nhà (phải còn).
      await nhom('nd-con-nha', _toi, 'dm-nha', 'dm-toi');
      await nhom('nd-cha-nha', _toi, 'dm-toi', 'dm-nha');
      await nhom('nd-rieng', _toi, 'dm-nha-khac', 'dm-mac-dinh');
      await db.categoryDao.replaceKeywords(accountId: _toi, categoryId: 'dm-nha', keywords: ['pho'], now: ngay);
      await db.categoryDao.replaceKeywords(accountId: _toi, categoryId: 'dm-toi', keywords: ['cafe'], now: ngay);

      final n = await db.xoaHangCuaNha(_nha);

      // 1 từ khoá + 2 quan hệ nhóm + 1 giao dịch + 1 ngân sách + 1 mục tiêu + 1 danh mục + 1 ví.
      expect(n, 8);
      expect(await idVi(), {'vi-toi', 'vi-cu', 'vi-nha-khac-toi-tao'});
      expect(await idGd(), {'gd-toi', 'gd-nha-khac'});
      expect(await idDm(), {'dm-mac-dinh', 'dm-toi', 'dm-nha-khac'});
      expect(await idNs(), {'ns-toi', 'ns-cu', 'ns-nha-khac-toi-tao'}, reason: 'ngân sách riêng còn sống');
      expect(await idMt(), {'mt-toi', 'mt-cu', 'mt-nha-khac-toi-tao'}, reason: 'mục tiêu riêng còn sống');
      final nd = (await db.select(db.categoryGroupMemberships).get()).map((m) => m.id).toSet();
      expect(nd, {'nd-rieng'}, reason: 'quan hệ nhóm trỏ vào danh mục nhà đi theo, quan hệ ngoài nhà ở lại');
      expect(await db.categoryDao.getKeywords(_toi, 'dm-nha'), isEmpty,
          reason: 'từ khoá trỏ vào danh mục đã xoá là rác không ai dọn');
      expect(await db.categoryDao.getKeywords(_toi, 'dm-toi'), ['cafe']);
    });
  });
}
