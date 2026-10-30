/// Hàng của NHÀ (gia đình phần 1, schema v32) nằm CÙNG bảng với hàng riêng — mọi phép đọc "của tôi" phải bỏ chúng, kể cả
/// hàng của nhà mang ĐÚNG `idaccount` của tôi (tôi là người tạo / chủ nhà; bộ danh mục nhà sao từ bộ mặc định mang
/// `idaccount` của chủ, CÙNG TÊN bản sao riêng). Spec 2026-10-23 mục 3.3, 7.2, 9 (vế DAO); rủi ro lớn nhất mục 10.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

const _toi = 10;
const _ban = 11;
const _nha = 5;

void main() {
  late AppDatabase db;
  final ngay = DateTime(2026, 10, 20, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    Future<void> vi(String id, int acc, {int? nha, bool macDinh = false}) => db.walletDao.insert(WalletsCompanion(
          id: Value(id),
          idaccount: Value(acc),
          name: Value(id),
          isDefault: Value(macDinh),
          idhousehold: Value(nha),
          syncStatus: const Value('synced'),
          updatedAt: Value(ngay),
        ));
    await vi('vi-rieng', _toi);
    await vi('vi-nha', _toi, nha: _nha, macDinh: true);
    await vi('vi-nha-ban', _ban, nha: _nha);
    Future<void> gd(String id, String viId, DateTime luc, {int? nha}) => db.transactionDao.insert(TransactionsCompanion(
          id: Value(id),
          idaccount: const Value(_toi),
          walletId: Value(viId),
          amount: const Value(50000),
          type: const Value('chi'),
          date: Value(luc),
          idhousehold: Value(nha),
          syncStatus: const Value('synced'),
          updatedAt: Value(ngay),
        ));
    await gd('gd-rieng', 'vi-rieng', ngay);
    await gd('gd-nha', 'vi-nha', ngay.subtract(const Duration(days: 30)), nha: _nha);
    await db.budgetDao.insert(BudgetsCompanion(
        id: const Value('ns-rieng'),
        idaccount: const Value(_toi),
        amount: const Value(1),
        startDate: Value(ngay),
        updatedAt: Value(ngay)));
    await db.budgetDao.insert(BudgetsCompanion(
        id: const Value('ns-nha'),
        idaccount: const Value(_toi),
        amount: const Value(1),
        startDate: Value(ngay),
        idhousehold: const Value(_nha),
        updatedAt: Value(ngay)));
    await db.goalDao.insert(GoalsCompanion(
        id: const Value('mt-rieng'),
        idaccount: const Value(_toi),
        name: const Value('a'),
        targetAmount: const Value(1),
        targetDate: Value(ngay),
        updatedAt: Value(ngay)));
    await db.goalDao.insert(GoalsCompanion(
        id: const Value('mt-nha'),
        idaccount: const Value(_toi),
        name: const Value('b'),
        targetAmount: const Value(1),
        targetDate: Value(ngay),
        idhousehold: const Value(_nha),
        updatedAt: Value(ngay)));
    await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'dm-rieng',
        idaccount: _toi,
        name: 'Ăn uống',
        classify: 'chi',
        syncStatus: const Value('synced'),
        updatedAt: ngay));
    await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'dm-nha',
        idaccount: _toi,
        name: 'Ăn uống',
        classify: 'chi',
        idhousehold: const Value(_nha),
        syncStatus: const Value('pending'),
        updatedAt: ngay));
  });
  tearDown(() => db.close());

  group('ví', () {
    test('getAll / watchAll chỉ trả ví riêng', () async {
      expect((await db.walletDao.getAll(_toi)).map((w) => w.id), ['vi-rieng'],
          reason:
              'ví của nhà do tôi tạo mang idaccount của tôi — lọc theo tài khoản thôi là quỹ chung hiện ở Quản lý ví '
              'và cộng vào tổng tài sản cá nhân');
      expect((await db.walletDao.watchAll(_toi).first).map((w) => w.id), ['vi-rieng']);
    });

    test('ví mặc định không bao giờ là ví của nhà', () async {
      expect(await db.walletDao.getDefault(_toi), isNull);
    });

    test('bỏ cờ mặc định không đụng ví của nhà (không đẩy hàng của nhà vô cớ)', () async {
      await db.walletDao.clearDefaultExcept(idaccount: _toi, keepId: 'vi-rieng');
      final nha = (await db.walletDao.getById('vi-nha'))!;
      expect(nha.syncStatus, 'synced', reason: 'chạm hàng của nhà là một lần đẩy hàng người khác có thể đang sửa');
    });
  });

  group('giao dịch', () {
    test('getAll / watchAll / watchKhoang chỉ trả giao dịch riêng', () async {
      expect((await db.transactionDao.getAll(_toi)).map((t) => t.id), ['gd-rieng']);
      expect((await db.transactionDao.watchAll(_toi).first).map((t) => t.id), ['gd-rieng']);
      final kh = await db.transactionDao
          .watchKhoang(_toi, ngay.subtract(const Duration(days: 60)), ngay.add(const Duration(days: 1)))
          .first;
      expect(kh.map((t) => t.id), ['gd-rieng'], reason: 'Sổ giao dịch / Phân tích không được lẫn khoản của nhà');
    });

    test('tuổi dữ liệu (mốc đầu tiên) không tính khoản của nhà', () async {
      expect(await db.transactionDao.getFirstTransactionDate(_toi), ngay,
          reason: 'mẫu số của "trung bình mỗi tháng" (cua_so_nhin_lai) — khoản của nhà cũ hơn kéo dài mẫu số, im lặng');
    });

    test('viDaDung chỉ gồm ví riêng', () async {
      expect(await db.transactionDao.viDaDung(_toi), {'vi-rieng'});
    });
  });

  test('ngân sách và mục tiêu chỉ trả hàng riêng', () async {
    expect((await db.budgetDao.getAll(_toi)).map((b) => b.id), ['ns-rieng']);
    expect((await db.budgetDao.watchAll(_toi).first).map((b) => b.id), ['ns-rieng']);
    expect((await db.goalDao.getAll(_toi)).map((g) => g.id), ['mt-rieng']);
    expect((await db.goalDao.watchAll(_toi).first).map((g) => g.id), ['mt-rieng']);
  });

  group('danh mục — bộ của nhà CÙNG TÊN bản sao riêng', () {
    test('danh sách chọn danh mục chỉ có bản riêng', () async {
      // `getCategoryRows` / `watchCategoryRows` trả record `({rows, khuon})` từ 2026-10-27 (luật ẩn theo khuôn, quét 40) —
      // đọc `.rows`; `khuon` là hàng mặc định toàn cục, không liên quan nhà.
      expect((await db.categoryDao.getCategoryRows(_toi, 'chi')).rows.map((c) => c.id), ['dm-rieng']);
      expect((await db.categoryDao.watchCategoryRows(_toi, 'chi').first).rows.map((c) => c.id), ['dm-rieng']);
      expect((await db.categoryDao.getAll(_toi)).map((c) => c.id), ['dm-rieng']);
      expect((await db.categoryDao.getByClassify(_toi, 'chi')).map((c) => c.id), ['dm-rieng']);
    });

    test('quy tắc trùng tên cá nhân KHÔNG đếm danh mục của nhà', () async {
      final ids = (await db.categoryDao.getNamesInUse(_toi)).map((c) => c.id);
      expect(ids, contains('dm-rieng'), reason: 'tiền đề: danh mục riêng vẫn chiếm chỗ tên — không chỉ vắng mặt');
      expect(ids, isNot(contains('dm-nha')));
    });

    test('⚠️ bộ gieo bản sao mặc định không coi danh mục của nhà là "đã có bản sao" (spec 3.3)', () async {
      expect((await db.categoryDao.getOwnedIncludingDeleted(_toi)).map((c) => c.id), ['dm-rieng'],
          reason: 'DefaultCategorySeeder xét "đã có" bằng hàm này: danh mục nhà cùng tên bộ mặc định mà lọt vào là tài '
              'khoản lập nhà trước lượt sao đầu KHÔNG BAO GIỜ có danh mục riêng');
    });

    test('⚠️ gộp trùng tên không nuốt danh mục của nhà', () async {
      expect(await db.categoryDao.mergeDuplicatePersonalCategories(_toi), 0);
      expect(await db.categoryDao.getById('dm-nha'), isNotNull,
          reason: 'dm-nha đang pending, dm-rieng synced cùng tên — thiếu ràng nhà là dm-nha bị xoá VẬT LÝ');
    });

    test('bảng tra tên GIỮ danh mục của nhà — kể cả với thành viên không tạo nó', () async {
      expect((await db.categoryDao.getBangTraTen(_ban)).map((c) => c.id), contains('dm-nha'),
          reason: 'khoản của nhà phải có tên ở mọi máy trong nhà (spec 7.2); thành viên tra bằng idaccount của mình');
    });
  });
}
