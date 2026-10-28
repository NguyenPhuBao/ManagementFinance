/// Công tắc *"Tính vào tổng tài sản"* khi không có quyền `wallet_exclude_total` (B1, I3 người dùng chốt 2026-10-28):
/// quyền chỉ chặn LOẠI MỚI. Ví đã lưu là "không tính" (loại từ khi còn Premium) thì người bị hạ cấp vẫn bật lại được —
/// bản đầu B1 khoá cả hai chiều nên ví ấy kẹt ngoài tổng tới khi mua lại Premium.
library;

import 'package:flowmoney/features/wallet/domain/cong_tac_tinh_vao_tong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('có quyền → đổi được, bất kể đã lưu gì', () {
    expect(doiDuocTinhVaoTong(coQuyen: true, daLuuTinhVaoTong: true), isTrue);
    expect(doiDuocTinhVaoTong(coQuyen: true, daLuuTinhVaoTong: false), isTrue);
  });

  test('⭐ không quyền, ví đã lưu là "tính" → KHOÁ (tắt là một lần loại mới)', () {
    expect(doiDuocTinhVaoTong(coQuyen: false, daLuuTinhVaoTong: true), isFalse);
  });

  test('⭐ không quyền, ví đã lưu là "không tính" → MỞ (bật lại; tắt lại trước khi Lưu chỉ là về giá trị cũ)', () {
    expect(doiDuocTinhVaoTong(coQuyen: false, daLuuTinhVaoTong: false), isTrue,
        reason: 'I3: khoá hai chiều làm ví người bị hạ cấp đã loại kẹt ngoài tổng — "hạ cấp giữ dữ liệu, chỉ chặn bật mới"');
  });
}
