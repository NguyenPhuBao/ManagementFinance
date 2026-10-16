/// A5 — chữ OCR THẬT của một hoá đơn siêu thị nhăn (MAXIDI, chụp trên OnePlus 13R, nghiệm thu 2026-10-08). Bốn lỗi
/// lượt nghiệm thu bắt được mà mọi ca dựng tay đều mù:
/// 1. *"Tổng"* bị OCR đọc thành *"Teng"* → không thấy nhãn tổng → rơi về số lớn nhất = tiền khách đưa (500.000).
/// 2. Dòng đầu là nhãn dán *"intel"* của laptop phía sau → ghi chú *"tel"*.
/// 3. Ngày in *9/11/2026* ở TƯƠNG LAI (máy POS in tháng trước ngày) → người dùng chốt: đảo ngày/tháng nếu ra quá khứ.
/// 4. Dòng món bị dính hàng, chữ số đọc nhầm → danh sách món rác — người dùng chốt TẠM TẮT tick món (A5b).
library;

import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flowmoney/features/transaction/domain/doc_hoa_don.dart';
import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';
import 'package:flutter_test/flutter_test.dart';

const _maxidi = '''
tel
MAXIDI ORE
LUON RẺ NHAT
KHÔNG CO ĐỐI THỦ
he gir at Cuar 12 HCM fGi19
Giá
SL 11,900 V08
1N1 Siuka 11,900 5,000 5.000 VO8
Shack bá 9.500 9,500 V08
Nà bóng 6.900 V08
Phe Bò V Bun ged 6,900 7,500 7,500 V06
24.906 24,900 V08
4,500 4.500 VO8
Kem dua 6,500 5,509 VO8
Teng 75,706
Tiân mặt 500,000
Tiên mặt (Hcân) NO 424.300 PgUp
Đã bao gôm thuế:
VO8 8 % 75,700 5,607
Ngày Gid CH POS Tên Số GD Pg Dn
9/11/2026 19:42 2066 4 02 1286
Nguyên tdc lat trôn tiến:
<5004 1àn trôn xuong 0d
>=5004 làm tròn thanh 1.000d
Shif
Néu quý khách có phàn nàn hoậc khern nggi
vui lông truy cập khaosat.maxidi.vn
Biên lai tirh fiên chỉ có giá tri
xuất hóa dơn GTGT trong ngày.''';

void main() {
  final luc = DateTime(2026, 10, 8, 10, 52);

  test('⭐ nhãn tổng đọc nhầm "Teng" vẫn là dòng tổng — KHÔNG lấy tiền khách đưa 500.000', () {
    expect(docHoaDonTuChu(_maxidi).tong, 75706, reason: 'chữ số 75,700 bị OCR đọc thành 75,706 — luật không chữa được');
  });

  test('ghi chú bỏ dòng ngắn hơn 4 chữ cái liền ("tel" của nhãn dán intel)', () {
    expect(docHoaDonTuChu(_maxidi).cuaHang, 'MAXIDI ORE');
  });

  test('⭐ ngày in ở tương lai → đảo ngày/tháng khi ra quá khứ (9/11 → 11/09)', () {
    final kq = docAnhQuet(vanBan: _maxidi, luc: luc);
    expect(kq.thoiGian, DateTime(2026, 9, 11, 19, 42));
    expect(kq.oThieu.contains(OAnhQuet.thoiGian), isFalse);
  });

  test('ngày tương lai mà đảo vẫn tương lai / không hợp lệ → lúc quét, ô thiếu', () {
    final kq = docAnhQuet(vanBan: 'Quan A\nNgay 25/12/2026\nTong cong 50.000', luc: luc);
    expect(kq.thoiGian, luc);
    expect(kq.oThieu, contains(OAnhQuet.thoiGian));
  });

  group('docMonHang — mã thuế đuôi dòng, số lượng đầu dòng, dừng ở tổng đọc nhầm', () {
    test('mã thuế V08 / VO8 / V06 sau số tiền bị bỏ; số lượng đầu dòng không vào tên', () {
      final ds = docMonHang('1 Mi Siuka 11,900 11,900 V08\n2 Kem dua 5,500 11,000 VO8\nTong 22.900');
      expect([for (final m in ds) (m.ten, m.soTien)], [('Mi Siuka', 11900.0), ('Kem dua', 11000.0)]);
    });

    test('"Teng" (tổng đọc nhầm) dừng đọc — "Tiền mặt" sau đó không thành món', () {
      final ds = docMonHang('Kem dua 5,500 V08\nTeng 5,500\nTien mat 500,000');
      expect(ds.map((m) => m.ten), ['Kem dua']);
    });
  });
}
