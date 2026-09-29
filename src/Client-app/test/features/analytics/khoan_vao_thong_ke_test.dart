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
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

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

  test('khoản MỞ SỔ không vào thống kê', () {
    expect(khoanVaoThongKe(loai: 'thu', categoryId: null, ghiChu: ghiChuMoSo()),
        isFalse,
        reason: 'Nó là phép MỞ SỔ, không phải thu nhập. Đếm nó là mỗi ví người '
            'dùng tạo ra lại làm thu nhập tháng ấy tăng vọt — cùng lý do đã '
            'loại khoản điều chỉnh số dư.');
  });

  test('⭐ CẶP nạp mục tiêu DẠNG CŨ (trước 2026-09-05) không vào thống kê — cả nửa thu lẫn nửa chi', () {
    // Đo 2026-09-29 (Realme + PostgreSQL dev, tài khoản 10): bản app cũ ghi mỗi lần nạp thành HAI hàng thường —
    // thu 500.000 "Tích lũy nhận từ Tiền mặt: MuaXe" + chi 500.000 "Tích lũy mục tiêu: MuaXe", không danh mục.
    // Mọi màn đếm cả hai: chi tháng 9 2.351.000 thay vì 1.851.000. Tiền đổi chỗ, cùng lý do đã loại khoản chuyển.
    expect(khoanVaoThongKe(loai: 'thu', categoryId: null, ghiChu: '${kGhiChuNapMucTieuCu}Tiền mặt: MuaXe'), isFalse,
        reason: 'nửa THU của cặp dạng cũ — tiền vào ví tích luỹ, không phải thu nhập');
    expect(khoanVaoThongKe(loai: 'chi', categoryId: null, ghiChu: '${kGhiChuNapMucTieu}MuaXe'), isFalse,
        reason: 'nửa CHI của cặp dạng cũ — tiền rời ví nguồn sang ví tích luỹ, không phải chi tiêu');
  });

  test('ghi chú trùng khuôn nạp mục tiêu nhưng CÓ danh mục thì vẫn được tính (cặp dấu hiệu, như khoản điều chỉnh)', () {
    expect(khoanVaoThongKe(loai: 'chi', categoryId: 'c-mua-sam', ghiChu: '${kGhiChuNapMucTieu}MuaXe'), isTrue,
        reason: 'app không bao giờ ghi khoản nạp có danh mục — hàng có danh mục là người dùng tự gõ, giấu nó là giấu chi thật');
    expect(khoanVaoThongKe(loai: 'thu', categoryId: 'c-thuong', ghiChu: '${kGhiChuNapMucTieuCu}sếp'), isTrue);
  });

  test('khoản thu THẬT vẫn vào thống kê', () {
    expect(
        khoanVaoThongKe(
            loai: 'thu', categoryId: 'cat-luong', ghiChu: 'Lương tháng 9'),
        isTrue,
        reason: 'Loại nhầm khoản thu thật là giấu mất thu nhập của người dùng.');
  });
}
