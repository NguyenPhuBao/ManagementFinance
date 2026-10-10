/// A5 mục 4 + 5.2 — ảnh người dùng QUÉT: nhận loại (hoá đơn giấy / biên lai chuyển khoản) rồi đọc bằng đúng luật.
/// Biên lai ở đây dựng lại bằng số và tên GIẢ (nếp của `doc_bien_lai_test.dart`).
library;

import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final luc = DateTime(2026, 10, 8, 9, 30);
  const hoaDon = 'CO.OPMART NGUYEN TRAI\nNgay: 28/09/2026 18:42\nSau rieng Ri6 1 152.000\n'
      'Nuoc suoi 2 19.931 39.862\nTONG CONG 191.862\nTien khach dua 200.000';
  const bienLai = 'Giao dịch thành công\nSố tiền 150.000 VND\nNgười nhận NGUYEN VAN A\nTài khoản nhận 0123456789\n'
      'Thời gian 02/10/2026 18:45\nMã giao dịch FT26275123456\nNội dung tra tien nha thang 10\nPhí giao dịch 0 VND';

  group('loaiAnhQuet', () {
    test('hoá đơn siêu thị → hoaDon', () => expect(loaiAnhQuet(hoaDon.split('\n')), LoaiAnhQuet.hoaDon));
    test('biên lai chuyển khoản → bienLai', () => expect(loaiAnhQuet(bienLai.split('\n')), LoaiAnhQuet.bienLai));
    test('⭐ hoá đơn quẹt thẻ in "GIAO DỊCH THÀNH CÔNG" vẫn là hoá đơn', () {
      expect(loaiAnhQuet(['GIAO DỊCH THÀNH CÔNG', 'Don gia 10.000', 'SL 2', 'Thanh tien 20.000', 'Tong cong 20.000']),
          LoaiAnhQuet.hoaDon,
          reason: 'một điểm biên lai ("thành công") thua bốn nhãn hoá đơn');
    });
    test('hoà điểm / 0–0 → bienLai (luật biên lai đã đo trên ảnh thật)', () {
      expect(loaiAnhQuet(['abc', '12.000']), LoaiAnhQuet.bienLai);
      expect(loaiAnhQuet(['Noi dung X', 'Tong cong 10.000']), LoaiAnhQuet.bienLai);
    });
  });

  group('docAnhQuet', () {
    test('⭐ hoá đơn: tổng, chi, ngày giờ trên hoá đơn, ghi chú = cửa hàng, có món, oThieu rỗng', () {
      final kq = docAnhQuet(vanBan: hoaDon, luc: luc);
      expect(kq.loai, LoaiAnhQuet.hoaDon);
      expect(kq.soTien, 191862);
      expect(kq.chieu, 'chi');
      expect(kq.thoiGian, DateTime(2026, 9, 28, 18, 42));
      expect(kq.ghiChu, 'CO.OPMART NGUYEN TRAI');
      expect(kq.mon.length, 2);
      expect(kq.oThieu, isEmpty);
      expect(kq.aiLap, isFalse);
    });

    test('hoá đơn không in ngày → thoiGian = luc, oThieu có thoiGian', () {
      // Phải mang dấu hiệu hoá đơn ("Tong cong") — "Tong" trần chấm 0–0 → hoà → biên lai.
      final kq = docAnhQuet(vanBan: 'Pho Hung\nPho tai 1 45.000\nTong cong 90.000', luc: luc);
      expect(kq.loai, LoaiAnhQuet.hoaDon);
      expect(kq.ghiChu, 'Pho Hung');
      expect(kq.thoiGian, luc);
      expect(kq.oThieu, {OAnhQuet.thoiGian});
    });

    test('ngày không có thật (31/02) → không nhận, dùng lúc quét', () {
      final kq = docAnhQuet(vanBan: 'Quan A\nNgay 31/02/2026\nTong cong 50.000', luc: luc);
      expect(kq.thoiGian, luc);
      expect(kq.oThieu, contains(OAnhQuet.thoiGian));
    });

    test('biên lai: đi docBienLai — tiền, giờ trên ảnh, nội dung; không có món', () {
      final kq = docAnhQuet(vanBan: bienLai, luc: luc);
      expect(kq.loai, LoaiAnhQuet.bienLai);
      expect(kq.soTien, 150000);
      expect(kq.thoiGian, DateTime(2026, 10, 2, 18, 45));
      expect(kq.ghiChu, 'tra tien nha thang 10');
      expect(kq.mon, isEmpty);
      expect(kq.oThieu, isEmpty);
    });

    test('chữ rỗng → không tiền, oThieu đủ ba ô, không ném', () {
      final kq = docAnhQuet(vanBan: '', luc: luc);
      expect(kq.soTien, isNull);
      expect(kq.oThieu, OAnhQuet.values.toSet());
    });
  });
}
