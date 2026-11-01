// Hoạt động của nhà (đợt 1B, Task 6): lọc, sắp, tiêu đề, dấu tiền, quyền sửa / xoá một khoản.
import 'package:flowmoney/features/household/domain/hoat_dong_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity khoan({
  String id = 'k',
  int idaccount = 10,
  int? nha = 7,
  String? cap,
  String type = 'chi',
  String note = '',
  String? cat = 'c',
  String vi = 'v1',
  String? viDich,
  DateTime? ngay,
  DateTime? sua,
  DateTime? xoa,
}) =>
    TransactionEntity(
      id: id,
      walletId: vi,
      walletTransfer: viDich,
      idaccount: idaccount,
      idhousehold: nha,
      fundPairId: cap,
      categoryId: cat,
      amount: 1000,
      type: type,
      note: note,
      date: ngay ?? DateTime(2026, 11, 1),
      updatedAt: sua ?? DateTime(2026, 11, 1),
      deletedAt: xoa,
    );

void main() {
  test('neo và điều chỉnh không hiện; khoản đã xoá không hiện', () {
    expect(hienTrongHoatDong(khoan(type: 'thu', note: tienToMoSo, cat: null)), isFalse, reason: 'neo');
    expect(hienTrongHoatDong(khoan(note: '$tienToDieuChinh giảm', cat: null)), isFalse, reason: 'điều chỉnh');
    expect(hienTrongHoatDong(khoan(xoa: DateTime(2026, 11, 1))), isFalse, reason: 'xoá mềm');
    expect(hienTrongHoatDong(khoan()), isTrue);
    expect(hienTrongHoatDong(khoan(type: 'thu', cap: 'p', cat: null)), isTrue, reason: 'góp là khoản thật');
  });

  test('lọc theo người, theo ví; ví gồm cả khoản chuyển ĐẾN ví', () {
    final ds = [
      khoan(id: 'a', idaccount: 10, vi: 'v1'),
      khoan(id: 'b', idaccount: 20, vi: 'v2'),
      khoan(id: 'c', idaccount: 10, vi: 'v1', type: 'transfer', viDich: 'v2', cat: null),
    ];
    expect(locHoatDong(ds, nguoi: 20).map((e) => e.id), ['b']);
    expect(locHoatDong(ds, vi: 'v2').map((e) => e.id).toSet(), {'b', 'c'}, reason: 'c chuyển đến v2');
    expect(locHoatDong(ds, nguoi: 10, vi: 'v2').map((e) => e.id), ['c']);
    expect(locHoatDong(ds).length, 3);
  });

  test('lọc bỏ neo ngay cả khi không có điều kiện', () {
    final ds = [khoan(id: 'a'), khoan(id: 'neo', type: 'thu', note: tienToMoSo, cat: null)];
    expect(locHoatDong(ds).map((e) => e.id), ['a'], reason: 'watchTheoNha trả cả neo');
  });

  test('sắp ngày giảm, cùng ngày thì giờ sửa giảm', () {
    final ds = [
      khoan(id: 'cu', ngay: DateTime(2026, 10, 30)),
      khoan(id: 'sang', ngay: DateTime(2026, 11, 1), sua: DateTime(2026, 11, 1, 8)),
      khoan(id: 'toi', ngay: DateTime(2026, 11, 1), sua: DateTime(2026, 11, 1, 20)),
    ];
    expect(locHoatDong(ds).map((e) => e.id), ['toi', 'sang', 'cu']);
  });

  test('tiêu đề đúng các loại, người đã rời có hậu tố', () {
    const minh = TenNguoi('Minh');
    expect(tieuDeKhoanNha(khoan(), const TenNguoi('An')), 'An chi');
    expect(tieuDeKhoanNha(khoan(type: 'thu'), const TenNguoi('An')), 'An thu');
    expect(tieuDeKhoanNha(khoan(type: 'thu', cap: 'p', cat: null), minh), 'Minh góp');
    expect(tieuDeKhoanNha(khoan(cap: 'p', cat: null), const TenNguoi('Bình')), 'Bình rút');
    expect(tieuDeKhoanNha(khoan(type: 'transfer', cat: null), const TenNguoi('An')), 'An chuyển');
    expect(tieuDeKhoanNha(khoan(), const TenNguoi('Hoa', daRoi: true)), 'Hoa (đã rời) chi');
    expect(tieuDeKhoanNha(khoan(type: 'thu', note: tienToMoSo, cat: null), minh), 'Minh',
        reason: 'không đọc được loại vẫn trả tên');
  });

  test('dấu: thu / góp +, chi / rút -, chuyển không dấu', () {
    expect(dauTienKhoanNha(khoan(type: 'thu')), isTrue);
    expect(dauTienKhoanNha(khoan(type: 'thu', cap: 'p', cat: null)), isTrue, reason: 'góp');
    expect(dauTienKhoanNha(khoan()), isFalse);
    expect(dauTienKhoanNha(khoan(cap: 'p', cat: null)), isFalse, reason: 'rút');
    expect(dauTienKhoanNha(khoan(type: 'transfer', cat: null)), isNull);
  });

  group('quyenKhoanNha', () {
    ({bool sua, bool xoa}) q(TransactionEntity t, VaiNha? vai, {TrangThaiNha? tt = TrangThaiNha.hoatDong, int? toi = 10}) =>
        quyenKhoanNha(t, vai: vai, trangThai: tt, idToi: toi);

    test('Chủ không sửa khoản có mã cặp của người khác, vẫn xoá được', () {
      final r = q(khoan(idaccount: 10, cap: 'p', cat: null), VaiNha.chu, toi: 20);
      expect((r.sua, r.xoa), (false, true), reason: 'nửa riêng chỉ trên máy người ghi');
    });

    test('Chủ sửa, xoá khoản thường của người khác', () {
      final r = q(khoan(idaccount: 10), VaiNha.chu, toi: 20);
      expect((r.sua, r.xoa), (true, true));
    });

    test('Thành viên: khoản của mình sửa + xoá được, của người khác không', () {
      expect(q(khoan(idaccount: 10), VaiNha.thanhVien, toi: 10), (sua: true, xoa: true));
      expect(q(khoan(idaccount: 10), VaiNha.thanhVien, toi: 20), (sua: false, xoa: false));
    });

    test('Thành viên không sửa, xoá khoản chuyển dù của mình', () {
      final r = q(khoan(idaccount: 10, type: 'transfer', cat: null), VaiNha.thanhVien, toi: 10);
      expect((r.sua, r.xoa), (false, false), reason: 'laChuyen đọc từ t.type');
      expect(q(khoan(type: 'transfer', cat: null), VaiNha.chu, toi: 20), (sua: true, xoa: true));
    });

    test('nhà chỉ xem và Chỉ xem: không gì', () {
      expect(q(khoan(), VaiNha.chu, tt: TrangThaiNha.chiXem), (sua: false, xoa: false));
      expect(q(khoan(), VaiNha.chiXem), (sua: false, xoa: false));
      expect(q(khoan(), VaiNha.chu, tt: TrangThaiNha.daGiaiTan), (sua: false, xoa: false));
    });

    test('idToi null: không gì cho Thành viên; Chủ vẫn theo vai', () {
      expect(q(khoan(), VaiNha.thanhVien, toi: null), (sua: false, xoa: false), reason: 'cuaToi phải false, không `== null`');
      expect(q(khoan(), VaiNha.chu, toi: null), (sua: true, xoa: true));
    });
  });
}
