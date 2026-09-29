/// `nhomTuKhoa` — tiền tố khoá → nhóm công tắc (B5b).
///
/// Phép canh "đủ mọi loại" nằm ở `notification_deeplink_test.dart`, cạnh
/// `tatCaUngVien()`, để khỏi chép đầu vào của bộ quét. Tệp này giữ ba ca biên:
/// khoá nhắc ghi chép, khoá lạ và khoá rỗng đều là `null` — không thuộc nhóm có
/// công tắc nào, nên B5b không bao giờ đề xuất tắt nhóm vì chúng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/nhom_tu_khoa.dart';
import 'package:flowmoney/core/notification/reminder_scheduler.dart';

void main() {
  test('khoá nhắc ghi chép → null: nó không thuộc NotificationKind nào', () {
    expect(nhomTuKhoa(ghiChepDedupeKey(DateTime(2026, 9, 29))), isNull,
        reason: 'nhắc ghi chép có công tắc riêng (nhacGhiChepBat), không phải '
            'công tắc nhóm — B5b đọc nó ở nhánh giờ ghi chép, không ở tắt nhóm');
  });

  test('khoá lạ hoặc rỗng → null', () {
    expect(nhomTuKhoa('khongBietLaGi:1'), isNull,
        reason: 'nhật ký có thể mang khoá của bản app cũ');
    expect(nhomTuKhoa(''), isNull);
  });

  test('chỉ so TIỀN TỐ đứng trước dấu ":" — không so chuỗi con', () {
    expect(nhomTuKhoa('billDueX:1'), isNull,
        reason: 'startsWith("billDue") sẽ nhận nhầm một tiền tố khác');
  });
}
