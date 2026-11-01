import 'package:flowmoney/features/household/domain/chu_nha_dung_dau.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chủ nhà lên đầu, còn lại giữ thứ tự; danh sách gốc không đổi', () {
    final goc = [(1, VaiNha.thanhVien), (2, VaiNha.chiXem), (3, VaiNha.chu), (4, VaiNha.thanhVien)];
    final ra = chuNhaDungDau(goc, (e) => e.$2);
    expect(ra.map((e) => e.$1), [3, 1, 2, 4]);
    expect(goc.map((e) => e.$1), [1, 2, 3, 4], reason: 'trả danh sách mới');
  });

  test('đã đúng thứ tự hoặc rỗng thì giữ nguyên', () {
    expect(chuNhaDungDau<VaiNha>([], (v) => v), isEmpty);
    expect(chuNhaDungDau([VaiNha.chu, VaiNha.chiXem], (v) => v), [VaiNha.chu, VaiNha.chiXem]);
  });
}
