/// Form Thêm giao dịch đổi TẠI CHỖ sang khoản của nhà khi chọn ví chung (spec 2026-11-16 mục 2): ví chung ở danh sách
/// riêng, danh mục ghép theo tên, không gợi ý / học cá nhân, Chuyển khoản về ví riêng, lưu mang `idhousehold`.
library;

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/domain/category_suggestion_engine.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/vi_chung_cho_form_nguon.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/them_giao_dich_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../../category/presentation/category_test_fakes.dart';

final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt').copyWith(isDefault: true);
final viNha = makeWallet(id: 'nha-v', name: 'Tiền chợ').copyWith(idhousehold: 7);
final anUong = makeCategory(id: 'food', name: 'Ăn uống');
final anUongNha = makeCategory(id: 'nha-food', name: 'Ăn uống', idaccount: 0);
final choNha = makeCategory(id: 'nha-cho', name: 'Đi chợ', idaccount: 0);

Future<void> cho() => Future<void>.delayed(const Duration(milliseconds: 20));

({ThemGiaoDichCubit c, NguonThemGiaoDichGia rieng, NguonThemGiaoDichGia nha, List<int> soLanNap}) dung({
  bool duocGhi = true,
  bool coNhom = true,
  TransactionEntity? dangSua,
  List<CategoryEntity>? danhMucNha,
}) {
  final rieng = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong], bangTuKhoa: {
    'food': ['phở']
  });
  final nha = NguonThemGiaoDichGia(vi: [viNha], danhMuc: danhMucNha ?? [anUongNha, choNha]);
  final soLanNap = <int>[];
  final nhom = NhomViChung(
    idNha: 7,
    tenNha: 'Nhà An Bình',
    vi: [viNha],
    nguon: nha,
    conDuocGhi: () => duocGhi,
    duongChonDanhMuc: '/add/nha-category',
  );
  final c = ThemGiaoDichCubit(
    nguon: rieng,
    taiKhoan: () => 1,
    boGoiY: const CategorySuggestionEngine(),
    dangSua: dangSua,
    danhMucDangSua: dangSua == null ? null : anUong,
    viChung: ViChungChoFormNguon(() async {
      soLanNap.add(1);
      return coNhom ? nhom : null;
    }),
  );
  addTearDown(c.close);
  return (c: c, rieng: rieng, nha: nha, soLanNap: soLanNap);
}

Future<ThemGiaoDichCubit> vaoNha({bool duocGhi = true, List<CategoryEntity>? danhMucNha}) async {
  final d = dung(duocGhi: duocGhi, danhMucNha: danhMucNha);
  await d.c.moTrang();
  d.c.chonDanhMuc(anUong);
  for (final k in ['4', '5', '0', '0', '0']) {
    d.c.goPhim(k);
  }
  d.c.ghiChuDoi('chợ');
  d.c.chonVi(viNha);
  await cho();
  return d.c;
}

void main() {
  test('nhóm ví chung nằm ở danh sách RIÊNG, không lọt vào ví cá nhân', () async {
    final d = dung();
    await d.c.moTrang();
    expect(d.c.state.viChung.map((w) => w.id), ['nha-v']);
    expect(d.c.state.vi.map((w) => w.id), isNot(contains('nha-v')),
        reason: 'Nhập nhanh / giọng nói / ví chọn sẵn đọc `vi` — không được chọn trúng ví chung');
    expect(d.c.tenNhaViChung, 'Nhà An Bình');
  });

  test('đường SỬA: không nạp nhóm ví chung', () async {
    final d = dung(
        dangSua: TransactionEntity(
      id: 'tx',
      walletId: 'cash',
      idaccount: 1,
      categoryId: 'food',
      amount: 1000,
      type: 'chi',
      note: '',
      date: DateTime(2026, 11, 1),
      syncStatus: 'synced',
      updatedAt: DateTime(2026, 11, 1),
    ));
    await d.c.moTrang();
    expect(d.soLanNap, isEmpty);
    expect(d.c.state.viChung, isEmpty);
  });

  test('cổng trả null → form như cũ', () async {
    final d = dung(coNhom: false);
    await d.c.moTrang();
    expect(d.c.state.viChung, isEmpty);
    expect(d.c.tenNhaViChung, isNull);
  });

  test('chọn ví chung → chế độ nhà; giữ số tiền / ghi chú; danh mục ghép tên sang danh mục nhà', () async {
    final c = await vaoNha();
    expect(c.state.nhaDangGhi?.idNha, 7);
    expect(c.state.nhaDangGhi?.choChuyen, isFalse, reason: 'quyết định 2: không Chuyển khoản ở chế độ nhà từ /add');
    expect(c.state.nhaDangGhi?.duongChonDanhMuc, '/add/nha-category');
    expect(c.state.viNguon?.id, 'nha-v');
    expect(c.state.danhMuc?.id, 'nha-food');
    expect(c.state.chuoiSoTien, '45000');
    expect(c.state.ghiChu, 'chợ');
    expect(c.state.goiY, isNull);
    expect(c.state.phanTach, isEmpty);
  });

  test('nhà không có danh mục cùng tên → ô danh mục trống', () async {
    final c = await vaoNha(danhMucNha: [choNha]);
    expect(c.state.danhMuc, isNull);
  });

  test('chọn lại ví cá nhân → ra chế độ nhà, danh mục ghép ngược', () async {
    final c = await vaoNha();
    c.chonVi(tienMat);
    await cho();
    expect(c.state.nhaDangGhi, isNull);
    expect(c.state.viNguon?.id, 'cash');
    expect(c.state.danhMuc?.id, 'food');
    expect(c.state.chuoiSoTien, '45000');
  });

  test('đang ở nhà mà chạm Chuyển khoản → về ví cá nhân chọn sẵn', () async {
    final c = await vaoNha();
    c.chonHuong('transfer');
    await cho();
    expect(c.state.nhaDangGhi, isNull);
    expect(c.state.viNguon?.id, 'cash');
    expect(c.state.huong, 'transfer');
  });

  test('ở chế độ nhà: gõ ghi chú KHÔNG hiện gợi ý cá nhân', () async {
    final d = dung();
    await d.c.moTrang();
    d.c.chonVi(viNha);
    await cho();
    d.c.ghiChuDoi('ăn phở');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(d.c.state.goiY, isNull, reason: 'từ khoá "phở" của danh mục RIÊNG không được gợi ý cho khoản của nhà');
  });

  test('đối chứng: ở chế độ riêng thì cùng ghi chú CÓ gợi ý (ca trên không mù)', () async {
    final d = dung();
    await d.c.moTrang();
    d.c.ghiChuDoi('ăn phở');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(d.c.state.goiY?.category.id, 'food');
  });

  test('lưu ở chế độ nhà → mang idhousehold của nhà, ví chung, danh mục nhà; không tra ngân sách riêng', () async {
    final d = dung();
    d.rieng.nganSach = (_, __) => throw StateError('ngân sách riêng không được tra cho khoản của nhà');
    await d.c.moTrang();
    d.c.chonDanhMuc(anUong);
    d.c.goPhim('9');
    d.c.chonVi(viNha);
    await cho();
    final kq = await d.c.chuanBiLuu();
    expect(kq, isA<SanSangLuu>());
    final tx = (kq as SanSangLuu).giaoDich.single;
    expect(tx.idhousehold, 7);
    expect(tx.walletId, 'nha-v');
    expect(tx.categoryId, 'nha-food');
    expect(tx.idaccount, 1, reason: 'người ghi = phiên (quy tắc 2)');
  });

  test('ở chế độ riêng → lưu KHÔNG mang idhousehold', () async {
    final d = dung();
    await d.c.moTrang();
    d.c.chonDanhMuc(anUong);
    d.c.goPhim('9');
    final kq = await d.c.chuanBiLuu() as SanSangLuu;
    expect(kq.giaoDich.single.idhousehold, isNull);
  });

  test('mất quyền ghi lúc Lưu → không lưu', () async {
    final c = await vaoNha(duocGhi: false);
    final kq = await c.chuanBiLuu();
    expect(kq, isA<LoiLuu>());
    expect((kq as LoiLuu).cau, 'Bạn không còn quyền ghi khoản vào nhà này.');
  });
}
