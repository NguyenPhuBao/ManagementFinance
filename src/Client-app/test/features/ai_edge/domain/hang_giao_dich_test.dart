/// Tool `tim_giao_dich` — phần CHÉP của ai_edge: hàng theo tiêu đề, trạng thái
/// nêu chiều · danh mục · ví, số tiền + NGÀY; tổng hợp theo chiều đã hỏi;
/// khoảng tiền đã hiểu dội lại; tên liên quan cho bộ kiểm.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_giao_dich.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/transaction/domain/khoang_tien.dart';
import 'package:flowmoney/features/transaction/domain/tim_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 10);
  final kq = KetQuaTimGiaoDich(
    dong: [
      DongTimThay(
        tieuDe: 'Cho vay', tenDanhMuc: 'test1', tenVi: 'Tiền mặt', tenViDich: null,
        soTien: 800000, chieu: ChieuTim.chi, ngay: DateTime(2026, 9, 19),
      ),
      DongTimThay(
        tieuDe: 'Chuyển khoản', tenDanhMuc: null, tenVi: 'Tiền mặt', tenViDich: 'Tiết kiệm',
        soTien: 900000, chieu: ChieuTim.chuyen, ngay: DateTime(2026, 9, 8),
      ),
      DongTimThay(
        tieuDe: 'Phí cũ', tenDanhMuc: null, tenVi: 'Tiền mặt', tenViDich: null,
        soTien: 20000, chieu: ChieuTim.chi, ngay: DateTime(2025, 12, 28),
      ),
    ],
    soKhop: 7,
    tongChi: 2031000,
    tongThu: 0,
    tongChuyen: 900000,
    tenKhop: const ['Tiền mặt'],
  );
  Map<String, String> so(HangSoLieu h) => {for (final s in h.soLieu) s.nhan: s.chuoi};

  test('⭐ hàng: tiêu đề, trạng thái chiều · danh mục · ví, Số tiền + Ngày (mang tên hàng)', () {
    final r = hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.hang[0].ten, 'Cho vay');
    expect(r.hang[0].trangThai, 'khoản chi · test1 · Tiền mặt');
    expect(so(r.hang[0]), {'Số tiền': '800.000 đ', 'Ngày': '19/09'});
    expect(r.hang[0].soLieu.every((s) => s.ten == 'Cho vay'), isTrue);
    expect(r.hang[1].trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
    expect(r.hang[2].trangThai, 'khoản chi · Chưa phân loại · Tiền mặt');
    expect(so(r.hang[2])['Ngày'], '28/12/2025');
    expect(r.hang.every((h) => !h.canhBao), isTrue);
  });

  test('tổng hợp theo CHIỀU đã hỏi; Số khoản là mọi khoản khớp', () {
    Map<String, String> tong(TieuChiTim t) => {
          for (final s in hangGiaoDich(kq, tieuChi: t, chuKy: 'tháng này', now: now).tongHop)
            s.nhan: s.chuoi,
        };
    expect(tong(const TieuChiTim(chieu: ChieuTim.chi)), {'Số khoản': '7', 'Tổng chi': '2.031.000 đ'});
    expect(tong(const TieuChiTim(chieu: ChieuTim.chuyen)), {'Số khoản': '7', 'Tổng chuyển': '900.000 đ'});
    expect(tong(const TieuChiTim()).keys, ['Số khoản', 'Tổng chi', 'Tổng thu', 'Tổng chuyển']);
  });

  test('khoảng tiền đã hiểu DỘI LẠI (Từ / Đến)', () {
    final r = hangGiaoDich(kq,
        tieuChi: const TieuChiTim(chieu: ChieuTim.chi, khoangTien: KhoangTien(tu: 500000)),
        chuKy: 'tháng này', now: now);
    final t = {for (final s in r.tongHop) s.nhan: s.chuoi};
    expect(t['Từ'], '500.000 đ');
    expect(t.containsKey('Đến'), isFalse);
  });

  test('chữ kèm: kỳ + kiểu xếp, KHÔNG có chữ số', () {
    final r = hangGiaoDich(kq,
        tieuChi: const TieuChiTim(sapXep: SapXepTim.moiNhat), chuKy: 'tuần trước', now: now);
    expect(r.chuThem, {'ky': 'tuần trước', 'sap_xep': 'mới nhất trước'});
    expect(r.chuThem.values.any((v) => RegExp(r'\d').hasMatch(v)), isFalse);
  });

  test('⭐ tenLienQuan: tên danh mục / ví trong trạng thái + tên đã khớp', () {
    final r = hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.tenLienQuan.toSet(), {'test1', 'Tiền mặt', 'Tiết kiệm'});
  });

  test('lỗi khớp tên → lời từ chối của tool, tên gợi ý vào tenLienQuan', () {
    const loi = KetQuaTimGiaoDich.loi(LoiKhopTen(
        truong: TruongTen.vi, hoi: 'vi gia', nhieu: false, tenGoiY: ['Tiền mặt', 'test']));
    final r = hangGiaoDich(loi, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now);
    expect(r.loi, 'vi "vi gia" không khớp tên nào. Chỉ có: Tiền mặt, test.');
    expect(r.choNguoiDung, 'không có ví nào tên "vi gia"');
    expect(r.thamSoGo, ['vi']);
    expect(r.tenLienQuan, ['Tiền mặt', 'test', 'vi gia']);
  });

  test('⭐ mẫu câu của gói tra cứu (có NGÀY) tự qua kiemSo và kiemNhan', () {
    final goi = GoiSoTraCuu()
      ..them('tim_giao_dich',
          hangGiaoDich(kq, tieuChi: const TieuChiTim(), chuKy: 'tháng này', now: now));
    final cau = goi.mauCau().cau;
    expect(kiemSo(cau, goi), isTrue, reason: cau);
    expect(kiemNhan(cau, [goi]), isTrue, reason: cau);
  });
}
