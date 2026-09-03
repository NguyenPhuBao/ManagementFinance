/// Canh chừng đường đồng bộ của 5 danh mục mà bộ mặc định backend không có.
///
/// Trước đây chúng là danh mục MẶC ĐỊNH ở client (idaccount = 0). Danh mục mặc
/// định không được đẩy lên, còn `_resolveCategoryId` thì ánh xạ chúng sang UUID
/// backend bằng cách so tên — không có bản nào cùng tên nên trả null, và mọi
/// giao dịch dùng chúng bị hoãn đẩy VĨNH VIỄN mà không báo gì.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/category/category_name.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/services/personal_default_categories.dart';

void main() {
  late AppDatabase db;
  late PersonalDefaultCategories service;
  const accountId = 7;

  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PersonalDefaultCategories(db: db);
  });

  tearDown(() => db.close());

  Future<Transaction> txById(String id) async =>
      (await db.transactionDao.getAll(accountId)).firstWhere((t) => t.id == id);

  Future<List<Category>> ownedOf(int account) async =>
      (await db.categoryDao.getNamesInUse(account))
          .where((c) => !c.isDefault)
          .toList();

  test('Tạo đủ 5 danh mục cá nhân, id là UUID và ở trạng thái chờ đẩy', () async {
    await service.ensureForAccount(accountId);

    final owned = await ownedOf(accountId);
    expect(owned.map((c) => c.name).toSet(), {
      'Chi khác',
      'Thu khác',
      'Làm thêm',
      'Trả nợ',
      'Thu nợ',
    });

    for (final c in owned) {
      expect(uuidRegex.hasMatch(c.id), isTrue,
          reason: 'Danh mục người dùng có id dạng `cat_*` sẽ bị '
              '_resolveCategoryId trả null và lại kẹt y như cũ.');
      expect(c.idaccount, accountId);
      expect(c.isDefault, isFalse);
      expect(c.syncStatus, 'pending',
          reason: 'Phải vào hàng đợi đẩy, nếu không chúng chỉ nằm ở máy này.');
    }
  });

  test('Gọi nhiều lần không sinh thêm bản trùng', () async {
    await service.ensureForAccount(accountId);
    await service.ensureForAccount(accountId);

    expect((await ownedOf(accountId)).length, 5);
  });

  test('Không làm gì khi chưa có phiên đăng nhập', () async {
    await service.ensureForAccount(0);
    await service.ensureForAccount(-1);

    expect(await ownedOf(0), isEmpty);
  });

  group('Dữ liệu cũ từ bản client trước', () {
    Future<void> seedLegacy() => db.categoryDao.insert(
          CategoriesCompanion.insert(
            id: 'cat_other_chi',
            idaccount: 0,
            name: 'Chi khác',
            classify: 'chi',
            isDefault: const Value(true),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    Future<void> seedWallet() => db.walletDao.insert(WalletsCompanion.insert(
          id: 'w-1',
          idaccount: accountId,
          name: 'Tiền mặt',
          updatedAt: DateTime(2026, 9, 1),
        ));

    Future<void> seedTransaction(String categoryId) =>
        db.transactionDao.insert(TransactionsCompanion.insert(
          id: 'tx-1',
          walletId: 'w-1',
          idaccount: accountId,
          amount: 50000,
          type: 'chi',
          date: DateTime(2026, 9, 2),
          categoryId: Value(categoryId),
          syncStatus: const Value('pending'),
          updatedAt: DateTime(2026, 9, 2),
        ));

    test('Giao dịch được chuyển sang danh mục cá nhân mới', () async {
      await seedLegacy();
      await seedWallet();
      await seedTransaction('cat_other_chi');

      await service.ensureForAccount(accountId);

      final moved = await txById('tx-1');
      final personal = (await ownedOf(accountId))
          .firstWhere((c) => c.name == 'Chi khác');

      expect(moved.categoryId, personal.id,
          reason: 'Không chuyển thì giao dịch trỏ vào một hàng vừa bị xoá — '
              'đúng lỗi 11.6.');
      expect(uuidRegex.hasMatch(moved.categoryId!), isTrue);
    });

    test('Hàng seed cũ bị xoá mềm SAU khi đã chuyển xong', () async {
      await seedLegacy();
      await seedWallet();
      await seedTransaction('cat_other_chi');

      await service.ensureForAccount(accountId);

      expect((await db.categoryDao.getById('cat_other_chi'))!.isDeleted, isTrue);
    });

    test('Không tạo bản mới nếu tài khoản đã có danh mục cùng tên', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: '22222222-2222-4222-8222-222222222222',
        idaccount: accountId,
        name: 'chi  KHÁC',
        classify: 'chi',
        updatedAt: DateTime(2026, 9, 1),
      ));
      await seedLegacy();
      await seedWallet();
      await seedTransaction('cat_other_chi');

      await service.ensureForAccount(accountId);

      final sameName = (await ownedOf(accountId))
          .where((c) => normalizeCategoryName(c.name) == 'chi khác')
          .toList();
      expect(sameName, hasLength(1),
          reason: 'So tên bỏ qua hoa/thường và khoảng trắng, nên "chi  KHÁC" '
              'đã là "Chi khác" — tạo thêm sẽ vi phạm quy tắc trùng tên.');
      expect((await txById('tx-1')).categoryId,
          '22222222-2222-4222-8222-222222222222');
    });
  });
}
