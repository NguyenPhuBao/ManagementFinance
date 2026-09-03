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
    await service.ensureMissing(accountId);

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
    await service.ensureMissing(accountId);
    await service.ensureMissing(accountId);

    expect((await ownedOf(accountId)).length, 5);
  });

  test('Không làm gì khi chưa có phiên đăng nhập', () async {
    await service.ensureMissing(0);
    await service.ensureMissing(-1);
    await service.convertLegacyRows(0);
    await service.convertLegacyRows(-1);

    expect(await ownedOf(0), isEmpty);
  });

  // ── G14: tạo danh mục phải chờ tới SAU lần pull đầu tiên ──────────────────
  //
  // Đo được trên app thật 2026-09-03. Đăng nhập trên một máy **chưa từng chạy
  // app** vào tài khoản đã có sẵn 5 danh mục này ở backend: client sinh lại
  // đúng 5 danh mục đó với UUID mới, đẩy lên thì vi phạm quy tắc trùng tên,
  // backend trả `failed` **kèm message rỗng** nên `_classifyFailure` xếp vào
  // `transient` và thử lại vĩnh viễn. Mọi chu kỳ đồng bộ kết thúc ở trạng thái
  // hỏng → giãn cách luỹ tiến → **mọi thay đổi khác** bị đẩy chậm theo.
  //
  // Nguyên nhân không phải phép kiểm trùng sai, mà là nó chạy sai thời điểm.

  group('Máy mới: không sinh bản trùng với bản đã có trên backend', () {
    /// Đúng trạng thái SQLite sau lần pull đầu tiên trên một máy mới.
    Future<void> pullVe(String id, String name, String classify) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: accountId,
          name: name,
          classify: classify,
          isDefault: const Value(false),
          syncStatus: const Value('synced'),
          updatedAt: DateTime(2026, 9, 1),
        ));

    Future<void> pullDu5() async {
      await pullVe('3f7bd9b9-1f76-4632-b996-99556415d994', 'Chi khác', 'chi');
      await pullVe('c69de4dd-8d77-474a-823b-5b6346284fc5', 'Thu khác', 'thu');
      await pullVe('7fa9d024-91d7-49ed-8866-f73e7146e9fc', 'Làm thêm', 'thu');
      await pullVe('dac4608a-dc42-41ad-bf56-e636f5c6312c', 'Trả nợ', 'vay_no');
      await pullVe('59ada9c9-4be6-44ca-934a-2bc5af869431', 'Thu nợ', 'vay_no');
    }

    test('convertLegacyRows trên máy sạch KHÔNG tạo gì cả', () async {
      await service.convertLegacyRows(accountId);

      expect(await ownedOf(accountId), isEmpty,
          reason: 'Đây là bản vá chính. Hàm này chạy TRƯỚC lần pull đầu tiên, '
              'lúc SQLite còn rỗng — tạo danh mục ở đây là tạo mù, và trên máy '
              'mới nó đẻ ra đúng những bản trùng tên làm hỏng đồng bộ.');
      expect(await db.categoryDao.getPending(accountId), isEmpty);
    });

    test('ensureMissing sau khi pull đủ 5 thì không tạo thêm bản nào', () async {
      await pullDu5();

      await service.ensureMissing(accountId);

      expect(await ownedOf(accountId), hasLength(5),
          reason: 'Mỗi bản thừa là một thao tác đẩy hỏng VĨNH VIỄN, và giãn '
              'cách luỹ tiến kéo chậm đồng bộ của mọi thực thể khác.');
      expect(await db.categoryDao.getPending(accountId), isEmpty,
          reason: 'Không tạo gì thì cũng không có gì chờ đẩy.');
    });

    test('pull về một phần thì chỉ tạo đúng phần còn thiếu', () async {
      await pullVe('3f7bd9b9-1f76-4632-b996-99556415d994', 'Chi khác', 'chi');
      await pullVe('c69de4dd-8d77-474a-823b-5b6346284fc5', 'Thu khác', 'thu');

      await service.ensureMissing(accountId);

      expect(await ownedOf(accountId), hasLength(5));
      expect(await db.categoryDao.getPending(accountId), hasLength(3));
    });

    test('đúng thứ tự đầu-cuối: convert (rỗng) → pull → ensureMissing',
        () async {
      await service.convertLegacyRows(accountId);
      expect(await ownedOf(accountId), isEmpty);

      await pullDu5();
      await service.ensureMissing(accountId);

      expect(await ownedOf(accountId), hasLength(5));
      expect(await db.categoryDao.getPending(accountId), isEmpty,
          reason: 'Không sinh thao tác đẩy nào. Trước bản vá, chỗ này là 5 '
              'thao tác hỏng vĩnh viễn.');
    });

    test('hàng seed cũ tự khớp tên với chính nó thì không được dùng làm đích',
        () async {
      // Hàng seed bình thường mang isDefault = true nên đã bị loại sẵn. Test
      // này canh trường hợp máy nào đó giữ nó ở dạng danh mục RIÊNG: khi ấy
      // phép so tên khớp chính nó, dữ liệu bị "chuyển" về đúng chỗ cũ rồi hàng
      // đó bị xoá mềm ngay sau — giao dịch kết thúc ở một danh mục đã xoá.
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'cat_other_chi',
        idaccount: accountId,
        name: 'Chi khác',
        classify: 'chi',
        isDefault: const Value(false),
        updatedAt: DateTime(2026, 9, 1),
      ));
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-1',
        idaccount: accountId,
        name: 'Tiền mặt',
        updatedAt: DateTime(2026, 9, 1),
      ));
      await db.transactionDao.insert(TransactionsCompanion.insert(
        id: 'tx-1',
        walletId: 'w-1',
        idaccount: accountId,
        amount: 50000,
        type: 'chi',
        date: DateTime(2026, 9, 2),
        categoryId: const Value('cat_other_chi'),
        updatedAt: DateTime(2026, 9, 2),
      ));

      await service.convertLegacyRows(accountId);

      final moved = await txById('tx-1');
      expect(moved.categoryId, isNot('cat_other_chi'));
      expect(uuidRegex.hasMatch(moved.categoryId!), isTrue);
      final dich = (await db.categoryDao.getById(moved.categoryId!))!;
      expect(dich.isDeleted, isFalse,
          reason: 'Giao dịch không được trỏ vào một danh mục vừa bị xoá mềm.');
    });
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

      await service.convertLegacyRows(accountId);

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

      await service.convertLegacyRows(accountId);

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

      await service.convertLegacyRows(accountId);

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
