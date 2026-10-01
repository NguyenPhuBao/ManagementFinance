// C1 — nguồn dữ liệu và đường ghi mặc định của màn Gắn danh mục nhanh, chạy trên CSDL bộ nhớ thật.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/gan_danh_muc_nguon.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/domain/gan_hang_loat.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGhiLai implements TransactionRepository {
  final lanGoi = <(TransactionEntity, TransactionEntity)>[];
  @override
  Future<void> updateTransaction(TransactionEntity before, TransactionEntity after) async =>
      lanGoi.add((before, after));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StoreGhiLai implements GoiYPhanHoiStore {
  final lanGhi = <({CategorySuggestion goiY, String ketQua, String? chon})>[];
  List<PhanHoiGoiY> daCo = const [];
  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) async =>
      lanGhi.add((goiY: goiY, ketQua: ketQua, chon: chonCategoryId));
  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => daCo;
}

void main() {
  late AppDatabase db;
  var dem = 0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final acc in [7, 99]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-$acc',
        idaccount: acc,
        name: acc == 7 ? 'Tiền mặt' : 'Ví khác',
        updatedAt: DateTime(2026, 9, 1),
      ));
    }
    for (final (id, ten, loai) in [('c-dc', 'Di chuyển', 'chi'), ('c-an', 'Ăn uống', 'chi'), ('c-luong', 'Lương', 'thu')]) {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: id,
        idaccount: 7,
        name: ten,
        classify: loai,
        updatedAt: DateTime(2026, 8, 21),
      ));
    }
  });
  tearDown(() => db.close());

  Future<String> them(String note, {String? cat, int acc = 7, String type = 'chi', DateTime? ngay}) async {
    final id = 'gd-${dem++}';
    final d = ngay ?? DateTime(2026, 9, 10);
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: id,
      walletId: 'w-$acc',
      idaccount: acc,
      categoryId: Value(cat),
      amount: 45000,
      type: type,
      note: Value(note),
      date: d,
      updatedAt: d,
    ));
    return id;
  }

  group('taiDuLieuGan', () {
    test('học B1 từ chính sổ, đoán cho khoản chưa gắn, kèm tên ví', () async {
      for (var i = 0; i < 8; i++) {
        await them('grab ve nha', cat: 'c-dc', ngay: DateTime(2026, 8, 1 + i));
      }
      for (var i = 0; i < 4; i++) {
        await them('com trua', cat: 'c-an', ngay: DateTime(2026, 8, 10 + i));
      }
      await them('grab');
      await them('xyz');
      await them('grab', acc: 99);

      final kq = await taiDuLieuGan(
        db: db,
        danhMuc: CategoryManagementRepositoryImpl(db: db),
        phanHoi: _StoreGhiLai(),
        idaccount: 7,
      );

      expect(kq.dong, hasLength(2), reason: 'chỉ khoản chưa gắn của tài khoản 7');
      expect(kq.dong.first.giaoDich.note, 'grab');
      expect(kq.dong.first.doan?.categoryId, 'c-dc');
      expect(kq.dong.first.lyDo, contains('Di chuyển'));
      expect(kq.dong.last.doan, isNull);
      expect(kq.tenVi['w-7'], 'Tiền mặt');
      expect(kq.chonDuoc.map((c) => c.id), containsAll(['c-dc', 'c-an', 'c-luong']));
    });

    test('cặp đang bị thôi gợi ý trong bảng phản hồi thì không đoán', () async {
      for (var i = 0; i < 8; i++) {
        await them('grab', cat: 'c-dc', ngay: DateTime(2026, 8, 1 + i));
      }
      for (var i = 0; i < 4; i++) {
        await them('com trua', cat: 'c-an', ngay: DateTime(2026, 8, 10 + i));
      }
      await them('grab');
      final store = _StoreGhiLai()
        ..daCo = [
          for (var i = 0; i < 2; i++)
            PhanHoiGoiY(
              nguon: kNguonGoiYHoc,
              amTietChinh: 'grab',
              goiYCategoryId: 'c-dc',
              ketQua: kKetQuaGoiYBoQua,
              createdAt: DateTime(2026, 9, 20),
            ),
        ];

      final kq = await taiDuLieuGan(
          db: db, danhMuc: CategoryManagementRepositoryImpl(db: db), phanHoi: store, idaccount: 7);

      expect(kq.dong.single.doan, isNull,
          reason: 'người dùng đã bỏ qua cặp ấy hai lần ở màn Thêm giao dịch — C1 không được gợi ý lại');
    });
  });

  group('apDungGan', () {
    test('đổi đúng categoryId, mọi cột khác lấy từ hàng TƯƠI chứ không từ ảnh chụp lúc mở màn', () async {
      final id = await them('grab');
      final anhChup = (await db.transactionDao.getById(id))!;
      await db.transactionDao.updateRow(id, const TransactionsCompanion(note: Value('grab (sửa ở máy khác)')));
      final repo = _RepoGhiLai();

      await apDungGan(db: db, repo: repo, dong: DongGanDanhMuc(giaoDich: anhChup), categoryId: 'c-dc');

      expect(repo.lanGoi, hasLength(1));
      final (before, after) = repo.lanGoi.single;
      expect(after.categoryId, 'c-dc');
      expect(after.note, 'grab (sửa ở máy khác)',
          reason: 'ghi từ ảnh chụp là đè mất lần sửa vừa kéo về, rồi updatedAt mới làm bản cũ thắng trên server');
      expect(before.categoryId, isNull);
      expect(after.amount, before.amount);
      expect(after.walletId, before.walletId);
    });

    test('hàng đã có danh mục từ lúc mở màn → từ chối, không ghi', () async {
      final id = await them('grab');
      final anhChup = (await db.transactionDao.getById(id))!;
      await db.transactionDao.updateRow(id, const TransactionsCompanion(categoryId: Value('c-an')));
      final repo = _RepoGhiLai();

      await expectLater(
        apDungGan(db: db, repo: repo, dong: DongGanDanhMuc(giaoDich: anhChup), categoryId: 'c-dc'),
        throwsStateError,
      );
      expect(repo.lanGoi, isEmpty, reason: 'không được đè danh mục người dùng vừa gắn ở chỗ khác');
    });
  });

  test('ghiPhanHoiGan ghi nguồn học, khoá cụm + danh mục đoán, kết quả và danh mục cuối', () async {
    final store = _StoreGhiLai();
    final duDoan = (await db.categoryDao.getById('c-dc'))!;
    const doan = DoanDanhMuc(categoryId: 'c-dc', xacSuat: 0.9, cumBoDau: 'grab', soLanCung: 6, soLanTong: 7);
    final gd = (await db.transactionDao.getById(await them('grab')))!;

    await ghiPhanHoiGan(
      store: store,
      idaccount: 7,
      dong: DongGanDanhMuc(giaoDich: gd, doan: doan, lyDo: 'x'),
      duDoan: duDoan,
      ketQua: kKetQuaGoiYKhac,
      chonCategoryId: 'c-an',
    );

    final g = store.lanGhi.single;
    expect(g.goiY.nguon, kNguonGoiYHoc);
    expect(g.goiY.amTietChinh, 'grab');
    expect(g.goiY.categoryId, 'c-dc');
    expect(g.ketQua, kKetQuaGoiYKhac);
    expect(g.chon, 'c-an');
  });
}
