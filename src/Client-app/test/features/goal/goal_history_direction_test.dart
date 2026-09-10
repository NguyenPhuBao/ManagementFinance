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

    test('HẬU TỐ "(tự động)" không làm khoản nạp đọc thành khoản rút', () {
      expect(
        laKhoanRutKhoiMucTieu(
          ghiChu: '${kGhiChuNapMucTieu}MuaXe$kHauToTuDong',
          viCuaHang: 'vi-tien-mat',
          viTichLuy: 'vi-tien-mat',
        ),
        isFalse,
        reason: 'Bất biến giữ cho cả hai tính năng cùng sống: phép đọc chiều '
            'tiền dùng `startsWith` nên hậu tố không được đụng tới nó. Hỏng ở '
            'đây thì MỌI khoản trích tự động hiện dấu trừ, và ca ví trùng ở '
            'trên còn giấu luôn phương án dự phòng.',
      );
    });
  });

  /// Canh chừng điều gì: nhãn "(tự động)" là **cách duy nhất** phân biệt khoản
  /// trích tự động với khoản nạp tay — hai thứ cố ý giống hệt nhau trên mọi cột
  /// (mục 3.12 `GOAL_FEATURE.md`) để phép đọc chiều tiền dùng chung được một
  /// tiền tố. Nhận nhầm là dán chữ "Tự động" lên khoản người dùng tự bấm.
  group('laKhoanTuDong', () {
    test('ghi chú do bộ trích tự động sinh ra thì nhận là tự động', () {
      expect(
        laKhoanTuDong('${kGhiChuNapMucTieu}MuaXe$kHauToTuDong'),
        isTrue,
      );
    });

    test('khoản nạp KHÔNG có hậu tố đọc là tay', () {
      expect(
        laKhoanTuDong('${kGhiChuNapMucTieu}MuaXe'),
        isFalse,
        reason: 'Mọi khoản ghi trước đợt này đều không có hậu tố. Đoán ngược '
            'cho lịch sử cũ là bịa ra một sự thật chưa từng được ghi lại; nhãn '
            'tự lành từ kỳ trích kế tiếp.',
      );
    });

    test('CHỈ hậu tố thôi thì chưa đủ — phải có cả tiền tố khoản nạp', () {
      expect(
        laKhoanTuDong('Chuyển tiền cá nhân$kHauToTuDong'),
        isFalse,
        reason: 'Ghi chú SỬA ĐƯỢC. Người dùng gõ tay đúng ba chữ ấy vào một '
            'giao dịch bất kỳ không biến nó thành khoản do app tự chuyển — chỉ '
            'bộ trích tự động mới ghi ra đủ CẶP tiền tố + hậu tố.',
      );
    });

    test('khoản RÚT không bao giờ là tự động', () {
      expect(
        laKhoanTuDong('${kGhiChuRutMucTieu}MuaXe$kHauToTuDong'),
        isFalse,
        reason: 'Không có đường nào trong app tự rút tiền khỏi mục tiêu. Ghi '
            'chú này chỉ có thể là hàng bị sửa tay.',
      );
    });

    test('ghi chú rỗng đọc là tay', () {
      expect(laKhoanTuDong(''), isFalse);
    });
  });

  /// Canh chừng điều gì: trang chi tiết hiện **ghi chú thô** làm tiêu đề dòng.
  /// Không cắt hậu tố thì dòng ấy mang chữ "(tự động)" hai lần — một lần trong
  /// tiêu đề, một lần trong chip — trong khi bảng đầy đủ chỉ có chip.
  group('ghiChuKhongHauTo', () {
    test('cắt hậu tố khỏi ghi chú của khoản tự động', () {
      expect(
        ghiChuKhongHauTo('${kGhiChuNapMucTieu}MuaXe$kHauToTuDong'),
        '${kGhiChuNapMucTieu}MuaXe',
      );
    });

    test('ghi chú không có hậu tố thì giữ nguyên', () {
      expect(
        ghiChuKhongHauTo('${kGhiChuNapMucTieu}MuaXe'),
        '${kGhiChuNapMucTieu}MuaXe',
      );
    });

    test('KHÔNG cắt khi hậu tố không đi cùng tiền tố khoản nạp', () {
      expect(
        ghiChuKhongHauTo('Chuyển tiền cá nhân$kHauToTuDong'),
        'Chuyển tiền cá nhân$kHauToTuDong',
        reason: 'Đi cặp với `laKhoanTuDong`: chỗ nào không dán nhãn thì chỗ ấy '
            'cũng không được cắt chữ. Lệch nhau là ba chữ người dùng tự gõ bị '
            'xoá khỏi màn hình mà không có gì thay thế.',
      );
    });

    test('tên mục tiêu tình cờ kết thúc bằng "(tự động)" vẫn giữ nguyên tên',
        () {
      // Người dùng đặt tên mục tiêu là "Quỹ (tự động)".
      const ten = 'Quỹ$kHauToTuDong';
      expect(
        ghiChuKhongHauTo('$kGhiChuNapMucTieu$ten$kHauToTuDong'),
        '$kGhiChuNapMucTieu$ten',
        reason: 'Cắt ĐÚNG MỘT lần, ở cuối. Cắt lặp sẽ ăn luôn vào tên mục tiêu '
            'người dùng đặt.',
      );
    });
  });
}
