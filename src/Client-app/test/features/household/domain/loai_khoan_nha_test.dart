// Phân loại khoản của nhà (`docs/Family/02A` mục 3) — một ca mỗi ô của bảng.
import 'package:flowmoney/features/household/domain/loai_khoan_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity gd({int? nha, String? cap, String type = 'chi', String note = '', String? cat}) => TransactionEntity(
      id: 'g',
      walletId: 'v',
      idaccount: 10,
      amount: 1000,
      type: type,
      note: note,
      categoryId: cat,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
      idhousehold: nha,
      fundPairId: cap,
    );

void main() {
  test('bảy loại hàng', () {
    expect(phanLoaiKhoanNha(gd(nha: 7, cat: 'c')), LoaiKhoanNha.chiNha, reason: 'chi của nhà');
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', cat: 'c')), LoaiKhoanNha.thuKhac);
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'transfer')), LoaiKhoanNha.chuyen);
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', cap: 'p')), LoaiKhoanNha.gopNha);
    expect(phanLoaiKhoanNha(gd(nha: 7, cap: 'p')), LoaiKhoanNha.rutNha);
    expect(phanLoaiKhoanNha(gd(cap: 'p')), LoaiKhoanNha.gopRieng);
    expect(phanLoaiKhoanNha(gd(type: 'thu', cap: 'p')), LoaiKhoanNha.rutRieng);
  });

  test('neo và điều chỉnh của ví chung không lọt vào số liệu', () {
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', note: tienToMoSo)), LoaiKhoanNha.khongTinh);
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', note: '$tienToDieuChinh tăng')), LoaiKhoanNha.khongTinh);
  });

  test('khoản có danh mục mang ghi chú giống neo vẫn là khoản thật', () {
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', cat: 'c', note: tienToMoSo)), LoaiKhoanNha.thuKhac,
        reason: 'nhận dạng neo là CẶP không danh mục + tiền tố');
  });

  test('khoản của nhà không danh mục: ghi chú người dùng gõ hay trống đều tính', () {
    expect(phanLoaiKhoanNha(gd(nha: 7)), LoaiKhoanNha.chiNha, reason: 'chi nhà không danh mục, ghi chú trống');
    expect(phanLoaiKhoanNha(gd(nha: 7, note: 'đi chợ')), LoaiKhoanNha.chiNha);
    expect(phanLoaiKhoanNha(gd(nha: 7, type: 'thu', note: 'lương')), LoaiKhoanNha.thuKhac,
        reason: 'ghi chú người dùng gõ không bị nhận nhầm là neo');
  });

  test('khoản riêng thường', () {
    expect(phanLoaiKhoanNha(gd(cat: 'c')), LoaiKhoanNha.khoanThuong);
  });
}
