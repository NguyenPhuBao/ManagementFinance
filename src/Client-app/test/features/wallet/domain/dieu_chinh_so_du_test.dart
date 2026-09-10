/// Điều chỉnh số dư ví (đối soát) — luật thuần.
///
/// Người dùng nhập **số dư thực tế** đếm được ngoài đời; app sinh một khoản
/// bù để lịch sử giao dịch khớp lại với số ấy. Khoản bù **không vào thống kê**:
/// nó không phải thu nhập cũng không phải chi tiêu, chỉ là phép sửa sổ.
///
/// ## Vì sao khoản bù nhận dạng bằng CẶP điều kiện
///
/// `transaction.Note` **sửa được**, nên một dấu hiệu chỉ nằm trong ghi chú có
/// thể mất — và mất thì khoản bù lặng lẽ trở thành thu nhập thật, tức sai một
/// **con số**, không chỉ sai một nhãn.
///
/// Chân thứ hai là cấu trúc: khoản bù **không mang danh mục**, mà giao diện
/// thêm giao dịch **bắt buộc chọn danh mục** cho mọi khoản `thu`/`chi`
/// (`add_transaction_page.dart:496`). Một khoản thu/chi không danh mục là thứ
/// giao diện không tạo ra được, nên nó là dấu hiệu thật.
///
/// Hai chân đều **đồng bộ được** — không cột cục bộ nào, khác hẳn cột `status`
/// của lưu trữ ví (G28).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';

void main() {
  group('tính khoản bù', () {
    test('số dư thực LỚN HƠN thì sinh một khoản THU', () {
      final k = tinhKhoanDieuChinh(soDuHienTai: 1000000, soDuThucTe: 1250000);

      expect(k, isNotNull);
      expect(k!.loai, 'thu');
      expect(k.soTien, 250000);
    });

    test('số dư thực NHỎ HƠN thì sinh một khoản CHI', () {
      final k = tinhKhoanDieuChinh(soDuHienTai: 1000000, soDuThucTe: 700000);

      expect(k!.loai, 'chi');
      expect(k.soTien, 300000,
          reason: 'Số tiền luôn DƯƠNG — chiều nằm ở `loai`, đúng quy ước của '
              'bảng `transactions` và của `_applyBalances`.');
    });

    test('bằng nhau thì KHÔNG sinh gì cả', () {
      expect(tinhKhoanDieuChinh(soDuHienTai: 1000000, soDuThucTe: 1000000),
          isNull,
          reason: 'PostgreSQL có `chk_transaction_nonzero_amount` bắt '
              '`Amount <> 0` (đo 2026-09-10), nên ghi một khoản 0đ là bản ghi '
              'vỡ ở tầng CSDL rồi kẹt hàng đợi đẩy. Đây là chốt chặn bắt buộc, '
              'không phải phép dọn cho gọn.');
    });

    test('ví đang âm về 0 vẫn ra một khoản THU', () {
      final k = tinhKhoanDieuChinh(soDuHienTai: -10000, soDuThucTe: 0);

      expect(k!.loai, 'thu');
      expect(k.soTien, 10000);
    });

    test('số dư thực âm cũng ra khoản đúng chiều', () {
      final k = tinhKhoanDieuChinh(soDuHienTai: 50000, soDuThucTe: -20000);

      expect(k!.loai, 'chi');
      expect(k.soTien, 70000);
    });

    test('phần lẻ nhỏ hơn một đồng KHÔNG được coi là chênh lệch', () {
      // Số dư là `double`, và mọi phép cộng dồn trên `double` đều để lại đuôi
      // lẻ. Không có ngưỡng thì một ví "đúng" vẫn đẻ ra khoản bù 0,0000001đ ở
      // mỗi lần mở màn — và `chk_transaction_nonzero_amount` cho nó đi qua vì
      // nó khác 0 thật.
      expect(
        tinhKhoanDieuChinh(soDuHienTai: 1000000.0000001, soDuThucTe: 1000000),
        isNull,
      );
    });
  });

  group('nhận dạng khoản bù', () {
    test('đủ CẶP điều kiện thì nhận', () {
      expect(
        laKhoanDieuChinh(
            loai: 'thu', categoryId: null, ghiChu: 'Điều chỉnh số dư'),
        isTrue,
      );
    });

    test('có ghi chú thêm của người dùng vẫn nhận', () {
      expect(
        laKhoanDieuChinh(
            loai: 'chi',
            categoryId: null,
            ghiChu: 'Điều chỉnh số dư: đếm lại ví tiền mặt'),
        isTrue,
      );
    });

    test('CÓ danh mục thì KHÔNG phải khoản bù, dù ghi chú trùng khuôn', () {
      expect(
        laKhoanDieuChinh(
            loai: 'chi', categoryId: 'c1', ghiChu: 'Điều chỉnh số dư'),
        isFalse,
        reason: 'Người dùng gõ đúng câu ấy vào ghi chú của một khoản chi thật '
            'là chuyện xảy ra được. Chân danh mục giữ cho khoản chi ấy vẫn '
            'được tính vào thống kê.',
      );
    });

    test('không danh mục nhưng ghi chú khác thì KHÔNG phải khoản bù', () {
      expect(
        laKhoanDieuChinh(loai: 'thu', categoryId: null, ghiChu: 'Lương tháng 9'),
        isFalse,
        reason: 'Giao dịch kéo về từ server có thể trống danh mục — 17 hàng '
            'như thế đã có trên CSDL, đo 2026-09-10. Chỉ mình chân danh mục '
            'rỗng mà loại khỏi thống kê là giấu mất thu chi thật.',
      );
    });

    test('ghi chú rỗng hoặc null thì KHÔNG phải khoản bù', () {
      expect(laKhoanDieuChinh(loai: 'thu', categoryId: null, ghiChu: null),
          isFalse);
      expect(
          laKhoanDieuChinh(loai: 'thu', categoryId: null, ghiChu: ''), isFalse);
    });

    test('khoản chuyển KHÔNG bao giờ là khoản bù', () {
      expect(
        laKhoanDieuChinh(
            loai: 'transfer', categoryId: null, ghiChu: 'Điều chỉnh số dư'),
        isFalse,
        reason: 'Khoản chuyển vốn đã bị loại khỏi thống kê bằng luật riêng; '
            'nhận nó ở đây là hai luật cùng nói về một hàng.',
      );
    });
  });

  test('ghi chú sinh ra đọc lại được bằng chính phép nhận dạng', () {
    // Vòng khép kín: nơi GHI và nơi ĐỌC dùng chung một khuôn, nên không thể
    // lệch nhau — cùng cách `goal_history_direction.dart` giữ ba khuôn của
    // giao dịch mục tiêu.
    for (final lyDo in ['', 'đếm lại ví', 'ATM báo khác']) {
      final ghiChu = ghiChuDieuChinh(lyDo);
      expect(laKhoanDieuChinh(loai: 'thu', categoryId: null, ghiChu: ghiChu),
          isTrue,
          reason: 'Lý do "$lyDo" làm hỏng vòng ghi–đọc.');
    }
  });
}
