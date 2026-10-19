/// Công tắc "Trợ lý online" + cờ "đã đọc tờ thông tin" — khuôn `CongTacAi`: một khoá
/// cho cả máy, nuốt lỗi (spec trợ lý online 2026-10-11 §3.5).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/data/cong_tac_online.dart';

import '../../../helpers/kho_gia.dart';

void main() {
  test('mặc định: online BẬT, chưa đọc tờ', () async {
    final c = CongTacOnline(KhoGia());
    expect(await c.docBat(), isTrue, reason: 'người dùng chốt "có mạng thì dùng backend" là mặc định');
    expect(await c.daDocTo(), isFalse);
  });

  test('ghi rồi đọc lại; hai khoá độc lập', () async {
    final kho = KhoGia();
    final c = CongTacOnline(kho);
    await c.ghiBat(false);
    await c.ghiDaDocTo();
    expect(await c.docBat(), isFalse);
    expect(await c.daDocTo(), isTrue);
    expect(kho.ban, {'ai_online_bat': 'false', 'ai_online_da_doc_to': 'true'}, reason: 'tên khoá khớp từng chữ');
  });

  test('kho hỏng → mặc định, không ném', () async {
    final kho = KhoGia()..hong = true;
    final c = CongTacOnline(kho);
    expect(await c.docBat(), isTrue);
    expect(await c.daDocTo(), isFalse);
    await c.ghiBat(false); // không ném
    await c.ghiDaDocTo();
  });
}
