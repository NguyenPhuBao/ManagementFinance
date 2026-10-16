/// Id tất định của khoản trích tự động (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 5): chạy nền làm
/// "hai máy cùng tới kỳ 08:00" thành ca thường, và cùng id là thứ giữ cho server chỉ có MỘT hàng.
library;

import 'package:flowmoney/features/goal/domain/id_khoan_trich.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ky = DateTime(2026, 10, 15, 8);

  test('cùng (mục tiêu, kỳ) → cùng id — hai máy cùng trích ra MỘT hàng', () {
    expect(idKhoanTrichTuDong('g1', ky), idKhoanTrichTuDong('g1', DateTime(2026, 10, 15, 8)));
  });

  test('khác kỳ / khác mục tiêu → khác id', () {
    expect(idKhoanTrichTuDong('g1', ky), isNot(idKhoanTrichTuDong('g1', DateTime(2026, 11, 15, 8))));
    expect(idKhoanTrichTuDong('g1', ky), isNot(idKhoanTrichTuDong('g2', ky)));
  });

  test('băm MỐC TUYỆT ĐỐI: cùng thời khắc biểu diễn UTC hay giờ máy ra cùng id', () {
    expect(idKhoanTrichTuDong('g1', ky), idKhoanTrichTuDong('g1', ky.toUtc()),
        reason: 'băm chuỗi giờ địa phương là hai máy khác múi giờ ra hai id');
  });

  test('UUID v5 hợp lệ, không trùng không gian với khoản mở sổ', () {
    final id = idKhoanTrichTuDong('g1', ky);
    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(id, isNot(idKhoanMoSo('g1')));
  });
}
