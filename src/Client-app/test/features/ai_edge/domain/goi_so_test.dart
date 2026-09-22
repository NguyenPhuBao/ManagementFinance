/// Định dạng số liệu của gói số — thẻ số liệu, tập cho phép của bộ kiểm số,
/// và phần đưa vào prompt đều đọc đúng chuỗi này, nên nó phải theo đúng quy
/// ước tiền của app (chấm nghìn, `đ` có cách) và luật G2 (một chữ số thập
/// phân cho phần trăm).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('soTien dùng CurrencyFormatter: chấm nghìn, có cách, ký hiệu đ', () {
    expect(soTien('Đã chi', 2100000).chuoi, '2.100.000 đ');
    expect(soTien('Đã chi', 2100000).loai, LoaiSo.tien);
  });

  test('soPhanTram in ĐÚNG một chữ số thập phân, phẩy thập phân (G2)', () {
    expect(soPhanTram('Tăng', 12.5).chuoi, '12,5%');
    expect(soPhanTram('Tăng', 35).chuoi, '35,0%');
    expect(soPhanTram('Tăng', 12.55).chuoi, '12,6%',
        reason: 'làm tròn, không cắt');
    expect(soPhanTram('Giảm', -8.25).chuoi, '-8,3%',
        reason: 'số âm giữ dấu — hướng giảm phải đọc được');
  });

  test('soNgay và soDem', () {
    expect(soNgay('Còn', 9).chuoi, '9 ngày');
    expect(soNgay('Còn', 9).loai, LoaiSo.soNgay);
    expect(soDem('Số cam kết', 3).chuoi, '3');
    expect(soDem('Số cam kết', 3).loai, LoaiSo.soDem);
  });

  group('SoLieu.ten — tên đối tượng mang con số (chặng 4a)', () {
    test('mặc định null: số không thuộc đối tượng nào là ca THƯỜNG', () {
      expect(soTien('Tổng chi', 2141000).ten, isNull,
          reason: 'Tổng chi không thuộc về một danh mục nào. `null` ở đây là '
              'đúng nghĩa, không phải dấu hiệu thiếu dữ liệu.');
    });

    test('chép nguyên tên đối tượng, KHÔNG ghép vào nhãn', () {
      final s = soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục');
      expect(s.ten, 'Giáo dục');
      expect(s.nhan, 'Tỉ lệ',
          reason: 'Ghép thành "Giáo dục · Tỉ lệ" là bẫy §3.1 của spec: '
              '`kiemNhan` đòi câu chứa MỌI âm tiết có nghĩa của nhãn, nên nhãn '
              'ghép đòi cả "tỉ" lẫn "lệ", và câu tự nhiên nhất — "Giáo dục đã '
              'dùng 90,0%" — bị chính lớp chắn ấy chặn, im lặng.');
    });

    test('cả bốn helper đều nhận ten', () {
      expect(soTien('Số dư', 1, ten: 'Tiền mặt').ten, 'Tiền mặt');
      expect(soPhanTram('Tỉ lệ', 1, ten: 'Giáo dục').ten, 'Giáo dục');
      expect(soNgay('Còn', 1, ten: 'MuaXe').ten, 'MuaXe');
      expect(soDem('Quá hạn', 1, ten: 'Kiem').ten, 'Kiem');
    });

    test('ten không làm đổi chuỗi hiển thị', () {
      expect(soTien('Số dư', 9903000, ten: 'Tiền mặt').chuoi, '9.903.000 đ',
          reason: '`chuoi` là ba thứ cùng lúc (thẻ, tập cho phép của bộ kiểm '
              'số, phần vào prompt) — thêm tên không được chạm vào nó.');
    });

    test('trần số mục mỗi gói là 4', () {
      expect(kToiDaMucMoiGoi, 4,
          reason: 'Prompt hỏi đáp đã 1.700 ký tự và token đầu 4,6 s trên CPU. '
              'Đây là tham số ĐO được: đổi nó thì phải đo lại trên máy thật.');
    });
  });
}
