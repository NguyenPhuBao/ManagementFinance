/// B8 ◐ (2026-10-07): tên khoản trong câu trả lời Trợ lý AI là ghi chú, mà khoản ghi
/// từ tin ngân hàng mang NGUYÊN VĂN tin — mã giao dịch, số tài khoản — nên mẫu câu
/// "3 khoản thu mới nhất" dài cả trăm ký tự. Các ghi chú dưới đây chép từ CSDL Realme
/// (tài khoản 10).
library;

import 'package:flowmoney/features/ai_edge/domain/ten_ngan_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ tin MoMo chuyển tiền: bỏ mã, cắt ở ranh giới từ HOẶC dấu "-" ≤ 40 ký tự', () {
    // Realme 2026-10-07: cắt chỉ ở khoảng trắng ra "…chuyen tien qua" — mẫu câu nối
    // thành "qua khoản thu". Đoạn ngăn bằng "-" của tin là một ý trọn.
    final t = tenNganGiaoDich(
        '149337921395-TRAN QUANG DAT chuyen tien qua MoMo-CHUYEN TIEN-OQCH000LKViu-MOMO149337921395MOMO');
    expect(t, 'TRAN QUANG DAT chuyen tien qua MoMo');
    expect(t.length, lessThanOrEqualTo(kDaiToiDaTenNgan));
  });

  test('⭐ tin MoMo rút tiền: chỉ còn chữ có nghĩa', () {
    expect(tenNganGiaoDich('MOMO-CASHOUT-0373155262-OQCONTBBHMXJ-149311742276'), 'MOMO-CASHOUT');
  });

  test('ghi chú người dùng tự gõ giữ nguyên', () {
    for (final c in ['ca phe sang', 'grab ve que', 'Tiền nhà T9', 'Mua 3 ly trà sữa',
        'Thanh toán hóa đơn: Netflix', 'Tích lũy mục tiêu: MuaXe']) {
      expect(tenNganGiaoDich(c), c, reason: c);
    }
  });

  test('ngày trong ghi chú không phải mã (cụm số ngắn); quá dài thì cắt ở ranh giới từ', () {
    expect(tenNganGiaoDich('Hoa don 2026-09-04'), 'Hoa don 2026-09-04');
    expect(tenNganGiaoDich('Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04'),
        'Thanh toán hóa đơn: Kiem thu hoa don');
  });

  test('toàn mã thì giữ nguyên — tên rỗng còn tệ hơn tên dài', () {
    expect(tenNganGiaoDich('149337921395-OQCH000LKViu'), '149337921395-OQCH000LKViu');
  });

  test('một từ liền dài hơn trần (không có chỗ ngắt) thì cắt cứng', () {
    final t = tenNganGiaoDich('a' * 60);
    expect(t.length, kDaiToiDaTenNgan);
  });
}
