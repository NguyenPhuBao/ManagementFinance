/// A5 mục 5.1 — luật đọc hoá đơn giấy (nâng từ spike C4, spike gỡ 2026-10-12). Bảy ca đầu và ca ⭐ hoá đơn hai cột
/// chép từ test của spike; ca giờ là phần thêm của A5.
library;

import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flowmoney/features/transaction/domain/doc_hoa_don.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ hoá đơn siêu thị: lấy dòng TỔNG, không lấy tiền khách đưa lớn hơn', () {
    final kq = docHoaDonTuChu('''
CO.OPMART NGUYEN TRAI
Ngay: 28/09/2026 18:42
Sau rieng Ri6   1   152.000
Nuoc suoi       2    39.862
TONG CONG              191.862
Tien khach dua         200.000
Tien thoi lai            8.138
''');
    expect(kq.tong, 191862, reason: 'tiền khách đưa (200.000) lớn hơn tổng — lấy số lớn nhất là sai');
    expect(kq.cuaHang, 'CO.OPMART NGUYEN TRAI');
    expect(kq.ngay, '28/09/2026');
  });

  test('nhãn và số bị OCR tách hai dòng → nhìn dòng kế', () {
    final kq = docHoaDonTuChu('Quán Phở Hùng\nPhở tái 45.000\nTổng thanh toán\n90.000 đ\nCảm ơn quý khách');
    expect(kq.tong, 90000);
  });

  test('nhiều dòng tổng: "Tổng thanh toán" thắng "Thành tiền" của từng dòng hàng', () {
    final kq = docHoaDonTuChu('Cà phê sữa\nThành tiền 35.000\nBánh mì\nThành tiền 25.000\nTổng thanh toán: 60.000');
    expect(kq.tong, 60000);
  });

  test('cùng nhãn hai lần → dòng SAU thắng (tổng sau giảm giá nằm dưới)', () {
    final kq = docHoaDonTuChu('Tổng cộng 120.000\nGiảm giá 20.000\nTổng cộng 100.000');
    expect(kq.tong, 100000);
  });

  test('không có nhãn nào → số lớn nhất, bỏ số quá dài (điện thoại, mã vạch)', () {
    final kq = docHoaDonTuChu('Tap hoa Co Ba\nDT 0901234567\nMi goi 12.000\nTrung 30.000\n8934563138165');
    expect(kq.tong, 30000);
    expect(kq.canCu, contains('không nhãn'));
  });

  test('biên lai chuyển khoản: "Số tiền"', () {
    final kq = docHoaDonTuChu('MB Bank\nGiao dịch thành công\nSố tiền 1.250.000 VND\nNgày 01-10-26');
    expect(kq.tong, 1250000);
    expect(kq.ngay, '01/10/2026');
  });

  test('chữ rỗng → không có gì, không ném', () {
    expect(docHoaDonTuChu('  \n ').tong, isNull);
  });

  test('giờ in trên hoá đơn đi cùng ngày; không có giờ thì null', () {
    final kq = docHoaDonTuChu('CO.OPMART\nNgay: 28/09/2026 18:42\nTONG CONG 191.862');
    expect(kq.ngay, '28/09/2026');
    expect(kq.gio, '18:42');
    expect(docHoaDonTuChu('Pho\nTong 90.000').gio, isNull);
  });

  test('giờ sai (25:61) không nhận', () {
    expect(docHoaDonTuChu('X\n01/10/2026 25:61\nTong 10.000').gio, isNull);
  });

  // 2026-10-22 (người dùng duyệt): ỦA TEA tờ N01 (`/quet` thật, Realme 2026-10-21) in *"Giò vào: 1407"* — OCR đọc "Giờ"
  // thành "Giò" và không có dấu hai chấm giữa giờ và phút; cả tờ không có HH:MM nào nên form để 00:00.
  group('giờ sau nhãn "Giờ" không có dấu hai chấm — đường dự phòng', () {
    for (final (dong, gio) in [
      ('Giò vào: 1407', '14:07'),
      ('(GF-264_TH8HW) Giò ra: 1407', '14:07'),
      ('Giờ ra: 14.26', '14:26'),
      ('Giò vào::1426 F7 F8', '14:26'),
      ('Giờ: 907', '09:07'),
      ('Gio vao 2105', '21:05'),
    ]) {
      test('"$dong" → $gio', () {
        expect(docHoaDonTuChu('ỦA TEA\nNgày: 14/10/2026\n$dong\nTổng tiền: 398,800 d').gio, gio);
      });
    }

    test('⭐ tờ đã có giờ HH:MM ở chỗ khác → HH:MM thắng (chỉ là đường dự phòng)', () {
      expect(docHoaDonTuChu('ỦA TEA\nGiò vào: 1407\nNgày: 14/10/2026 18:42\nTổng tiền: 398,800 d').gio, '18:42');
    });

    for (final dong in ['Giờ vào: 2507', 'Giờ vào: 1475', 'Giờ mở cửa: 0700', 'Giờ vàng 1407']) {
      test('"$dong" → không phải giờ', () {
        expect(docHoaDonTuChu('ỦA TEA\nNgày: 14/10/2026\n$dong\nTổng tiền: 398,800 d').gio, isNull);
      });
    }
  });

  // 2026-10-22: Starbucks tờ R01 ra ghi chú *STARBUCKS"* — dấu nháy là logo ™ / ® OCR đọc thành ký tự.
  group('tên cửa hàng: cắt ký tự không phải chữ / số ở HAI ĐẦU', () {
    for (final (dau, ten) in [
      ('STARBUCKS"', 'STARBUCKS'),
      ('"Quán Phở Hùng"', 'Quán Phở Hùng'),
      ('|BEE BEE MART|', 'BEE BEE MART'),
      ('™ABC Mart.', 'ABC Mart'),
      ('Cơm Tấm (Q1)', 'Cơm Tấm (Q1)'),
      ('BEE BEE MART 18K', 'BEE BEE MART 18K'),
      ('eco-shop Invoice', 'eco-shop Invoice'),
    ]) {
      test('"$dau" → "$ten"', () {
        expect(docHoaDonTuChu('$dau\nDELIVERS\nTotal 262,000').cuaHang, ten);
      });
    }
  });

  test('kNhanTongHoaDon / kNhanLoaiHoaDon công khai, cùng nội dung spike', () {
    expect(kNhanTongHoaDon.first, 'tong thanh toan');
    expect(kNhanLoaiHoaDon, contains('khach dua'));
  });

  test('⭐ hoá đơn hai cột: ghép theo hàng rồi mới đọc → tổng 191.862, không phải tiền khách đưa', () {
    // Hoá đơn hai cột như ảnh thử T01 trên Realme: khối nhãn (trái) rồi mới tới khối số (phải). Hàng cao 30, cách 44.
    DongOcr nhan(String chu, int hang) =>
        DongOcr(chu, trai: 40, tren: 100.0 + 44 * hang, phai: 300, duoi: 130.0 + 44 * hang);
    DongOcr so(String chu, int hang) =>
        DongOcr(chu, trai: 500, tren: 100.0 + 44 * hang, phai: 640, duoi: 130.0 + 44 * hang);
    final haiCot = [
      nhan('CO.OPMART NGUYEN TRAI', 0),
      nhan('Sau rieng Ri6', 1),
      nhan('Nuoc suoi', 2),
      nhan('TONG CONG', 3),
      nhan('Tien khach dua', 4),
      nhan('Tien thoi lai', 5),
      so('152.000', 1),
      so('39.862', 2),
      so('191.862', 3),
      so('200.000', 4),
      so('8.138', 5),
    ];
    expect(docHoaDonTuChu(haiCot.map((d) => d.chu).join('\n')).tong, 200000,
        reason:
            'tiền đề: nối theo thứ tự ML Kit trả về thì nhãn TONG CONG không có số cạnh nó — đúng lỗi đo trên Realme');
    final ghep = ghepDongTheoHang(haiCot);
    expect(ghep.split('\n'), contains('TONG CONG 191.862'));
    expect(docHoaDonTuChu(ghep).tong, 191862);
  });
}
