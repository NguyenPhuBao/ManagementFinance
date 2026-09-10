/// "Hàng này có được tính vào thống kê không" — **một luật, một chỗ**.
///
/// Trước bản này luật ấy là câu `loai != 'transfer'` chép tay ở **năm** chỗ:
/// bốn trong `bao_cao_xuat.dart` (danh sách, gom theo danh mục, dòng tiền, so
/// kỳ trước) và một trong `thong_ke_thang.dart`. Thêm khoản **điều chỉnh số
/// dư** vào danh sách bị loại nghĩa là sửa cả năm — hoặc gom chúng lại trước.
///
/// Gom lại rẻ hơn và bền hơn: chỗ nào quên vế mới thì con số ở đó lệch với bốn
/// chỗ kia, và người dùng thấy cùng một khoản tiền được đếm ở màn này mà không
/// ở màn kia — không màn nào nói ra.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/analytics/domain/khoan_vao_thong_ke.dart';

void main() {
  test('thu và chi bình thường thì được tính', () {
    expect(
      khoanVaoThongKe(loai: 'thu', categoryId: 'c1', ghiChu: 'Lương'),
      isTrue,
    );
    expect(
      khoanVaoThongKe(loai: 'chi', categoryId: 'c1', ghiChu: 'Cà phê'),
      isTrue,
    );
  });

  test('khoản chuyển KHÔNG được tính', () {
    expect(
      khoanVaoThongKe(loai: 'transfer', categoryId: null, ghiChu: 'Nạp mục tiêu'),
      isFalse,
      reason: 'Tiền đổi chỗ không phải thu cũng không phải chi — đếm nó là mỗi '
          'kỳ trích tự động vào mục tiêu làm "Tổng chi" tăng.',
    );
  });

  test('khoản ĐIỀU CHỈNH SỐ DƯ không được tính', () {
    expect(
      khoanVaoThongKe(
          loai: 'thu', categoryId: null, ghiChu: 'Điều chỉnh số dư: đếm lại ví'),
      isFalse,
      reason: 'Khoản bù là phép SỬA SỔ, không phải thu nhập. Đếm nó là tháng '
          'nào người dùng đối soát ví cũng thấy "thu nhập" tăng vọt.',
    );
    expect(
      khoanVaoThongKe(loai: 'chi', categoryId: null, ghiChu: 'Điều chỉnh số dư'),
      isFalse,
    );
  });

  test('khoản chưa phân loại THẬT thì vẫn được tính', () {
    expect(
      khoanVaoThongKe(loai: 'chi', categoryId: null, ghiChu: 'Mua đồ'),
      isTrue,
      reason: 'Giao dịch kéo về từ server có thể trống danh mục — 17 hàng như '
          'thế đã có trên CSDL, đo 2026-09-10. Loại chúng là giấu mất chi tiêu '
          'thật của người dùng.',
    );
    expect(
      khoanVaoThongKe(loai: 'thu', categoryId: null, ghiChu: null),
      isTrue,
    );
  });

  test('ghi chú trùng khuôn nhưng CÓ danh mục thì vẫn được tính', () {
    expect(
      khoanVaoThongKe(
          loai: 'chi', categoryId: 'c1', ghiChu: 'Điều chỉnh số dư'),
      isTrue,
      reason: 'Người dùng gõ đúng câu ấy vào một khoản chi thật là chuyện xảy '
          'ra được; chân danh mục giữ cho khoản ấy không bị giấu đi.',
    );
  });
}
