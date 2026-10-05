/// `docBienLai` — chữ trên ảnh biên lai (đã ghép theo hàng) → các trường của một khoản chờ ghi. Spec
/// `2026-10-02-chia-se-bien-lai-design.md` mục 5.
///
/// ⚠️ Mọi biên lai trong tệp này là DỰNG LẠI bằng số và tên giả theo hình dạng đã che thu trên máy thật — không chép
/// chữ thật của biên lai nào vào repo.
library;

import 'package:flowmoney/features/transaction/domain/doc_bien_lai.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

final _luc = DateTime(2026, 10, 2, 19, 0);

const _bienLaiChung = '''
Giao dịch thành công
Số tiền 150.000 VND
Người nhận NGUYEN VAN A
Tài khoản nhận 0123456789
Thời gian 02/10/2026 18:45
Mã giao dịch FT26275123456
Nội dung tra tien nha thang 10
Phí giao dịch 0 VND
''';

void main() {
  group('luật chung', () {
    test('⭐ biên lai có nhãn đủ: số tiền, giờ trên ảnh, mã GD, nội dung; chiều chi; cachDoc chung', () {
      final b = docBienLai(vanBan: _bienLaiChung, nguon: null, luc: _luc);
      expect(b.soTien, 150000);
      expect(b.chieu, 'chi');
      expect(b.thoiGian, DateTime(2026, 10, 2, 18, 45));
      expect(b.maGiaoDich, 'FT26275123456');
      expect(b.noiDung, 'tra tien nha thang 10');
      expect(b.duoiTaiKhoan, isNull, reason: 'tài khoản trên biên lai là của người NHẬN — không phải khoá chọn ví');
      expect(b.cachDoc, kCachDocChung);
    });

    test('⭐ số tài khoản và mã GD KHÔNG thành số tiền', () {
      final b = docBienLai(vanBan: 'Tài khoản nhận 1234567890123\nMã giao dịch 987654321012', nguon: null, luc: _luc);
      expect(b.soTien, isNull);
      expect(b.cachDoc, kCachDocKhong);
      expect(b.maGiaoDich, '987654321012', reason: 'không đọc ra tiền thì các trường khác vẫn điền nếu đọc được');
    });

    test('không nhãn "số tiền" → số có đơn vị đ / VND lớn nhất; hàng phí và số dư bị bỏ', () {
      final b = docBienLai(
          vanBan: 'Chuyển tiền thành công\n-250.000 đ\nPhí 1.100 đ\nSố dư 9.999.000 đ', nguon: null, luc: _luc);
      expect(b.soTien, 250000);
    });

    // Hình dạng biên lai ví điện tử (ảnh người dùng gửi 2026-10-05, dựng lại bằng số và tên GIẢ): tiêu đề "… thành
    // công" + số tiền ngay dưới, rồi các hàng thông tin, rồi khối QUẢNG CÁO của app mang một con số to hơn kèm "đ".
    // Bản cũ lấy số có đơn vị LỚN NHẤT → điền 5.000.000 thay vì 39.000.
    const viDienTu = '''
17:48
Kết quả giao dịch
Giao dịch thành công
Chia sẻ
39.000đ
Dịch vụ/ Cửa hàng CUA HANG A
Thời gian giao dịch 17:48 - 04/10/2026
Thưởng xu +3 Xu
Mã giao dịch 150000000001
Cửa Hàng A
308.4K người theo dõi Đã theo dõi
Quản lý chi tiêu Chợ, siêu thị
Tháng 10 biến động, An đã chi bao tiền?
Liệu đã tới 5.000.000đ?
Xem lại ngay
''';

    test('⭐ số tiền ngay dưới tiêu đề "… thành công" thắng số to hơn của khối quảng cáo bên dưới', () {
      final b = docBienLai(vanBan: viDienTu, nguon: null, luc: _luc);
      expect(b.soTien, 39000,
          reason: 'biên lai không có nhãn "Số tiền": số đầu tiên có đơn vị ngay sau tiêu đề thành công là số tiền '
              'giao dịch; số to hơn ở dưới là câu quảng cáo của app');
      expect(b.thoiGian, DateTime(2026, 10, 4, 17, 48));
      expect(b.maGiaoDich, '150000000001');
      expect(b.cachDoc, kCachDocChung);
    });

    test('tiêu đề thành công và số tiền CÙNG hàng (OCR gộp) cũng nhận; hàng phí ngay dưới tiêu đề bị bỏ', () {
      expect(docBienLai(vanBan: 'Giao dịch thành công 39.000đ\nLiệu đã tới 5.000.000đ?', nguon: null, luc: _luc)
          .soTien, 39000);
      expect(
          docBienLai(vanBan: 'Thanh toán thành công\nPhí 2.000đ\n45.000đ\nƯu đãi tới 1.000.000đ', nguon: null,
                  luc: _luc)
              .soTien,
          45000);
    });

    test('⭐ không tiêu đề thành công: hàng là CÂU HỎI ("…5.000.000đ?") không phải số tiền giao dịch', () {
      expect(docBienLai(vanBan: 'Thanh toán\n39.000đ\nLiệu đã tới 5.000.000đ?', nguon: null, luc: _luc).soTien,
          39000);
    });

    test('⭐ không nhãn VÀ không đơn vị → không phải số tiền (mã đơn 1.234.567 trông y như một số tiền)', () {
      final b = docBienLai(vanBan: 'Giao dịch thành công\nMã đơn 1.234.567\nĐiểm thưởng 2.500', nguon: null, luc: _luc);
      expect(b.soTien, isNull, reason: 'điền một con số không chắc là tiền thì tệ hơn để trống kèm ảnh');
    });

    test('⭐ hàng "Phí giao dịch" có số to hơn không thắng hàng "Số tiền"', () {
      final b = docBienLai(vanBan: 'Phí giao dịch 22.000 VND\nSố tiền 5.000 VND', nguon: null, luc: _luc);
      expect(b.soTien, 5000);
    });

    test('nhãn và số ở HAI hàng (OCR tách) → nhìn hàng kế; "Số tiền bằng chữ" không phải hàng số tiền', () {
      expect(docBienLai(vanBan: 'Số tiền\n75.000 VND', nguon: null, luc: _luc).soTien, 75000);
      expect(
          docBienLai(vanBan: 'Số tiền bằng chữ: Bảy mươi lăm nghìn đồng\nMã 1.234.567\nSố tiền 75.000 VND',
                  nguon: null, luc: _luc)
              .soTien,
          75000);
    });

    test('không có ngày trên ảnh → lúc chia sẻ; có ngày không có giờ → 00:00 của ngày ấy', () {
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ', nguon: null, luc: _luc).thoiGian, _luc);
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ\nNgày 01/10/2026', nguon: null, luc: _luc).thoiGian,
          DateTime(2026, 10, 1));
    });

    test('giờ đứng TRƯỚC ngày (18:45 - 02/10/2026) vẫn đọc được; ngày vô lý (45/13/2026) thì bỏ', () {
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ\n18:45 - 02/10/2026', nguon: null, luc: _luc).thoiGian,
          DateTime(2026, 10, 2, 18, 45));
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ\n45/13/2026', nguon: null, luc: _luc).thoiGian, _luc);
    });

    test('ảnh không phải biên lai / chữ rỗng → không số tiền, cachDoc khong, không ném', () {
      for (final v in ['', 'Hôm nay trời đẹp', 'Cuộc họp lúc 14:00', '\n\n  \n']) {
        final b = docBienLai(vanBan: v, nguon: null, luc: _luc);
        expect(b.soTien, isNull, reason: v);
        expect(b.cachDoc, kCachDocKhong);
        expect(b.chieu, 'chi');
        expect(b.thoiGian, _luc);
      }
    });

    test('số từ 1 tỷ trở lên không được điền (giới hạn của phép đọc số trên ảnh) — rơi về "chưa đọc được"', () {
      final b = docBienLai(vanBan: 'Số tiền 99.999.999.999.999 đ', nguon: null, luc: _luc);
      expect(b.soTien, isNull);
      expect(b.cachDoc, kCachDocKhong);
    });

    test('nội dung ở hàng kế nhãn; không nhãn nội dung → rỗng', () {
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ\nLời nhắn\nmua sach', nguon: null, luc: _luc).noiDung, 'mua sach');
      expect(docBienLai(vanBan: 'Số tiền 10.000 đ', nguon: null, luc: _luc).noiDung, '');
    });

    test('nhãn có dấu hai chấm và khoảng trắng thừa: "Nội dung :  mua sach"', () {
      expect(docBienLai(vanBan: 'Số tiền: 10.000 đ\nNội dung :  mua  sach', nguon: null, luc: _luc).noiDung,
          'mua sach');
    });
  });

  // Hình dạng thu trên Realme 2026-10-02 (đã che), dựng lại bằng số và tên GIẢ:
  //   … / Chuyển … thành công / 99,999 VND / 99:99 - 99/99/9999 / … … … / … … / … / …9999999999999999 /
  //   … … … chuyen tien / Giao dịch … / …
  // Các hàng theo thứ tự: logo · tiêu đề · số tiền · giờ · tên người nhận · ngân hàng / ví nhận (logo + tên, OCR ra
  // hai hàng) · tài khoản nhận (chữ liền số) · nội dung · hai hàng chân biên lai (chữ chung của MB, không riêng tư).
  const mb = '''
MB
Chuyển tiền thành công
10,000 VND
19:38 - 02/10/2026
NGUYEN VAN A
mo mo
MoMo
PSP0001234567890123
TRAN VAN B chuyen tien
Giao dịch được xác nhận bởi MB.
Vui lòng không chỉnh sửa hình ảnh này.
''';

  group('mẫu riêng MB Bank — biên lai không nhãn, đọc theo vị trí', () {
    test('⭐ biên lai chuyển tiền → số tiền, giờ, nội dung; chiều chi; cachDoc mau; KHÔNG mã giao dịch', () {
      final b = docBienLai(vanBan: mb, nguon: kNguonMb, luc: _luc);
      expect(b.soTien, 10000);
      expect(b.chieu, 'chi');
      expect(b.thoiGian, DateTime(2026, 10, 2, 19, 38));
      expect(b.noiDung, 'TRAN VAN B chuyen tien');
      expect(b.maGiaoDich, isNull,
          reason: 'hàng chữ liền số là TÀI KHOẢN người nhận (người dùng xác nhận) — lấy nó làm mã GD là gộp nhầm '
              'mọi lần chuyển cho cùng một người thành một giao dịch');
      expect(b.duoiTaiKhoan, isNull);
      expect(b.cachDoc, kCachDocMau);
    });

    test('⭐ không có hàng nội dung → nội dung RỖNG, không lấy số tài khoản người nhận làm ghi chú', () {
      final b = docBienLai(
          vanBan: mb.replaceFirst('TRAN VAN B chuyen tien\n', ''), nguon: kNguonMb, luc: _luc);
      expect(b.soTien, 10000);
      expect(b.noiDung, '');
    });

    test('khoản dưới 1.000 đ và khoản từ 1 tỷ vẫn đọc được — hàng số tiền của mẫu là CHẮC', () {
      expect(docBienLai(vanBan: mb.replaceFirst('10,000 VND', '500 VND'), nguon: kNguonMb, luc: _luc).soTien, 500);
      expect(
          docBienLai(vanBan: mb.replaceFirst('10,000 VND', '1,500,000,000 VND'), nguon: kNguonMb, luc: _luc).soTien,
          1500000000);
    });

    test('chữ "tiền" bị đọc lệch dấu ("Chuyển tiên thành công") vẫn khớp tiêu đề', () {
      final b = docBienLai(
          vanBan: mb.replaceFirst('Chuyển tiền thành công', 'Chuyển tiên thành công'), nguon: kNguonMb, luc: _luc);
      expect(b.cachDoc, kCachDocMau);
    });

    test('⭐ nguồn MB nhưng ảnh KHÔNG khớp mẫu (app đổi giao diện) → rơi về luật chung, không rơi về "không đọc"', () {
      final b = docBienLai(vanBan: _bienLaiChung, nguon: kNguonMb, luc: _luc);
      expect(b.soTien, 150000);
      expect(b.cachDoc, kCachDocChung);
    });

    test('thiếu hàng giờ ngay dưới số tiền → không phải mẫu này → luật chung (số tiền vẫn đọc được nhờ đơn vị VND)', () {
      final b = docBienLai(
          vanBan: 'Chuyển tiền thành công\n10,000 VND\nNGUYEN VAN A', nguon: kNguonMb, luc: _luc);
      expect(b.soTien, 10000);
      expect(b.cachDoc, kCachDocChung);
    });

    test('nguồn khác MB (MoMo, ZaloPay, "Biên lai", null) không thử mẫu MB dù chữ giống hệt', () {
      for (final n in [kNguonMomo, kNguonZalopay, 'Biên lai', null]) {
        final b = docBienLai(vanBan: mb, nguon: n, luc: _luc);
        expect(b.cachDoc, kCachDocChung, reason: '$n');
        expect(b.soTien, 10000, reason: 'luật chung vẫn đọc được số có đơn vị VND');
        expect(b.noiDung, '', reason: 'biên lai không nhãn: luật chung không biết hàng nào là nội dung');
      }
    });
  });
}
