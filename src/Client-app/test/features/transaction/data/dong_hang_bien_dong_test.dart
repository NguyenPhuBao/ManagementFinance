// test/features/transaction/data/dong_hang_bien_dong_test.dart
/// D1 — đóng một hàng biến động sau Lưu / Bỏ qua. Dời khỏi `ThemGiaoDichCubit` ngày 2026-10-12 (spec C4 §4.2) để chừa
/// chỗ dưới trần 1.200 dòng (quét 23); hành vi giữ nguyên từng dòng.
library;

import 'package:flowmoney/features/transaction/data/dong_hang_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/goi_y_chuyen_khoan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/them_giao_dich_nguon_gia.dart';

void main() {
  const tin = DienSanBienDong(khoa: 'bienDong:abc', nguon: 'MB Bank', ghiChu: 'x', duoi: '1234', anh: 'a.jpg');

  group('dongHangBienDong', () {
    test('Lưu ở lần đầu của cặp: nhớ ví, xoá cứng hàng, xoá ảnh biên lai', () async {
      final n = NguonThemGiaoDichGia();
      await dongHangBienDong(n, tin, 1, viDaLuu: 'tcb', nhoVi: true);
      expect(n.viDaNho, ['MB Bank|1234=tcb']);
      expect(n.hangDaXoa, ['bienDong:abc']);
      expect(n.anhBienLaiDaXoa, ['a.jpg']);
    });

    test('Bỏ qua (nhoVi = false): không nhớ ví, vẫn xoá hàng + ảnh', () async {
      final n = NguonThemGiaoDichGia();
      await dongHangBienDong(n, tin, 1);
      expect(n.viDaNho, isEmpty);
      expect(n.hangDaXoa, ['bienDong:abc']);
      expect(n.anhBienLaiDaXoa, ['a.jpg']);
    });

    test('ảnh quét (A5): chỉ xoá ảnh quét — không hàng loại 20, không bảng nguồn → ví', () async {
      final n = NguonThemGiaoDichGia();
      const quet = DienSanBienDong(khoa: '${kTienToKhoaQuet}q.jpg', nguon: kNguonAnhQuet, ghiChu: '', anh: 'q.jpg');
      await dongHangBienDong(n, quet, 1, viDaLuu: 'tcb', nhoVi: true);
      expect(n.anhQuetDaXoa, ['q.jpg']);
      expect(n.hangDaXoa, isEmpty);
      expect(n.viDaNho, isEmpty);
    });
  });

  group('dongHangChuyenKhoan', () {
    const gy = GoiYChuyenKhoan(nguonTu: 'MB Bank', duoiTu: '1234', nguonDen: 'MoMo', khoaCap: 'bienDong:cap');

    test('nhớ ví HAI phía theo phía của nó, xoá hàng đang mở + hàng cặp + ảnh', () async {
      final n = NguonThemGiaoDichGia();
      await dongHangChuyenKhoan(n, tin, gy, 1, viTu: 'mb', viDen: 'momo', daNhoTu: false, daNhoDen: false);
      expect(n.viDaNho, ['MB Bank|1234=mb', 'MoMo|=momo']);
      expect(n.hangDaXoa, ['bienDong:abc', 'bienDong:cap']);
      expect(n.anhBienLaiDaXoa, ['a.jpg']);
    });

    test('phía đã nhớ thì không ghi lại', () async {
      final n = NguonThemGiaoDichGia();
      await dongHangChuyenKhoan(n, tin, gy, 1, viTu: 'mb', viDen: 'momo', daNhoTu: true, daNhoDen: false);
      expect(n.viDaNho, ['MoMo|=momo']);
    });
  });
}
