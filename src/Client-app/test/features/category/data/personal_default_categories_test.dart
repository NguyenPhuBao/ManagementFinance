/// Canh chừng đường đi của 5 danh mục mà bộ mặc định backend từng không có.
///
/// **Chặng một (lịch sử).** Chúng là danh mục MẶC ĐỊNH ở client (idaccount = 0).
/// Danh mục mặc định không được đẩy lên, còn `_resolveCategoryId` thì ánh xạ
/// chúng sang UUID backend bằng cách so tên — không có bản nào cùng tên nên trả
/// null, và mọi giao dịch dùng chúng bị hoãn đẩy VĨNH VIỄN mà không báo gì. Cách
/// chữa lúc ấy: tạo lại thành danh mục RIÊNG của từng tài khoản.
///
/// **Chặng hai (2026-09-05).** Backend đã thêm đúng 5 hàng ấy vào bộ mặc định
/// của nó (`Create_by = 1`, `Is_default = true`), nên mỗi tài khoản không cần
/// giữ bản riêng nữa. `foldIntoBackendDefaults` gộp bản riêng vào bản mặc định
/// rồi xoá mềm bản riêng. Việc này cũng rút chân G16: danh mục mặc định là toàn
/// cục, không thuộc tài khoản nào, nên không còn gì để "mọc lại" mỗi lần mở app.
///
/// Gộp là thao tác **phá huỷ** — nó xoá một hàng của người dùng — nên mọi test ở
/// đây canh đúng một câu hỏi: *khi nào thì KHÔNG được gộp*.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('Không làm gì khi chưa có phiên đăng nhập', () async {
    await service.foldIntoBackendDefaults(0);
    await service.foldIntoBackendDefaults(-1);
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

    test('pull về 5 bản riêng, backend CHƯA có bộ mặc định → không đụng gì',
        () async {
      await pullDu5();

      await service.foldIntoBackendDefaults(accountId);

      expect(await ownedOf(accountId), hasLength(5),
          reason: 'Không thấy bản mặc định thì không có đích để gộp vào. Xoá '
              'bản riêng lúc này là làm người dùng mất danh mục đang dùng.');
      expect(await db.categoryDao.getPending(accountId), isEmpty,
          reason: 'Không đụng gì thì cũng không có gì chờ đẩy.');
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

  // ── Gộp bản riêng vào bộ mặc định của backend (2026-09-05) ────────────────
  //
  // Backend đã có đủ 5 hàng trong bộ mặc định, nên mỗi tài khoản không cần giữ
  // bản riêng nữa. Gộp là thao tác PHÁ HUỶ — nó xoá mềm một hàng của người dùng
  // và dời mọi tham chiếu — nên phần lớn nhóm này canh các ca **không được gộp**.

  group('foldIntoBackendDefaults', () {
    const idMacDinhChiKhac = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
    const idRiengChiKhac = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

    /// Đúng trạng thái sau khi pull một hàng thuộc bộ mặc định của backend:
    /// `is_default = true` được `sync_engine` quy về `idaccount = 0`.
    Future<void> macDinh(String id, String name, String classify) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: 0,
          name: name,
          classify: classify,
          isDefault: const Value(true),
          syncStatus: const Value('synced'),
          updatedAt: DateTime(2026, 9, 5),
        ));

    Future<void> rieng(String id, String name, String classify,
            {int? account}) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: account ?? accountId,
          name: name,
          classify: classify,
          isDefault: const Value(false),
          syncStatus: const Value('synced'),
          updatedAt: DateTime(2026, 9, 1),
        ));

    Future<void> viVaGiaoDich(String categoryId) async {
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
        categoryId: Value(categoryId),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 9, 2),
      ));
    }

    test('có cả hai: giao dịch dời sang bản mặc định, bản riêng xoá MỀM',
        () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng(idRiengChiKhac, 'Chi khác', 'chi');
      await viVaGiaoDich(idRiengChiKhac);

      await service.foldIntoBackendDefaults(accountId);

      expect((await txById('tx-1')).categoryId, idMacDinhChiKhac,
          reason: 'Xoá bản riêng mà không dời tham chiếu là để giao dịch trỏ '
              'vào một danh mục đã xoá — đúng lỗi 11.6.');

      final cu = (await db.categoryDao.getById(idRiengChiKhac))!;
      expect(cu.isDeleted, isTrue);
      expect(cu.deletedAt, isNotNull);
      expect(cu.syncStatus, 'pending',
          reason: 'Cờ xoá phải đi lên server qua đường đồng bộ thường. Không '
              'được xoá cứng ở PostgreSQL — quy tắc 5.');
    });

    test('ngân sách và hoá đơn cũng được dời theo', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng(idRiengChiKhac, 'Chi khác', 'chi');
      await db.budgetDao.insert(BudgetsCompanion.insert(
        id: 'b-1',
        idaccount: accountId,
        amount: 2000000,
        startDate: DateTime(2026, 9, 1),
        categoryId: const Value(idRiengChiKhac),
        updatedAt: DateTime(2026, 9, 1),
      ));
      await db.billDao.insert(BillsCompanion.insert(
        id: 'hd-1',
        idaccount: accountId,
        name: 'Tiền điện',
        amount: 300000,
        dueDate: DateTime(2026, 9, 20),
        categoryId: const Value(idRiengChiKhac),
        updatedAt: DateTime(2026, 9, 1),
      ));

      await service.foldIntoBackendDefaults(accountId);

      expect((await db.budgetDao.getById('b-1'))!.categoryId,
          idMacDinhChiKhac,
          reason: 'Ba bảng đều có cột categoryId. Bỏ sót một bảng thì hạn mức '
              'hoặc hoá đơn trỏ vào danh mục đã xoá, và hỏng im lặng.');
      expect((await db.billDao.getById('hd-1'))!.categoryId,
          idMacDinhChiKhac);
    });

    test('KHÔNG có bản mặc định thì không đụng gì', () async {
      await rieng(idRiengChiKhac, 'Chi khác', 'chi');
      await viVaGiaoDich(idRiengChiKhac);

      await service.foldIntoBackendDefaults(accountId);

      expect((await db.categoryDao.getById(idRiengChiKhac))!.isDeleted, isFalse,
          reason: 'Backend chưa có hàng, hoặc pull hỏng. Xoá bản riêng lúc này '
              'là làm người dùng mất danh mục đang dùng mà không có gì thay.');
      expect((await txById('tx-1')).categoryId, idRiengChiKhac);
    });

    test('chỉ có bản mặc định thì không làm gì', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');

      await service.foldIntoBackendDefaults(accountId);

      expect(await ownedOf(accountId), isEmpty,
          reason: 'Đây là trạng thái đích của tài khoản mới — không tạo bản '
              'riêng nào nữa, đó chính là điểm của thay đổi này.');
      expect(await db.categoryDao.getPending(accountId), isEmpty);
    });

    test('chạy lần hai không đổi gì thêm', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng(idRiengChiKhac, 'Chi khác', 'chi');
      await viVaGiaoDich(idRiengChiKhac);

      await service.foldIntoBackendDefaults(accountId);
      final sauLan1 = (await db.categoryDao.getById(idRiengChiKhac))!.updatedAt;

      await service.foldIntoBackendDefaults(accountId);

      expect((await db.categoryDao.getById(idRiengChiKhac))!.updatedAt,
          sauLan1,
          reason: 'Hàm chạy ở MỖI lần đăng nhập. Chạm lại vào hàng đã xoá sẽ '
              'đội updatedAt lên và sinh một thao tác đẩy thừa mỗi lần mở app.');
      expect((await txById('tx-1')).categoryId, idMacDinhChiKhac);
    });

    test('so tên bỏ qua hoa/thường và khoảng trắng thừa', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng(idRiengChiKhac, 'chi  KHÁC', 'chi');

      await service.foldIntoBackendDefaults(accountId);

      expect((await db.categoryDao.getById(idRiengChiKhac))!.isDeleted, isTrue,
          reason: 'normalizeCategoryName là định nghĩa DUY NHẤT của phép so '
              'tên. Bỏ sót thì bản riêng nằm lại và người dùng thấy hai mục '
              'trông y hệt nhau.');
    });

    test('classify khác thì KHÔNG gộp', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng(idRiengChiKhac, 'Chi khác', 'thu');
      await viVaGiaoDich(idRiengChiKhac);

      await service.foldIntoBackendDefaults(accountId);

      expect((await db.categoryDao.getById(idRiengChiKhac))!.isDeleted, isFalse,
          reason: 'Quy tắc trùng tên không tính classify, nên một danh mục do '
              'người dùng TỰ tạo có thể trùng tên mà khác loại. Gộp nó vào bản '
              'mặc định là âm thầm đổi loại của mọi giao dịch bên trong.');
      expect((await txById('tx-1')).categoryId, idRiengChiKhac);
    });

    test('không đụng danh mục của tài khoản khác', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng('cccccccc-3333-4333-8333-cccccccccccc', 'Chi khác', 'chi',
          account: 99);

      await service.foldIntoBackendDefaults(accountId);

      final cuaNguoiKhac = (await db.categoryDao
          .getById('cccccccc-3333-4333-8333-cccccccccccc'))!;
      expect(cuaNguoiKhac.isDeleted, isFalse,
          reason: 'getNamesInUse trả cả hàng mặc định, nên phép lọc theo tài '
              'khoản phải nằm ở chính chỗ tìm bản riêng.');
    });

    test('danh mục tự tạo có tên ngoài danh sách thì không bị đụng', () async {
      await macDinh(idMacDinhChiKhac, 'Chi khác', 'chi');
      await rieng('dddddddd-4444-4444-8444-dddddddddddd', 'Cà phê', 'chi');

      await service.foldIntoBackendDefaults(accountId);

      expect(
          (await db.categoryDao
                  .getById('dddddddd-4444-4444-8444-dddddddddddd'))!
              .isDeleted,
          isFalse);
    });
  });
}
