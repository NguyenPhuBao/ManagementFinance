/// C4 — lời chép của Gemma → câu đưa vào ô Nhập nhanh. Prompt GIỮ NGUYÊN của spike (spec §3.5): đổi chữ là mất điểm đo
/// duy nhất đang có (spike 2026-10-01: số đúng, chữ sai "phở → vợ").
library;

import 'package:flowmoney/features/transaction/domain/chep_loi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt y nguyên spike', () {
    expect(kPromptChepLoi, 'Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về câu ấy, không giải thích.');
  });

  test('bỏ khoảng trắng, ngoặc kép bao ngoài, dấu chấm cuối', () {
    expect(lamSachLoiChep('  Hôm qua ăn phở 45.000 bằng tiền mặt.  '), 'Hôm qua ăn phở 45.000 bằng tiền mặt');
    expect(lamSachLoiChep('"Đổ xăng 50."'), 'Đổ xăng 50');
    expect(lamSachLoiChep('“Cà phê 25 nghìn”'), 'Cà phê 25 nghìn');
  });

  test('chấm trong số không bị cắt; rỗng ra rỗng', () {
    expect(lamSachLoiChep('Ăn phở 45.000'), 'Ăn phở 45.000');
    expect(lamSachLoiChep('   '), '');
  });
}
