/// Cú chạm thông báo hệ điều hành dạng THÔ (B5a) và mã sự kiện nhật ký của nó.
library;

import 'package:flowmoney/core/notification/cham_hdh.dart';
import 'package:flowmoney/core/notification/notification_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suKienTuCham: ba mã, actionId lạ → cham_hdh', () {
    expect(suKienTuCham(const ChamHdh('billDue:b1:2026-10-01:1')), 'cham_hdh');
    expect(suKienTuCham(const ChamHdh('billDue:b1:2026-10-01:1', hanhDongTraNgay)), 'nut_tra_ngay');
    expect(suKienTuCham(const ChamHdh('billDue:b1:2026-10-01:1', hanhDongHoan)), 'hoan');
    expect(suKienTuCham(const ChamHdh('billDue:b1:2026-10-01:1', 'ma_cu_khong_ai_biet')), 'cham_hdh',
        reason: 'lịch do bản app cũ đặt có thể mang mã lạ — vẫn là một cú chạm');
  });

  test('ChamHdh so bằng giá trị (router khử trùng bằng ==)', () {
    expect(const ChamHdh('k', 'a'), const ChamHdh('k', 'a'));
    expect(const ChamHdh('k'), isNot(const ChamHdh('k', 'a')));
  });
}
