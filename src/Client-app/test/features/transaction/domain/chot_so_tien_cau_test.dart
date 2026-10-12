/// C4 §3.4 — chốt số tiền câu nói khi có hai nguồn (luật, Gemma). Không dùng `chotTongQuet`: luật `vanBan` và "lệch một
/// chữ số" của nó là của OCR; ở đây cả hai số đã là cách đọc có trong câu (`cachDocSoTien`).
library;

import 'package:flowmoney/features/transaction/domain/chot_so_tien_cau.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI không có số → giữ số luật', () {
    final c = chotSoTienCau(luat: 1200000, ai: null);
    expect(c.soTien, 1200000.0);
    expect(c.luaChon, isEmpty);
  });
  test('khớp (trong nửa đồng) → giữ số luật', () {
    expect(chotSoTienCau(luat: 1200000, ai: 1200000.4).soTien, 1200000.0);
  });
  test('lệch → ô trống, hai chip: số AI trước, số luật sau', () {
    final c = chotSoTienCau(luat: 1200000, ai: 1000000);
    expect(c.soTien, isNull);
    expect(c.luaChon, [1000000.0, 1200000.0]);
  });
}
