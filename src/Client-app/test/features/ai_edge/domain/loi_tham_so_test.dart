/// Lời từ chối tham số của ba tool bước 2 (spec mục 3.9): mô hình đọc được vì
/// sao, và có danh sách đúng để gọi lại (tốn một suất trong trần 3).
library;

import 'package:flowmoney/features/ai_edge/domain/loi_tham_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giá trị enum lạ: nêu giá trị nhận được và mọi giá trị đúng', () {
    expect(loiGiaTri('chieu', 'chi', ['khoan_chi', 'khoan_thu']),
        'chieu "chi" không hợp lệ. Chỉ nhận: khoan_chi, khoan_thu.');
  });

  test('tên không khớp: liệt kê tên thật, và tên vào tenLienQuan', () {
    final kq = loiKhongKhop('vi', 'vi gia', ['Tiền mặt', 'test1']);
    expect(kq.loi, 'vi "vi gia" không khớp tên nào. Chỉ có: Tiền mặt, test1.');
    expect(kq.tenLienQuan, ['Tiền mặt', 'test1']);
    expect(kq.hang, isEmpty);
  });

  test('tên khớp nhiều: liệt kê các tên đã khớp', () {
    final kq = loiKhopNhieu('danh_muc', 'da', ['Dá', 'Đá']);
    expect(kq.loi, 'danh_muc "da" khớp nhiều tên: Dá, Đá. Gọi lại với đúng một tên.');
    expect(kq.tenLienQuan, ['Dá', 'Đá']);
  });
}
