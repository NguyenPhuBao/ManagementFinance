/// Chữ THÔ Gemma 4 E2B trả khi nhìn ảnh hoá đơn (đo OnePlus + Realme 2026-10-08) → tổng + món.
library;

import 'package:flowmoney/features/transaction/domain/doc_anh_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rào ```json + số nguyên', () {
    const tho = '```json {   "mon": [     {       "ten": "Mon Nuoc V Iced Pure Matcha Tea Latte",       "tien": 116000     },'
        '     {       "ten": "Mon Nuoc No Sweet",       "tien": 0     }   ],   "tong": 262000 } ```';
    final kq = docJsonGemmaAnh(tho)!;
    expect(kq.tong, 262000);
    expect([for (final m in kq.mon) (m.ten, m.soTien)], [('Mon Nuoc V Iced Pure Matcha Tea Latte', 116000.0)],
        reason: 'dòng 0 đ (tuỳ chọn "ít ngọt") không phải món');
  });

  test('⭐ số dạng CHUỖI có ngăn nghìn ("75,700")', () {
    const tho = '```json {"mon": [{"ten": "Snack bã", "tien": "5,000"}], "tong": "75,700"} ```';
    final kq = docJsonGemmaAnh(tho)!;
    expect(kq.tong, 75700);
    expect(kq.mon.single.soTien, 5000);
  });

  test('⭐ số KHÔNG ngoặc mà có phẩy ("tien": 39,000 — JSON hỏng) vẫn đọc', () {
    const tho = '```json {"mon": [{"ten": "HỒNG TRÀ SỮA", "tien": 39,000}, {"ten": "-50% NGOT", "tien": 0}], '
        '"tong": 158000} ```';
    final kq = docJsonGemmaAnh(tho)!;
    expect(kq.tong, 158000);
    expect(kq.mon.single.ten, 'HỒNG TRÀ SỮA');
    expect(kq.mon.single.soTien, 39000);
  });

  test('tổng 0 / thiếu → null; món vẫn đọc', () {
    final kq = docJsonGemmaAnh('{"mon": [{"ten": "A", "tien": 10000}], "tong": 0}')!;
    expect(kq.tong, isNull);
    expect(kq.mon, hasLength(1));
  });

  test('không có khối JSON / JSON hỏng hẳn → null', () {
    expect(docJsonGemmaAnh('Xin lỗi, tôi không đọc được ảnh.'), isNull);
    expect(docJsonGemmaAnh('{"mon": [ }'), isNull);
  });

  test('tổng từ 13 chữ số trở lên (vượt cột numeric(15,2)) → null', () {
    expect(docJsonGemmaAnh('{"mon": [], "tong": 10000000000000}')!.tong, isNull);
  });

  test('prompt chỉ hỏi món + tổng — thêm trường là tổng tụt (đo OnePlus: 6/6 → 5/6)', () {
    expect(kPromptMonTong, contains('"mon"'));
    expect(kPromptMonTong, contains('"tong"'));
    for (final k in ['cua_hang', 'ngay', 'gio']) {
      expect(kPromptMonTong, isNot(contains(k)));
    }
  });
}
