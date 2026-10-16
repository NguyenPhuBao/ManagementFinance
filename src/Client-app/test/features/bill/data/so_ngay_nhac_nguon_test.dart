/// Cổng đọc tuỳ chọn "Nhắc trước" cho nhãn "Sắp đến hạn" — `so_ngay_nhac_nguon.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/data/so_ngay_nhac_nguon.dart';
import 'package:flowmoney/features/bill/domain/bill_nhac_truoc.dart';

void main() {
  test('trả đúng số ngày kho tuỳ chọn đưa, theo đúng tài khoản', () async {
    int? hoi;
    final nguon = SoNgayNhacNguon((id) async {
      hoi = id;
      return 7;
    });

    expect(await nguon.doc(10), 7,
        reason: 'Số người dùng đặt trong Cài đặt thông báo phải tới được nhãn.');
    expect(hoi, 10, reason: 'Tuỳ chọn là của TÀI KHOẢN — đọc nhầm tài khoản là '
        'nhãn theo cài đặt của người khác.');
  });

  test('kho tuỳ chọn hỏng thì rơi về mốc mặc định, không làm hỏng trang', () async {
    final nguon = SoNgayNhacNguon((_) async => throw StateError('kho hỏng'));

    expect(await nguon.doc(10), mocNhacMacDinh,
        reason: 'Một nhãn trạng thái không đáng làm trang Hoá đơn đổ lỗi; mốc '
            '3 ngày là hành vi trước 2026-10-16.');
  });
}
