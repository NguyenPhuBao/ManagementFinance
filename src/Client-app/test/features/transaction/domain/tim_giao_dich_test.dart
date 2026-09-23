/// timGiaoDich (bước 2, spec mục 3.8) — nguồn của tool `tim_giao_dich`. Canh:
/// lọc QUA applyTransactionFilter (ví khớp cả ví đích), bỏ khoản ghi sổ và
/// khoản ngày tương lai, tổng trên MỌI khoản khớp (không chỉ số dòng hiện),
/// khớp tên không chuỗi con.
library;

import 'package:flowmoney/features/analytics/data/bao_cao_repository.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/khoang_tien.dart';
import 'package:flowmoney/features/transaction/domain/tim_giao_dich.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final now = DateTime(2026, 9, 23, 10);
  final lookup = TransactionLookup(
    wallets: [
      makeWallet(id: 'w-cash', name: 'Tiền mặt'),
      makeWallet(id: 'w-save', name: 'Tiết kiệm'),
      makeWallet(id: 'w-nha', name: 'Tiết kiệm mua nhà'),
    ],
    categories: [
      makeCategory(id: 'c-an', name: 'Ăn uống'),
      makeCategory(id: 'c-dc', name: 'Di chuyển'),
      makeCategory(id: 'c-cu', name: 'Danh mục cũ'), // đã xoá mềm: chỉ còn trong bảng tra
      makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu'),
    ],
  );
  const viSong = [
    LuaChonLoc(id: 'w-cash', ten: 'Tiền mặt'),
    LuaChonLoc(id: 'w-save', ten: 'Tiết kiệm'),
    LuaChonLoc(id: 'w-nha', ten: 'Tiết kiệm mua nhà'),
  ];
  const dmSong = [
    LuaChonLoc(id: 'c-an', ten: 'Ăn uống'),
    LuaChonLoc(id: 'c-dc', ten: 'Di chuyển'),
    LuaChonLoc(id: 'c-luong', ten: 'Lương'),
  ];

  TransactionEntity gd(String id, String loai, double soTien, DateTime ngay,
          {String? dm, String vi = 'w-cash', String? viDich, String ghiChu = ''}) =>
      TransactionEntity(
        id: id,
        walletId: vi,
        idaccount: 10,
        categoryId: dm,
        walletTransfer: viDich,
        amount: soTien,
        type: loai,
        note: ghiChu,
        date: ngay,
        updatedAt: ngay,
      );

  final so = [
    gd('an1', 'chi', 50000, DateTime(2026, 9, 4), dm: 'c-an'),
    gd('dc1', 'chi', 50000, DateTime(2026, 9, 20), dm: 'c-dc'),
    gd('cho', 'chi', 800000, DateTime(2026, 9, 19), dm: 'c-cu', ghiChu: 'Cho vay'),
    gd('hd1', 'chi', 123000, DateTime(2026, 9, 15), ghiChu: 'Thanh toán hóa đơn: Điện'),
    gd('mx', 'chi', 500000, DateTime(2026, 9, 5), ghiChu: 'Tích lũy mục tiêu: MuaXe'),
    gd('luong', 'thu', 9000000, DateTime(2026, 9, 2), dm: 'c-luong'),
    gd('dieuChinh', 'thu', 10000, DateTime(2026, 9, 10), ghiChu: '$tienToDieuChinh ví Tiền mặt'),
    gd('moSo', 'thu', 2000000, DateTime(2026, 9, 2), vi: 'w-save', ghiChu: tienToMoSo),
    gd('ck1', 'transfer', 900000, DateTime(2026, 9, 8), vi: 'w-cash', viDich: 'w-save'),
    gd('ck2', 'transfer', 100000, DateTime(2026, 9, 9), vi: 'w-cash', viDich: 'w-nha'),
    gd('hen', 'transfer', 100000, DateTime(2026, 11, 10),
        vi: 'w-cash', viDich: 'w-save', ghiChu: 'Tích lũy mục tiêu: MuaXe'),
  ];

  KetQuaTimGiaoDich tim(TieuChiTim t, {int toiDa = 4}) => timGiaoDich(
        trongKy: so,
        lookup: lookup,
        viSong: viSong,
        danhMucSong: dmSong,
        tieuChi: t,
        now: now,
        toiDa: toiDa,
      );

  test('⭐ tổng trên MỌI khoản khớp, không chỉ các dòng hiện (bẫy 10)', () {
    final kq = tim(const TieuChiTim(chieu: ChieuTim.chi), toiDa: 2);
    expect(kq.dong.length, 2);
    expect(kq.soKhop, 5);
    expect(kq.tongChi, 50000 + 50000 + 800000 + 123000 + 500000);
  });

  test('xếp theo số tiền (mặc định): lớn trước; tiêu đề theo luật dòng sổ', () {
    final kq = tim(const TieuChiTim(chieu: ChieuTim.chi));
    expect(kq.dong.map((d) => d.tieuDe).toList(),
        ['Cho vay', 'Tích lũy mục tiêu: MuaXe', 'Thanh toán hóa đơn: Điện', 'Di chuyển']);
  });

  test('xếp mới nhất trước', () {
    final kq = tim(const TieuChiTim(chieu: ChieuTim.chi, sapXep: SapXepTim.moiNhat));
    expect(kq.dong.first.ngay, DateTime(2026, 9, 20));
  });

  test('⭐ bỏ khoản điều chỉnh số dư và khoản mở sổ (bẫy 4)', () {
    final kq = tim(const TieuChiTim(chieu: ChieuTim.thu));
    expect(kq.dong.map((d) => d.tieuDe).toList(), ['Lương']);
    expect(kq.tongThu, 9000000);
  });

  test('⭐ bỏ khoản ghi ngày TƯƠNG LAI (bẫy 3) — "lần cuối" không trả 10/11', () {
    final kq = tim(const TieuChiTim(tuKhoa: 'muaxe', sapXep: SapXepTim.moiNhat));
    expect(kq.dong.map((d) => d.ngay).toList(), [DateTime(2026, 9, 5)]);
  });

  test('khoản chuyển chỉ có khi hỏi chuyển ví hoặc tất cả', () {
    expect(tim(const TieuChiTim(chieu: ChieuTim.chi)).dong.any((d) => d.chieu == ChieuTim.chuyen),
        isFalse);
    final ck = tim(const TieuChiTim(chieu: ChieuTim.chuyen));
    expect(ck.soKhop, 2);
    expect(ck.tongChuyen, 1000000);
    expect(ck.dong.first.tenViDich, 'Tiết kiệm');
    expect(ck.dong.first.tieuDe, 'Chuyển khoản');
    expect(tim(const TieuChiTim()).soKhop, 5 + 1 + 2);
  });

  test('⭐ ví khớp CẢ ví đích của khoản chuyển; "tiet kiem" không khớp "Tiết kiệm mua nhà"', () {
    final kq = tim(const TieuChiTim(chieu: ChieuTim.chuyen, tenVi: 'tiet kiem'));
    expect(kq.dong.map((d) => d.tenViDich).toList(), ['Tiết kiệm']);
    expect(kq.tenKhop, ['Tiết kiệm']);
  });

  test('danh mục theo tên; tên danh mục ĐÃ XOÁ MỀM vẫn tra được cho dòng', () {
    expect(tim(const TieuChiTim(tenDanhMuc: 'an uong')).dong.single.tenDanhMuc, 'Ăn uống');
    final chi = tim(const TieuChiTim(chieu: ChieuTim.chi)).dong;
    expect(chi.first.tenDanhMuc, 'Danh mục cũ');
    expect(chi.firstWhere((d) => d.tieuDe.startsWith('Thanh toán')).tenDanhMuc, isNull);
  });

  test('khoảng tiền qua KhoangTien.chua', () {
    final kq = tim(const TieuChiTim(
        chieu: ChieuTim.chi, khoangTien: KhoangTien(tu: 200000, den: 1000000)));
    expect(kq.dong.map((d) => d.soTien).toList(), [800000, 500000]);
  });

  test('từ khoá không dấu, không phân biệt hoa thường', () {
    expect(tim(const TieuChiTim(tuKhoa: 'hoa don')).dong.single.tieuDe, 'Thanh toán hóa đơn: Điện');
  });

  test('tên KHÔNG khớp → lỗi kèm mọi tên còn sống; không dòng nào', () {
    final kq = tim(const TieuChiTim(tenVi: 'vi gia'));
    expect(kq.dong, isEmpty);
    expect(kq.loi!.truong, TruongTen.vi);
    expect(kq.loi!.nhieu, isFalse);
    expect(kq.loi!.tenGoiY, ['Tiền mặt', 'Tiết kiệm', 'Tiết kiệm mua nhà']);
  });

  test('tên khớp NHIỀU → lỗi kèm các tên đã khớp', () {
    final kq = timGiaoDich(
      trongKy: so,
      lookup: lookup,
      viSong: viSong,
      danhMucSong: const [LuaChonLoc(id: 'a', ten: 'Dá'), LuaChonLoc(id: 'b', ten: 'Đá')],
      tieuChi: const TieuChiTim(tenDanhMuc: 'da'),
      now: now,
      toiDa: 4,
    );
    expect(kq.loi!.nhieu, isTrue);
    expect(kq.loi!.tenGoiY, ['Dá', 'Đá']);
  });
}
