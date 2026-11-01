// Câu hộp xoá khoản góp / rút (Stitch 6dc96c4a 8B): bốn nhánh, tiền qua CurrencyFormatter.
import 'package:flowmoney/features/household/domain/cau_xoa_khoan_gop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('góp từ ví riêng: quỹ giảm, tiền trả về ví riêng', () {
    expect(cauXoaKhoanGop(gop: true, tenQuy: 'Tiền chợ', soTien: 2000000, tenViRieng: 'Ví MB'),
        'Quỹ Tiền chợ cũng giảm 2.000.000 đ, và số tiền được trả về Ví MB.');
  });

  test('rút về ví riêng: quỹ được cộng lại, khoản nhận bị huỷ', () {
    expect(cauXoaKhoanGop(gop: false, tenQuy: 'Du lịch', soTien: 500000, tenViRieng: 'Ví MB'),
        'Quỹ Du lịch được cộng lại 500.000 đ, và khoản nhận ở Ví MB bị huỷ.');
  });

  test('tiền mặt trao tay: chỉ quỹ giảm', () {
    expect(cauXoaKhoanGop(gop: true, tenQuy: 'Tiền chợ', soTien: 2000000),
        'Quỹ Tiền chợ cũng giảm 2.000.000 đ.');
  });

  test('Chủ xoá hộ: nêu tên người, tiền về ví riêng của họ', () {
    expect(cauXoaKhoanGop(gop: true, tenQuy: 'Tiền chợ', soTien: 2000000, tenNguoiKhac: 'Minh'),
        'Khoản góp của Minh bị xoá, quỹ Tiền chợ giảm 2.000.000 đ. Tiền được trả về ví riêng của Minh.',
        reason: 'tenNguoiKhac thắng tenViRieng (máy Chủ không có nửa riêng)');
    expect(cauXoaKhoanGop(gop: false, tenQuy: 'Tiền chợ', soTien: 500000, tenNguoiKhac: 'Bình'),
        'Khoản rút của Bình bị xoá, quỹ Tiền chợ được cộng lại 500.000 đ. Khoản nhận ở ví riêng của Bình bị huỷ.');
  });
}
