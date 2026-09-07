/// `DefaultCategorySeeder` — tạo cho mỗi tài khoản bản sao riêng của bộ danh
/// mục mặc định.
///
/// Hai thứ đáng canh nhất **không phải** là "có tạo được không" mà là:
///
/// 1. **Tính luỹ đẳng.** Hàm này chạy sau *mọi* lần pull, không phải một lần
///    trong đời — đó là cách một danh mục mặc định thêm về sau tới được tài
///    khoản đã seed. Không luỹ đẳng nghĩa là mỗi lần mở app thêm một bản trùng.
/// 2. **Hàng đã xoá mềm vẫn chặn việc tạo lại.** Đây là khác biệt duy nhất với
///    `ensureMissing()` cũ, thứ đã sinh ra G16.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/services/default_category_seeder.dart';

void main() {
  late AppDatabase db;
  late DefaultCategorySeeder seeder;
  var soId = 0;

  Future<String> themMacDinh(String ten, String classify,
      {String? parentId}) async {
    final id = 'md-$ten-$classify';
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: 0,
      name: ten,
      classify: classify,
      icon: const Value('restaurant'),
      colour: const Value('#FF9800'),
      isDefault: const Value(true),
      parentId: Value(parentId),
      updatedAt: DateTime(2026, 9, 1),
    ));
    return id;
  }

  Future<void> themRieng(int idaccount, String ten, String classify) {
    return db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'rieng-$ten',
      idaccount: idaccount,
      name: ten,
      classify: classify,
      isDefault: const Value(false),
      updatedAt: DateTime(2026, 9, 1),
    ));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    soId = 0;
    seeder = DefaultCategorySeeder(db: db, sinhId: () => 'moi-${soId++}');

    // CSDL mới seed sẵn 13 danh mục mặc định. Xoá mềm chúng để mỗi test tự
    // quyết định bộ khuôn của mình — nếu không thì mọi phép đếm ở đây đều cộng
    // thêm 13, và test hoá ra đang nói về bộ seed thay vì về luật.
    for (final c in await db.categoryDao.getBackendDefaults()) {
      await db.categoryDao.softDelete(c.id);
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('tài khoản chưa có gì thì nhận đủ bản sao', () async {
    await themMacDinh('Ăn uống', 'chi');
    await themMacDinh('Lương', 'thu');

    expect(await seeder.seedForAccount(7), 2);

    final cua7 = await db.categoryDao.getOwnedIncludingDeleted(7);
    expect(cua7.map((c) => c.name).toSet(), {'Ăn uống', 'Lương'});
    expect(cua7.every((c) => !c.isDefault), isTrue,
        reason: 'Bản sao mang isDefault = true sẽ đụng thẳng '
            'uq_category_default_name_classify khi đẩy lên.');
    expect(cua7.every((c) => c.syncStatus == 'pending'), isTrue,
        reason: 'Không đánh dấu pending thì bản sao không bao giờ lên server, '
            'và cả tính năng chỉ tồn tại trên một máy.');
    expect(cua7.every((c) => c.idaccount == 7), isTrue);
  });

  test('bản sao giữ nguyên biểu tượng và màu của khuôn', () async {
    await themMacDinh('Ăn uống', 'chi');

    await seeder.seedForAccount(7);

    final ban = (await db.categoryDao.getOwnedIncludingDeleted(7)).single;
    expect(ban.icon, 'restaurant');
    expect(ban.colour, '#FF9800');
  });

  test('chạy lần hai không tạo thêm gì', () async {
    await themMacDinh('Ăn uống', 'chi');
    await seeder.seedForAccount(7);

    expect(await seeder.seedForAccount(7), 0,
        reason: 'Bước này chạy sau MỌI lần pull, không phải một lần trong '
            'đời. Không luỹ đẳng là mỗi lần mở app thêm một bản trùng.');
    expect(await db.categoryDao.getOwnedIncludingDeleted(7), hasLength(1));
  });

  test('bản sao đã bị xoá mềm thì KHÔNG tạo lại', () async {
    await themMacDinh('Ăn uống', 'chi');
    await seeder.seedForAccount(7);
    final ban = (await db.categoryDao.getOwnedIncludingDeleted(7)).single;
    await db.categoryDao.softDelete(ban.id);

    expect(await seeder.seedForAccount(7), 0,
        reason: 'Đây là phép canh G16. Đếm sót hàng đã xoá thì danh mục người '
            'dùng vừa xoá mọc lại ở mỗi lần mở app, và mỗi lần mọc lại là một '
            'thao tác đẩy hỏng vĩnh viễn.');
  });

  test('danh mục người dùng tự tạo trùng tên cũng chặn việc tạo bản sao',
      () async {
    await themMacDinh('Ăn uống', 'chi');
    await themRieng(7, 'ăn  uống', 'chi'); // khác hoa thường và khoảng trắng

    expect(await seeder.seedForAccount(7), 0,
        reason: 'normalizeCategoryName gom khoảng trắng và hạ chữ thường. Tạo '
            'thêm bản thứ hai là vi phạm quy tắc 7 ở client và '
            'uq_category_owner_name_classify khi đẩy lên.');
  });

  test('cùng tên nhưng KHÁC loại thì vẫn tạo bản sao', () async {
    await themMacDinh('Thưởng', 'thu');
    await themRieng(7, 'Thưởng', 'chi');

    expect(await seeder.seedForAccount(7), 1,
        reason: 'Phép đối chiếu ở đây so cả tên LẪN classify. Khác loại là hai '
            'khái niệm khác nhau, và uq_category_owner_name_classify cũng cho '
            'chúng cùng tồn tại.');
  });

  test('chưa pull được bộ mặc định thì không tạo gì', () async {
    expect(await seeder.seedForAccount(7), 0,
        reason: 'Tạo mù khi CSDL cục bộ chưa có bộ mặc định chính là G14: trên '
            'máy mới nó sinh đúng những bản trùng tên với bản đã có trên '
            'server, đẩy lên hỏng vĩnh viễn và kéo cả engine vào giãn cách.');
  });

  test('idaccount không hợp lệ thì không tạo gì', () async {
    await themMacDinh('Ăn uống', 'chi');

    expect(await seeder.seedForAccount(0), 0);
    expect(await seeder.seedForAccount(-1), 0,
        reason: 'Danh tính chỉ đến từ phiên đăng nhập; 0 không phải "chưa '
            'biết" mà là một giá trị không được phép ghi dữ liệu.');
  });

  test('bản sao KHÔNG thuộc nhóm nào', () async {
    await themMacDinh('Ăn uống', 'chi', parentId: 'nhom-1');

    await seeder.seedForAccount(7);

    final ban = (await db.categoryDao.getOwnedIncludingDeleted(7)).single;
    expect(ban.parentId, isNull,
        reason: 'CategoryGroupMemberships không đồng bộ được (G10), nên kế '
            'thừa nhóm là chép một thứ vốn đã không đi đâu.');
  });

  test('từ khoá của bản mặc định được chép sang bản sao', () async {
    final macDinh = await themMacDinh('Ăn uống', 'chi');
    await db.categoryDao.replaceKeywords(
      accountId: 7,
      categoryId: macDinh,
      keywords: ['cơm', 'phở'],
      now: DateTime(2026, 9, 7),
    );

    await seeder.seedForAccount(7);

    final ban = (await db.categoryDao.getOwnedIncludingDeleted(7)).single;
    expect((await db.categoryDao.getKeywords(7, ban.id)).toSet(),
        {'cơm', 'phở'},
        reason: '13/18 danh mục mặc định có từ khoá; mất chúng là bộ gợi ý kém '
            'hẳn đi mà không có lỗi nào báo ra.');
  });

  test('khuôn không có từ khoá thì bản sao cũng không có', () async {
    await themMacDinh('Ăn uống', 'chi');

    await seeder.seedForAccount(7);

    final ban = (await db.categoryDao.getOwnedIncludingDeleted(7)).single;
    expect(await db.categoryDao.getKeywords(7, ban.id), isEmpty);
  });
}
