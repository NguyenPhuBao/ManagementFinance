/// Trang chủ bỏ ba khối thừa — nhóm D (D10, D11), 2026-09-19.
///
/// Trang chủ từng có **năm** lối vào cùng một màn Thêm giao dịch: nút hero, ba
/// nút tròn, và FAB. Ba nút tròn từ C4 đã đặt sẵn chiều Chi/Thu/Chuyển nên
/// nhanh hơn hero; hero là lối vào duy nhất **không thêm được gì** mà chiếm cả
/// một hàng đầu màn. Cùng với slogan hai dòng (~120dp không nói gì về tiền của
/// người dùng), nó đẩy số dư xuống quá sâu.
///
/// "Xem báo cáo" bỏ theo: báo cáo vẫn vào được từ drawer ("Xuất báo cáo") và
/// từ tab Phân tích.
///
/// ## Vì sao quét nguồn chứ không dựng widget
///
/// Dựng `HomePage` thật đòi `GetIt` (`AppDatabase`, các cubit) và bảy stream —
/// một ca test phải dựng nửa cái app là ca giòn, và nó đỏ vì những lý do
/// chẳng liên quan. Đây là khuôn đã dùng cho mười hai test quét `lib/` khác
/// của dự án.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final nguon = File('lib/features/home/presentation/pages/home_page.dart')
      .readAsStringSync();

  test('không còn slogan hai dòng (D11)', () {
    expect(nguon.contains('Kiểm soát tiền bạc'), isFalse,
        reason: 'Slogan chiếm khoảng 120dp đầu màn và không nói gì về tiền '
            'của người dùng; bỏ nó thì số dư lên gần đỉnh màn.');
  });

  test('không còn nút hero và nút "Xem báo cáo" (D10)', () {
    expect(nguon.contains('HomeActionButtons'), isFalse);
    expect(nguon.contains('_buildHeroSection'), isFalse);
  });

  test('widget HomeActionButtons đã xoá khỏi cây nguồn', () {
    expect(
        File('lib/features/home/presentation/widgets/home_action_buttons.dart')
            .existsSync(),
        isFalse,
        reason: 'Còn 0 chỗ gọi sau khi bỏ hero. Giữ lại một widget không ai '
            'dùng là đúng thứ lượt soát 2026-09-10 đã dặn phải quét trước khi '
            'commit.');
  });

  test('⚠️ luồng xác nhận đăng xuất của drawer KHÔNG nằm ở HomePage', () {
    expect(nguon.contains('xacNhanDangXuat'), isFalse,
        reason: 'Nghiệm thu Realme 2026-10-03: luồng ấy từng nằm ở đây và dùng '
            'context của drawer — đóng drawer là gỡ context, nên sau hộp thoại '
            '`mounted == false` và bấm "Đăng xuất" không làm gì. Nay '
            '`DrawerTrangChu` tự đóng và tự hỏi bằng context của Scaffold (có '
            'ca test mở drawer thật); HomePage chỉ đăng xuất.');
  });

  test('ba nút tròn đặt sẵn chiều vẫn còn — chúng là lối vào nhanh nhất', () {
    for (final huong in ["'thu'", "'chi'", "'transfer'"]) {
      expect(nguon.contains("push('/add', extra: $huong)"), isTrue,
          reason: 'Ba nút tròn đặt sẵn chiều từ C4, nên chúng nhanh hơn hero '
              'vừa bỏ. Mất chúng là Trang chủ chỉ còn FAB.');
    }
  });

  test('C4: nút Nói nối dây — có quyền thì /add?noi=1, Basic thì màn Nâng cấp (duongNutNoi)', () {
    // Quét nguồn (khuôn của cả tệp này): dựng HomePage thật đòi nửa cái app. Phần chọn đường đã có ca thuần ở
    // `presentation/widgets/hang_nut_nhanh_test.dart`; ở đây canh HomePage gọi đúng hàm đó với đúng quyền.
    expect(nguon.contains("Key('nut-nhanh-noi')"), isTrue);
    expect(
      nguon.contains('context.push(duongNutNoi(coQuyen: context.coQuyenDoc(MaQuyen.aiQuickInput)))'),
      isTrue,
      reason: 'C4 2026-10-12: nút Nói phải xét quyền aiQuickInput (cùng quyền với ô Nhập nhanh).',
    );
    expect(nguon.contains('HangNutNhanh('), isTrue);
    expect(nguon.contains('_buildActionItem'), isFalse, reason: 'C4 2026-10-12: đã tách thành HangNutNhanh.');
  });

  test('năm nút theo Stitch c8f09f19: biểu tượng, và chỉ Thêm chi nền đậm (người dùng chốt 2026-10-16)', () {
    // Quét nguồn: mỗi khối NutNhanh từ biểu tượng tới cờ `dam` nằm liền nhau trong `_buildQuickActions`.
    String khoiCua(String nhan) {
      final i = nguon.indexOf("nhan: '$nhan'");
      expect(i, greaterThan(0), reason: 'Không tìm thấy nút "$nhan".');
      final dau = nguon.lastIndexOf('NutNhanh(', i);
      return nguon.substring(dau, nguon.indexOf('onTap:', i));
    }

    for (final (nhan, bieuTuong, dam) in [
      ('Thêm thu', 'Icons.arrow_downward,', false),
      ('Thêm chi', 'Icons.arrow_upward,', true),
      ('Chuyển', 'Icons.sync_alt,', false),
      ('Quét', 'Icons.qr_code_scanner,', false),
      ('Nói', 'Icons.mic,', false),
    ]) {
      final khoi = khoiCua(nhan);
      expect(khoi.contains('bieuTuong: $bieuTuong'), isTrue, reason: 'Stitch vẽ "$nhan" bằng $bieuTuong');
      expect(khoi.contains('dam: $dam'), isTrue,
          reason: 'Stitch: chỉ Thêm chi nền đậm; Thêm thu nền trắng viền như ba nút còn lại.');
    }
  });
}
