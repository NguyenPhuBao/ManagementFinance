/// `ThemGiaoDichNguonNha` — nguồn dữ liệu form Thêm giao dịch ở chế độ nhà (gia đình 1A, Task 11, spec mục 9).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository_impl.dart';
import 'package:flowmoney/features/household/data/them_giao_dich_nguon_nha.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

class _SyncEngineGia implements SyncEngine {
  @override
  void scheduleSync() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late ThemGiaoDichNguonNha nguon;
  final moc = DateTime(2026, 11, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = DuLieuNhaRepositoryImpl(
      db: db,
      localDataSource: WalletLocalDataSourceImpl(db: db),
      soDuVi: SoDuViService(db: db, taiKhoanPhien: () => 10),
      syncEngine: _SyncEngineGia(),
    );
    nguon = ThemGiaoDichNguonNha(idNha: 5, duLieu: repo, categoryDao: db.categoryDao);

    Future<void> vi(String id, {int? nha, String status = 'active', bool daXoa = false}) =>
        db.walletDao.insert(WalletsCompanion.insert(
          id: id,
          idaccount: 10,
          name: id,
          idhousehold: Value(nha),
          status: Value(status),
          deletedAt: Value(daXoa ? moc : null),
          updatedAt: moc,
        ));
    await vi('vc', nha: 5);
    await vi('vc-luu-tru', nha: 5, status: 'inactive');
    await vi('vc-xoa', nha: 5, daXoa: true);
    await vi('vc-nha-khac', nha: 6);
    await vi('vi-rieng');

    Future<void> dm(String id, {int? nha, bool nhom = false, bool daXoa = false}) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: 10,
          name: id,
          classify: 'chi',
          idhousehold: Value(nha),
          isGroup: Value(nhom),
          deletedAt: Value(daXoa ? moc : null),
          updatedAt: moc,
        ));
    await dm('dn', nha: 5);
    await dm('dn-nhom', nha: 5, nhom: true);
    await dm('dn-xoa', nha: 5, daXoa: true);
    await dm('dn-nha-khac', nha: 6);
    await dm('dm-rieng');
    // Từ khoá của danh mục riêng: nguồn nhà không được trả.
    await db.into(db.categoryKeywords).insert(CategoryKeywordsCompanion.insert(
          id: 'k1',
          idaccount: 10,
          categoryId: 'dm-rieng',
          keyword: 'cafe',
          normalizedKeyword: 'cafe',
          createdAt: moc,
          updatedAt: moc,
        ));
  });
  tearDown(() => db.close());

  Future<List<int>> demBang() async => [
        (await db.select(db.goiYDanhMucPhanHois).get()).length,
        (await db.select(db.danhMucAiDoans).get()).length,
        (await db.select(db.categoryKeywords).get()).length,
        (await db.select(db.categories).get()).length,
      ];

  test('ví: chỉ ví chung đang hoạt động của nhà, kể cả khi có phiên cá nhân', () async {
    final ds = await nguon.napViDangDung(10);
    expect(ds.map((v) => v.id), ['vc'], reason: 'không ví riêng, không ví lưu trữ / đã xoá / của nhà khác');
    for (final id in [null, 11, 999]) {
      expect((await nguon.napViDangDung(id)).map((v) => v.id), ['vc'],
          reason: 'idaccount ($id) bị BỎ QUA: danh sách chỉ do idNha quyết định — ca ghim "không phụ thuộc id", không phải '
              'yêu cầu "chạy được khi không có phiên"');
    }
  });

  test('danh mục: chỉ của nhà (không nhóm, không đã xoá), không danh mục riêng; từ khoá rỗng', () async {
    final (ds, tuKhoa) = await nguon.napDanhMucVaTuKhoa(10);
    expect(ds.map((c) => c.id), ['dn']);
    expect(tuKhoa, isEmpty, reason: 'gợi ý từ khoá là của cá nhân');
    expect((await nguon.danhMucChonDuoc(10)).map((c) => c.id), ['dn']);
    expect(await nguon.tuKhoa(10), isEmpty, reason: 'tài khoản có từ khoá riêng nhưng chế độ nhà không dùng');
    for (final id in [null, 11, 999]) {
      final (dsKhac, tuKhoaKhac) = await nguon.napDanhMucVaTuKhoa(id);
      expect(dsKhac.map((c) => c.id), ['dn'], reason: 'idaccount ($id) bị BỎ QUA: danh mục chỉ do idNha quyết định');
      expect(tuKhoaKhac, isEmpty);
    }
  });

  test('lịch sử học rỗng: B1 không học từ khoản của nhà', () async {
    final h = nguon.napLichSu(10, dangSua: 'x');
    expect(h.viHayDung, isEmpty);
    expect(h.boPhanLoai, isNull);
    expect(h.boSoTien, isNull);
    expect(h.mauDeXuat, isNull);
  });

  test('không AI, không ngân sách cá nhân, không phản hồi, không ví theo nguồn, không ảnh', () async {
    expect(nguon.docAi, isNull);
    expect(await nguon.traNganSach(10, 'dn'), isNull);
    expect(await nguon.docPhanHoi(10), isNull);
    expect(await nguon.viTheoNguon(10, 'mb', '1234'), isNull);
    expect(await nguon.viTheoNguonChung(10, 'mb'), isNull);
    const d = DienSanBienDong(khoa: 'k', nguon: 'mb', ghiChu: 'x');
    expect(await nguon.duongDanAnh(d), isNull);
  });

  test('biến động, khoản trong sổ, món quét đều rỗng', () async {
    expect(await nguon.hangBienDongCho(10), isEmpty);
    expect(await nguon.khoanTrongSo(10), isEmpty);
    expect(await nguon.docMonQuet('a.jpg'), isEmpty);
  });

  test('mọi phép ghi không làm gì: bảng phản hồi / dấu AI / từ khoá / danh mục không đổi hàng nào', () async {
    final truoc = await demBang();
    final goiY = CategorySuggestion(
      category: CategoryEntity.fromDrift(await (db.select(db.categories)..where((t) => t.id.equals('dn'))).getSingle()),
      matchedKeyword: 'x',
    );
    nguon.ghiPhanHoi(idaccount: 10, goiY: goiY, ketQua: 'chon', chon: 'dn');
    nguon.danhDauDanhMucAi(idaccount: 10, transactionId: 't1', categoryId: 'dn');
    nguon.goDanhDauDanhMucAi(idaccount: 10, transactionId: 't1');
    await nguon.luuTuKhoa(idaccount: 10, categoryId: 'dn', tuKhoa: ['an']);
    await nguon.nhoViTheoNguon(10, 'mb', '1234', 'vc');
    await nguon.xoaHangBienDong(10, 'k');
    await nguon.xoaAnhBienLai('a.jpg');
    await nguon.xoaAnhQuet('b.jpg');
    await Future<void>.delayed(Duration.zero);
    expect(await demBang(), truoc, reason: 'chế độ nhà không học, không ghi phản hồi, không lưu từ khoá cá nhân');
  });
}
