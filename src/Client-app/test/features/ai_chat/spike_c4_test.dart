/// Spike C4 — phần thuần: luật đọc hoá đơn từ chữ OCR (lối A) và đọc JSON của mô hình (lối B). Mã spike là mã bỏ đi,
/// nhưng số đo của lối A chỉ có nghĩa khi luật ấy đọc đúng những hoá đơn rõ ràng — nếu không, phép so A / B là so một
/// bộ luật hỏng với mô hình.
library;

import 'package:flowmoney/features/ai_chat/spike/spike_c4.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('docSoHoaDon', () {
    test('ngăn nghìn bằng chấm hoặc phẩy, bỏ phần lẻ', () {
      expect(docSoHoaDon('191.862'), 191862);
      expect(docSoHoaDon('1,250,000'), 1250000);
      expect(docSoHoaDon('45.000,00'), 45000);
      expect(docSoHoaDon('45000'), 45000);
      expect(docSoHoaDon('12.5'), 12);
    });
  });

  group('docHoaDonTuChu — lối A', () {
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
  });

  group('ghepDongTheoHang — ML Kit trả chữ theo CỘT, luật đọc theo HÀNG', () {
    // Hoá đơn hai cột như ảnh thử T01 trên Realme: khối nhãn (trái) rồi mới tới khối số (phải). Hàng cao 30, cách 44.
    DongOcr nhan(String chu, int hang) => DongOcr(chu, trai: 40, tren: 100.0 + 44 * hang, phai: 300, duoi: 130.0 + 44 * hang);
    DongOcr so(String chu, int hang, {double lech = 0}) =>
        DongOcr(chu, trai: 500, tren: 100.0 + 44 * hang + lech, phai: 640, duoi: 130.0 + 44 * hang + lech);

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

    test('⭐ hoá đơn hai cột: ghép theo hàng rồi mới đọc → tổng 191.862, không phải tiền khách đưa', () {
      expect(docHoaDonTuChu(haiCot.map((d) => d.chu).join('\n')).tong, 200000,
          reason: 'tiền đề: nối theo thứ tự ML Kit trả về thì nhãn TONG CONG không có số cạnh nó — đúng lỗi đo trên Realme');
      final ghep = ghepDongTheoHang(haiCot);
      expect(ghep.split('\n'), contains('TONG CONG 191.862'));
      expect(docHoaDonTuChu(ghep).tong, 191862);
    });

    test('trong một hàng: trái trước phải sau, bất kể thứ tự đầu vào', () {
      expect(ghepDongTheoHang([so('90.000', 0), nhan('Tong thanh toan', 0)]), 'Tong thanh toan 90.000');
    });

    test('các hàng xếp từ trên xuống, bất kể thứ tự đầu vào', () {
      expect(ghepDongTheoHang([nhan('Dong duoi', 2), nhan('Dong tren', 0), nhan('Dong giua', 1)]),
          'Dong tren\nDong giua\nDong duoi');
    });

    test('số lệch vài điểm ảnh so với nhãn (ảnh hơi nghiêng) vẫn cùng hàng; hàng kế thì KHÔNG bị gộp', () {
      final ghep = ghepDongTheoHang([nhan('TONG CONG', 0), nhan('Tien khach dua', 1), so('191.862', 0, lech: 9), so('200.000', 1, lech: 9)]);
      expect(ghep, 'TONG CONG 191.862\nTien khach dua 200.000');
    });

    test('dòng tiêu đề chữ to không nuốt hàng ngay dưới nó, dù khung của nó trùm tới tâm dòng ấy', () {
      // Khung tiêu đề 20–120 chứa tâm (111) của dòng dưới; tâm tiêu đề (70) thì KHÔNG nằm trong khung dòng dưới.
      final ghep = ghepDongTheoHang([
        const DongOcr('SIEU THI', trai: 40, tren: 20, phai: 600, duoi: 120),
        const DongOcr('28/09/2026', trai: 400, tren: 96, phai: 600, duoi: 126),
      ]);
      expect(ghep, 'SIEU THI\n28/09/2026', reason: 'cùng hàng phải đúng ở CẢ HAI chiều — một chiều là chữ to nuốt chữ nhỏ');
    });

    test('không có dòng nào → chuỗi rỗng, không ném', () {
      expect(ghepDongTheoHang(const []), '');
    });
  });

  group('docHoaDonTuJson — lối B', () {
    test('JSON trong rào ```json``` với số nguyên', () {
      final kq = docHoaDonTuJson('```json\n{"tong": 191862, "cua_hang": "Co.opmart", "ngay": "28/09/2026"}\n```')!;
      expect((kq.tong, kq.cuaHang, kq.ngay), (191862, 'Co.opmart', '28/09/2026'));
    });

    test('tổng là chuỗi có ngăn nghìn và ký hiệu', () {
      expect(docHoaDonTuJson('{"tong": "191.862 đ", "cua_hang": "", "ngay": ""}')!.tong, 191862);
    });

    test('không phải JSON → null (người chấm xem chữ thô)', () {
      expect(docHoaDonTuJson('Tổng tiền là 191.862 đồng.'), isNull);
    });
  });

  test('bản thường: cờ spike TẮT', () {
    expect(kSpikeC4, isFalse, reason: 'flutter test không truyền --dart-define=SPIKE_C4');
  });
}
