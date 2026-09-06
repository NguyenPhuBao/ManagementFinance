import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';

/// Canh chừng điều gì: nạp và rút đều là giao dịch `'transfer'` mang cùng một
/// `goal_id`, nên `type` không phân biệt được. Đọc sai chiều thì khoản rút hiện
/// lên **giống hệt khoản nạp** — cùng dấu `+`, cùng màu xanh — trong khi tiến
/// độ mục tiêu lại giảm.
void main() {
  group('laKhoanRutKhoiMucTieu', () {
    test('ghi chú "Rút từ mục tiêu" là khoản rút', () {
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: '${kGhiChuRutMucTieu}MuaXe',
          viCuaHang: 'vi-bat-ky',
          viTichLuy: 'vi-tiet-kiem',
        ),
        isTrue,
      );
    });

    test('ghi chú "Tích lũy mục tiêu" là khoản nạp', () {
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: '${kGhiChuNapMucTieu}MuaXe',
          viCuaHang: 'vi-bat-ky',
          viTichLuy: 'vi-tiet-kiem',
        ),
        isFalse,
      );
    });

    test('ĐỔI VÍ TÍCH LŨY không làm khoản nạp cũ đọc thành khoản rút', () {
      // Hàng nạp cũ: lúc ghi, ví nguồn là "Tiền mặt" và ví tích lũy là "Tiết
      // kiệm". Sau đó mục tiêu đổi ví tích lũy sang chính "Tiền mặt".
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: '${kGhiChuNapMucTieu}MuaDT',
          viCuaHang: 'vi-tien-mat',
          viTichLuy: 'vi-tien-mat',
        ),
        isFalse,
        reason: 'So vị trí ví là diễn giải hàng CŨ bằng cấu hình HIỆN TẠI của '
            'mục tiêu. Máy ảo đã bắt đúng ca này ngày 2026-09-05: đổi ví xong '
            'thì cả hai dòng lịch sử đều hiện dấu trừ, kể cả dòng người dùng '
            'thật sự đã gửi vào.',
      );
    });

    test('hàng lạ thì rơi về so vị trí ví', () {
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: 'Chuyển tiền cá nhân',
          viCuaHang: 'vi-tiet-kiem',
          viTichLuy: 'vi-tiet-kiem',
        ),
        isTrue,
        reason: 'Không do luồng mục tiêu sinh ra, hoặc ghi chú đã bị sửa — lúc '
            'này vị trí ví là căn cứ duy nhất còn lại.',
      );
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: 'Chuyển tiền cá nhân',
          viCuaHang: 'vi-tien-mat',
          viTichLuy: 'vi-tiet-kiem',
        ),
        isFalse,
      );
    });

    test('mục tiêu chưa có ví và ghi chú lạ thì coi là nạp', () {
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: 'Chuyển tiền cá nhân',
          viCuaHang: 'vi-tien-mat',
          viTichLuy: null,
        ),
        isFalse,
        reason: 'Mục tiêu do bản app cũ tạo chưa từng có luồng rút — mọi hàng '
            'cũ đều là nạp. Đoán bừa là hiện dấu trừ cho những khoản người dùng '
            'thật sự đã gửi vào.',
      );
    });
  });
}
