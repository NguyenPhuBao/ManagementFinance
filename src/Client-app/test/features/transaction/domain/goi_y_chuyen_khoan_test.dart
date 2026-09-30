/// Gợi ý Chuyển khoản từ biến động số dư — phép nhận thuần (spec `2026-09-30-goi-y-chuyen-khoan-bien-dong-design.md`).
library;

import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/goi_y_chuyen_khoan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Nguyên văn tin thật trên Realme 2026-09-30 (sau `docTinBienDong`).
  const quaMomo = '149346965345-TRAN QUANG DAT chuyen tien qua MoMo-CHUYEN TIEN-OQCH000LKkVs-MOMO149346965345MOMO';
  const tran = 'TRAN QUANG DAT chuyen tien';

  DienSanBienDong h({
    String khoa = 'bienDong:a',
    String nguon = kNguonMb,
    String ghiChu = tran,
    double? soTien = 10000,
    String? chieu = 'thu',
    DateTime? luc,
    String? duoi = '262',
  }) =>
      DienSanBienDong(
        khoa: khoa,
        nguon: nguon,
        ghiChu: ghiChu,
        soTien: soTien,
        chieu: chieu,
        thoiGian: luc ?? DateTime(2026, 9, 30, 20, 2),
        duoi: duoi,
      );

  group('nguonNhacTrongTin', () {
    test('⭐ tin MB thật "qua MoMo" → MoMo', () {
      expect(nguonNhacTrongTin(quaMomo, nguonCuaTin: kNguonMb), kNguonMomo);
    });
    test('MOMO dính chữ số vẫn nhận; "momoney" không', () {
      expect(nguonNhacTrongTin('ABC-MOMO1234', nguonCuaTin: kNguonMb), kNguonMomo);
      expect(nguonNhacTrongTin('mua momoney', nguonCuaTin: kNguonMb), isNull);
    });
    test('nhắc chính nguồn của tin → null', () {
      expect(nguonNhacTrongTin('nap tien tu MoMo', nguonCuaTin: kNguonMomo), isNull);
    });
    test('nhắc hai nguồn khác → null (mơ hồ)', () {
      expect(nguonNhacTrongTin('MoMo va ZaloPay', nguonCuaTin: kNguonMb), isNull);
    });
    test('"mb" trần không phải MB Bank; "MB Bank" / "MBBANK" là', () {
      expect(nguonNhacTrongTin('ma GD MB 123', nguonCuaTin: kNguonMomo), isNull);
      expect(nguonNhacTrongTin('rut ve MB Bank', nguonCuaTin: kNguonMomo), kNguonMb);
      expect(nguonNhacTrongTin('rut ve MBBANK', nguonCuaTin: kNguonMomo), kNguonMb);
    });
    test('VCB / TCB / BIDV / Zalo Pay', () {
      expect(nguonNhacTrongTin('den VCB', nguonCuaTin: kNguonMb), kNguonVcb);
      expect(nguonNhacTrongTin('den TCB', nguonCuaTin: kNguonMb), kNguonTcb);
      expect(nguonNhacTrongTin('den BIDV', nguonCuaTin: kNguonMb), kNguonBidv);
      expect(nguonNhacTrongTin('nap Zalo Pay', nguonCuaTin: kNguonMb), kNguonZalopay);
    });
    test('tin trần −10.000 thật → null (phần DEN đã bị cắt — spec §7)', () {
      expect(nguonNhacTrongTin(tran, nguonCuaTin: kNguonMb), isNull);
    });
  });

  group('goiYChuyenKhoan — luật nội dung', () {
    test('⭐ thu ở MB nhắc MoMo → từ MoMo sang MB Bank, đuôi theo MB', () {
      final g = goiYChuyenKhoan(h(ghiChu: quaMomo), const [])!;
      expect((g.nguonTu, g.duoiTu, g.nguonDen, g.duoiDen, g.khoaCap), (kNguonMomo, null, kNguonMb, '262', null));
    });
    test('chi ở MB nhắc MoMo → từ MB Bank sang MoMo', () {
      final g = goiYChuyenKhoan(h(ghiChu: 'chuyen sang MoMo', chieu: 'chi'), const [])!;
      expect((g.nguonTu, g.duoiTu, g.nguonDen, g.duoiDen), (kNguonMb, '262', kNguonMomo, null));
    });
    test('không nhắc nguồn nào → null', () {
      expect(goiYChuyenKhoan(h(), const []), isNull);
    });
    test('thiếu số tiền hoặc chiều → null', () {
      expect(goiYChuyenKhoan(h(ghiChu: quaMomo, soTien: null), const []), isNull);
      expect(goiYChuyenKhoan(h(ghiChu: quaMomo, chieu: null), const []), isNull);
    });
  });

  group('goiYChuyenKhoan — luật cặp', () {
    final chiMb = h(khoa: 'bienDong:chi', chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 19));
    DienSanBienDong thuVcb(DateTime luc, {String khoa = 'bienDong:vcb', double soTien = 10000}) =>
        h(khoa: khoa, nguon: kNguonVcb, chieu: 'thu', luc: luc, duoi: '1234', soTien: soTien);

    test('⭐ chi MB + thu VCB cùng tiền, lệch 2 phút → từ MB sang VCB, khoaCap = hàng VCB', () {
      final g = goiYChuyenKhoan(chiMb, [chiMb, thuVcb(DateTime(2026, 9, 30, 20, 21))])!;
      expect((g.nguonTu, g.duoiTu, g.nguonDen, g.duoiDen, g.khoaCap),
          (kNguonMb, '262', kNguonVcb, '1234', 'bienDong:vcb'));
    });
    test('mở từ phía thu cũng ra cùng hướng', () {
      final vcb = thuVcb(DateTime(2026, 9, 30, 20, 21));
      final g = goiYChuyenKhoan(vcb, [chiMb, vcb])!;
      expect((g.nguonTu, g.nguonDen, g.khoaCap), (kNguonMb, kNguonVcb, 'bienDong:chi'));
    });
    test('lệch đúng 5 phút có; 6 phút không', () {
      expect(goiYChuyenKhoan(chiMb, [thuVcb(DateTime(2026, 9, 30, 20, 24))]), isNotNull);
      expect(goiYChuyenKhoan(chiMb, [thuVcb(DateTime(2026, 9, 30, 20, 25))]), isNull);
    });
    test('cùng nguồn không phải cặp (hai khoản riêng trong một tài khoản)', () {
      final thuMb = h(khoa: 'bienDong:thuMb', chieu: 'thu', luc: DateTime(2026, 9, 30, 20, 20));
      expect(goiYChuyenKhoan(chiMb, [thuMb]), isNull);
    });
    test('khác số tiền hoặc cùng chiều không phải cặp', () {
      expect(goiYChuyenKhoan(chiMb, [thuVcb(DateTime(2026, 9, 30, 20, 21), soTien: 20000)]), isNull);
      expect(goiYChuyenKhoan(chiMb, [h(khoa: 'x', nguon: kNguonVcb, chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 20))]),
          isNull);
    });
    test('hai ứng viên → lấy hàng gần giờ nhất', () {
      final g = goiYChuyenKhoan(chiMb, [
        thuVcb(DateTime(2026, 9, 30, 20, 23), khoa: 'xa'),
        thuVcb(DateTime(2026, 9, 30, 20, 20), khoa: 'gan'),
      ])!;
      expect(g.khoaCap, 'gan');
    });
    test('hai ứng viên cùng lệch → null (mơ hồ), kể cả khi nội dung nhắc nguồn', () {
      final chi = h(khoa: 'bienDong:chi', chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 19), ghiChu: 'sang MoMo');
      expect(
          goiYChuyenKhoan(chi, [
            thuVcb(DateTime(2026, 9, 30, 20, 21), khoa: 'a'),
            thuVcb(DateTime(2026, 9, 30, 20, 17), khoa: 'b'),
          ]),
          isNull);
    });
    test('cặp thắng nội dung', () {
      final chi = h(khoa: 'bienDong:chi', chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 19), ghiChu: 'sang MoMo');
      expect(goiYChuyenKhoan(chi, [thuVcb(DateTime(2026, 9, 30, 20, 20))])!.nguonDen, kNguonVcb);
    });
  });

  group('viTheoTenNguon', () {
    test('một ví chứa tên nguồn → ví ấy', () {
      expect(viTheoTenNguon(kNguonMomo, [(id: 'a', ten: 'Tiền mặt'), (id: 'm', ten: 'Ví MoMo')]), 'm');
      expect(viTheoTenNguon(kNguonMb, [(id: 'b', ten: 'Ví MB Bank')]), 'b');
    });
    test('hai ví cùng chứa → null; không ví nào → null', () {
      expect(viTheoTenNguon(kNguonMomo, [(id: 'm1', ten: 'MoMo chính'), (id: 'm2', ten: 'Ví MoMo phụ')]), isNull);
      expect(viTheoTenNguon(kNguonMomo, [(id: 'a', ten: 'Tiền mặt')]), isNull);
    });
  });
}
