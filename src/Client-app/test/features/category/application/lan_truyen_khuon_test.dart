/// `LanTruyenKhuon` — Admin-web sửa danh mục mặc định thì bản sao của tài khoản đổi theo (spec 2026-10-27 mục 5).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/category/application/default_category_seeder.dart';
import 'package:flowmoney/features/category/application/lan_truyen_khuon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LanTruyenKhuon lan;
  final cu = DateTime(2026, 9, 1);
  final bayGio = DateTime(2026, 10, 27, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lan = LanTruyenKhuon(db: db, now: () => bayGio);
  });
  tearDown(() => db.close());

  Future<void> hang(String id, String ten,
          {int idaccount = 10, String classify = 'chi', String icon = 'fuel', bool xoa = false, bool khuon = false}) =>
      db.categoryDao.insert(CategoriesCompanion.insert(
        id: id,
        idaccount: khuon ? 0 : idaccount,
        name: ten,
        classify: classify,
        icon: Value(icon),
        isDefault: Value(khuon),
        isDeleted: Value(xoa),
        deletedAt: xoa ? Value(cu) : const Value.absent(),
        syncStatus: const Value('synced'),
        updatedAt: cu,
      ));

  ThayDoiKhuon doi({
    String tenCu = 'Thử khuôn',
    String tenMoi = 'Thử khuôn',
    String iconCu = 'fuel',
    String iconMoi = 'fuel',
    List<String> tuKhoaCu = const [],
    List<String> tuKhoaMoi = const [],
  }) =>
      ThayDoiKhuon(
          id: 'k1', loai: 'chi', tenCu: tenCu, tenMoi: tenMoi, iconCu: iconCu, iconMoi: iconMoi,
          tuKhoaCu: tuKhoaCu, tuKhoaMoi: tuKhoaMoi);

  Future<Category> doc(String id) async => (await db.categoryDao.getById(id))!;

  test('⭐ đổi tên: bản sống đổi + pending; bản ĐÃ XOÁ đổi tên CỤC BỘ — không pending, giữ updatedAt', () async {
    await hang('sao', 'Thử khuôn');
    await hang('sao_xoa', 'Thử khuôn', xoa: true);

    expect(await lan.apDung(10, [doi(tenMoi: 'Thử khuôn mới')]), 1);

    final song = await doc('sao');
    expect([song.name, song.syncStatus, song.updatedAt], ['Thử khuôn mới', 'pending', bayGio]);
    final xoa = await doc('sao_xoa');
    expect(xoa.name, 'Thử khuôn mới', reason: 'Bỏ sót là bộ tạo bản sao thấy tên mới trống và đẻ lại thứ đã xoá (G16).');
    expect([xoa.syncStatus, xoa.updatedAt], ['synced', cu],
        reason: 'Hàng xoá mà pending bị đẩy thành delete → server bỏ tên mới, kéo về tên cũ đè lên (spec mục 5 bước 6).');
  });

  test('tài khoản đã có danh mục mang tên mới → bỏ qua đổi tên', () async {
    await hang('sao', 'Thử khuôn');
    await hang('rieng', 'Thử khuôn mới');
    expect(await lan.apDung(10, [doi(tenMoi: 'Thử khuôn mới')]), 0);
    expect((await doc('sao')).name, 'Thử khuôn');
  });

  test('bản người dùng đã tự đổi tên, khác loại, tài khoản khác → không đụng', () async {
    await hang('doi_ten', 'Thử khuôn xe máy');
    await hang('khac_loai', 'Thử khuôn', classify: 'thu');
    await hang('tk_khac', 'Thử khuôn', idaccount: 99);
    expect(await lan.apDung(10, [doi(tenMoi: 'Thử khuôn mới', iconMoi: 'gas')]), 0);
    expect((await doc('doi_ten')).name, 'Thử khuôn xe máy');
    expect((await doc('khac_loai')).name, 'Thử khuôn');
    expect((await doc('tk_khac')).name, 'Thử khuôn');
  });

  test('⭐ biểu tượng chỉ đổi khi bản sao còn đúng biểu tượng cũ', () async {
    await hang('sao', 'Thử khuôn', icon: 'fuel');
    await hang('tu_doi', 'Thử khuôn 2', icon: 'star');
    expect(await lan.apDung(10, [doi(iconMoi: 'gas')]), 1);
    expect((await doc('sao')).icon, 'gas');

    await lan.apDung(10, [doi(tenCu: 'Thử khuôn 2', tenMoi: 'Thử khuôn 2', iconMoi: 'gas')]);
    expect((await doc('tu_doi')).icon, 'star', reason: 'Người dùng đã tự đổi biểu tượng — giữ.');
  });

  test('⭐ từ khoá chỉ THÊM phần mới; không xoá từ người dùng gõ; khuôn nhận bộ mới', () async {
    await hang('k1', 'Thử khuôn', khuon: true);
    await hang('sao', 'Thử khuôn');
    await db.categoryDao.replaceKeywords(accountId: 10, categoryId: 'sao', keywords: ['cay xang'], now: cu);
    await db.categoryDao.replaceKeywords(accountId: 10, categoryId: 'k1', keywords: ['xang'], now: cu);

    expect(await lan.apDung(10, [doi(tuKhoaCu: ['xang'], tuKhoaMoi: ['xang', 'petrolimex'])]), 1);

    // `getKeywords` xếp theo createdAt — các hàng một lần `replaceKeywords` cùng mốc, nên so KHÔNG theo thứ tự.
    expect(await db.categoryDao.getKeywords(10, 'sao'), unorderedEquals(['cay xang', 'petrolimex']),
        reason: '"xang" người dùng đã bỏ khỏi bản sao — không được thêm lại; chỉ thêm phần admin MỚI thêm.');
    expect((await doc('sao')).syncStatus, 'pending', reason: 'Từ khoá đi trong payload danh mục — phải đẩy lên.');
    expect(await db.categoryDao.getKeywords(10, 'k1'), unorderedEquals(['xang', 'petrolimex']));
  });

  test('luỹ đẳng — áp lần hai không ghi gì', () async {
    await hang('sao', 'Thử khuôn');
    final d = doi(tenMoi: 'Thử khuôn mới', iconMoi: 'gas', tuKhoaMoi: ['petrolimex']);
    expect(await lan.apDung(10, [d]), 1);
    expect(await lan.apDung(10, [d]), 0);
  });

  test('⭐ thứ tự cổng: lan truyền TRƯỚC tạo bản sao — đổi tên khuôn không đẻ bản thứ hai', () async {
    await hang('k1', 'Thử khuôn mới', khuon: true); // hàng khuôn đã mang tên mới (kéo về vừa ghi đè)
    await hang('sao', 'Thử khuôn');

    await viecSauKeoVeDanhMuc(lan, DefaultCategorySeeder(db: db), 10, [doi(tenMoi: 'Thử khuôn mới')]);

    final ten = (await db.categoryDao.getOwnedIncludingDeleted(10)).where((c) => !c.isDeleted).map((c) => c.name);
    expect(ten.where((t) => t == 'Thử khuôn mới'), hasLength(1));
    expect(ten, isNot(contains('Thử khuôn')),
        reason: 'Tạo bản sao chạy trước là thấy tên mới trống → bản thứ hai, rồi lan truyền bỏ qua vì tên đã có.');
  });
}
