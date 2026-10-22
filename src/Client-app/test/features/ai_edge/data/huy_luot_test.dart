/// `HuyLuot` — thẻ huỷ của MỘT lượt mô hình (bẫy 4.60, 2026-10-22): lớp bọc hết giờ dừng đúng lượt của nó, không qua
/// `huy()` toàn cục (tăng bộ đếm chung của `BoNapMoHinh`, dừng `_chatDangSinh` — có thể bỏ oan lượt khác).
library;

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/ai_edge/data/huy_luot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thẻ mới chưa huỷ, tín hiệu chưa phát', () {
    fakeAsync((fa) {
      final h = HuyLuot();
      var phat = false;
      h.tin.then((_) => phat = true);
      fa.flushMicrotasks();
      expect((h.daHuy, phat), (false, false));
    });
  });

  test('⭐ huy() → daHuy và tín hiệu phát — kể cả người nghe đăng ký SAU lúc huỷ', () {
    fakeAsync((fa) {
      final h = HuyLuot();
      var truoc = false, sau = false;
      h.tin.then((_) => truoc = true);
      h.huy();
      h.tin.then((_) => sau = true);
      fa.flushMicrotasks();
      expect(h.daHuy, isTrue);
      expect((truoc, sau), (true, true), reason: 'runtime đăng ký dừng chat sau khi tạo chat — huỷ trước đó vẫn phải tới');
    });
  });

  test('huy() hai lần không ném', () {
    final h = HuyLuot()..huy();
    expect(h.huy, returnsNormally);
    expect(h.daHuy, isTrue);
  });

  test('hai thẻ độc lập — huỷ thẻ này không đụng thẻ kia', () {
    final a = HuyLuot(), b = HuyLuot();
    a.huy();
    expect((a.daHuy, b.daHuy), (true, false));
  });
}
