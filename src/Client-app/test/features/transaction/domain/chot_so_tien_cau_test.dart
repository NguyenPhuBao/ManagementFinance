/// C4 §3.4 — chốt số tiền câu nói khi có hai nguồn (luật, Gemma). Không dùng `chotTongQuet`: luật `vanBan` và "lệch một
/// chữ số" của nó là của OCR; ở đây cả hai số đã là cách đọc có trong câu (`cachDocSoTien`).
///
/// Từ 2026-10-22 (người dùng chốt): chỉ số AI nằm trong [khac] — cách đọc NGOÀI cụm luật đã đọc
/// (`KetQuaDocCau.soTienKhac`) — mới là lệch. Gemma đọc lại chính cụm luật theo cách khác (bỏ chữ số lẻ: *"một triệu
/// hai"* → 1.000.000) thì không: luật chỉ chọn dạng nói khi chữ số lẻ đứng ở chỗ của tiền.
library;

import 'package:flowmoney/features/transaction/domain/chot_so_tien_cau.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI không có số → giữ số luật', () {
    final c = chotSoTienCau(luat: 50000, ai: null, khac: {20000.0});
    expect(c.soTien, 50000.0);
    expect(c.luaChon, isEmpty);
  });
  test('khớp (trong nửa đồng) → giữ số luật', () {
    expect(chotSoTienCau(luat: 50000, ai: 50000.4, khac: {20000.0}).soTien, 50000.0);
  });
  test('AI chọn một số tiền KHÁC trong câu → ô trống, hai chip: số AI trước, số luật sau', () {
    final c = chotSoTienCau(luat: 50000, ai: 20000, khac: {20000.0});
    expect(c.soTien, isNull);
    expect(c.luaChon, [20000.0, 50000.0]);
  });
  test('⭐ AI đọc lại chính cụm luật theo cách khác ("một triệu hai" → 1.000.000) → giữ số luật, không chip', () {
    final c = chotSoTienCau(luat: 1200000, ai: 1000000, khac: <double>{});
    expect(
      c.soTien,
      1200000.0,
      reason: 'đo Realme 2026-10-21: Gemma đọc "một triệu hai" thành 1.000.000 2/2 lần — chip ấy là chip oan',
    );
    expect(c.luaChon, isEmpty);
  });
}
