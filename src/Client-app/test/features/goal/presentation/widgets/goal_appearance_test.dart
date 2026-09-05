import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_appearance.dart';

void main() {
  group('mauMucTieu', () {
    test('đọc mã hex có dấu thăng', () {
      expect(mauMucTieu('#4CAF50'), const Color(0xFF4CAF50));
    });

    test('đọc mã hex KHÔNG có dấu thăng', () {
      expect(mauMucTieu('4CAF50'), const Color(0xFF4CAF50),
          reason: 'Cột colour đi qua đồng bộ và Admin-web; không có gì bảo đảm '
              'mọi hàng đều có dấu thăng. Bỏ nhánh này thì một mục tiêu kéo về '
              'từ server hiện ra màu dự phòng mà không ai hiểu vì sao.');
    });

    test('chuỗi rác thì rơi về màu mặc định thay vì ném', () {
      expect(mauMucTieu('xanh lá'), kMauMucTieuMacDinh,
          reason: 'Đây là hàm chạy trong build(). Ném ra ở đây là MÀN ĐỎ trên '
              'trang danh sách, và một hàng dữ liệu hỏng sẽ kéo sập cả trang '
              'chứ không chỉ thẻ của nó.');
    });

    test('chuỗi rỗng thì rơi về màu mặc định', () {
      expect(mauMucTieu(''), kMauMucTieuMacDinh);
    });
  });

  group('bieuTuongMucTieu', () {
    test('tên đã biết trả đúng biểu tượng', () {
      expect(bieuTuongMucTieu('directions_car'), Icons.directions_car);
      expect(bieuTuongMucTieu('school'), Icons.school);
    });

    test('tên lạ rơi về lá cờ', () {
      expect(bieuTuongMucTieu('con-ngua-bay'), Icons.flag,
          reason: 'Cột icon là chuỗi tự do ở cả hai đầu đồng bộ. Một tên lạ '
              'phải hiện được thành thứ gì đó, không được làm hỏng thẻ.');
    });

    test('mặc định của CSDL là "flag" và nó nằm trong bảng tra', () {
      expect(bieuTuongMucTieu('flag'), Icons.flag,
          reason: 'GoalsCompanion đặt mặc định là "flag". Nếu nó chỉ khớp nhờ '
              'nhánh dự phòng thì bảng tra và CSDL đã lệch nhau mà không ai '
              'biết.');
    });

    test('biểu tượng hiện tại nằm ngoài bảng thì được CHÈN vào đầu', () {
      final ds = danhSachBieuTuong('flag');

      expect(ds.first, 'flag',
          reason: 'Mục tiêu tạo bởi bản app trước mang icon "flag", vốn không '
              'có trong bảng chọn. Không chèn nó vào thì trang sửa mở ra với '
              'KHÔNG ô nào được tô — người dùng tưởng chưa chọn gì. Còn tự '
              'nhảy sang ô đầu bảng thì đổi biểu tượng sau lưng họ, chỉ vì họ '
              'vào sửa cái tên.');
      expect(ds.length, kBieuTuongMucTieu.length + 1);
    });

    test('biểu tượng hiện tại đã có trong bảng thì không nhân đôi', () {
      final ds = danhSachBieuTuong('school');
      expect(ds.length, kBieuTuongMucTieu.length);
      expect(ds.where((e) => e == 'school').length, 1);
    });

    test('mọi lựa chọn trong bảng chọn đều tra được', () {
      for (final ten in kBieuTuongMucTieu) {
        expect(bieuTuongMucTieu(ten), isNot(Icons.flag),
            reason: 'Bảng chọn và bảng tra phải khớp nhau. Một lựa chọn không '
                'có trong bảng tra sẽ hiện lá cờ ngay sau khi người dùng vừa '
                'chọn một biểu tượng khác — im lặng, không lỗi. '
                '(Lá cờ cố ý không nằm trong kBieuTuongMucTieu để phép kiểm '
                'này có nghĩa.)');
      }
    });
  });
}
