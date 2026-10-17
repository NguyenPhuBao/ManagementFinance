/// Câu trả lời ở bậc tool có lúc là markdown (`*   Giáo dục: …`) — OnePlus đo
/// được ở chặng 4b (2026-09-23), bẫy 4.36 — mà màn Trợ lý AI hiện chữ trần, nên
/// dấu `*` lộ ra giữa câu. Gỡ ở lúc HIỆN, sau khi câu đã qua kiểm.
library;

import 'package:flowmoney/features/ai_edge/domain/bo_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ gạch đầu dòng `*` ở đầu câu — đúng câu máy thật hiện ra', () {
    expect(boDanhDauMarkdown('*   Di chuyển: Còn 8 ngày, Còn lại 95.000 đ.'),
        'Di chuyển: Còn 8 ngày, Còn lại 95.000 đ.');
  });

  test('gạch đầu dòng sau xuống dòng giữa câu', () {
    expect(
      boDanhDauMarkdown(
          'Danh sách ngân sách sắp hết:\n*   Giáo dục: Còn lại 5.000 đ.'),
      'Danh sách ngân sách sắp hết:\nGiáo dục: Còn lại 5.000 đ.',
    );
  });

  test('`-` và `•` làm gạch đầu dòng cũng gỡ', () {
    expect(boDanhDauMarkdown('- Ví test: Số dư -100.000 đ.'),
        'Ví test: Số dư -100.000 đ.');
    expect(boDanhDauMarkdown('• Kiem: 45.000 đ.'), 'Kiem: 45.000 đ.');
  });

  test('⭐ số ÂM ở đầu câu KHÔNG bị gỡ dấu', () {
    expect(boDanhDauMarkdown('-100.000 đ là số dư ví test.'),
        '-100.000 đ là số dư ví test.',
        reason: 'Gỡ nhầm dấu trừ là đổi nghĩa con số — sai theo chiều nguy hiểm.');
  });

  test('chữ đậm `**…**` thành chữ thường', () {
    expect(boDanhDauMarkdown('**Giáo dục** còn lại 5.000 đ.'),
        'Giáo dục còn lại 5.000 đ.');
  });

  test('câu thường giữ nguyên', () {
    const c = 'Ví test đang âm với số dư là -100.000 đ.';
    expect(boDanhDauMarkdown(c), c);
  });

  // Nghiệm thu OnePlus 2026-10-18, đường online: Gemini dùng `###`, `>`, `---`.
  group('tiêu đề, trích dẫn, dòng kẻ ngang (đường online)', () {
    test('tiêu đề `#` ×1–6 đầu dòng bị gỡ', () {
      expect(boDanhDauMarkdown('### 2. Ba yếu tố'), '2. Ba yếu tố',
          reason: 'Gemini mở đầu mục bằng `###` — chữ trần không được lộ dấu.');
      expect(boDanhDauMarkdown('a\n## b'), 'a\nb',
          reason: 'Tiêu đề sau xuống dòng cũng gỡ.');
      expect(boDanhDauMarkdown('   # c'), 'c',
          reason: 'Khoảng trắng đứng trước `#` vẫn là tiêu đề.');
    });

    test('`#` không có khoảng trắng sau, hoặc giữa câu, giữ nguyên', () {
      expect(boDanhDauMarkdown('#1 ưu tiên'), '#1 ưu tiên',
          reason: 'Bẫy 4.36: dấu đứng sát chữ số không phải dấu markdown.');
      expect(boDanhDauMarkdown('mã #5 và #6'), 'mã #5 và #6',
          reason: '`#` giữa câu không phải tiêu đề.');
    });

    test('trích dẫn `>` bị gỡ, kể cả lồng và kèm gạch đầu dòng', () {
      expect(boDanhDauMarkdown('> - Năm 30: Tài sản tăng'),
          'Năm 30: Tài sản tăng',
          reason: 'Thứ tự áp dụng: `>` trước rồi mới gạch đầu dòng.');
      expect(boDanhDauMarkdown('> > a'), 'a', reason: 'Trích dẫn lồng.');
      expect(boDanhDauMarkdown('x > 5 triệu'), 'x > 5 triệu',
          reason: '`>` giữa câu là so sánh, không phải trích dẫn.');
    });

    test('dòng kẻ ngang bị bỏ cả dòng, không để dòng trống kép', () {
      expect(boDanhDauMarkdown('a\n---\nb'), 'a\nb');
      expect(boDanhDauMarkdown('a\n***\n'), 'a\n');
      expect(boDanhDauMarkdown('- - -\nb'), 'b',
          reason: 'Kẻ ngang xen khoảng trắng — không bị gạch đầu dòng ăn dở.');
      expect(boDanhDauMarkdown('--- abc'), '--- abc',
          reason: 'Dòng có chữ không phải kẻ ngang.');
      expect(boDanhDauMarkdown('-100.000 đ'), '-100.000 đ',
          reason: 'Số âm vẫn nguyên (bẫy 4.36).');
    });

    test('⭐ tổ hợp thật từ máy OnePlus', () {
      expect(
        boDanhDauMarkdown(
            '### 2. Ba yếu tố\n> - **Năm 30**: Tài sản\n---\n1. Thời gian'),
        '2. Ba yếu tố\nNăm 30: Tài sản\n1. Thời gian',
        reason: 'Đúng chuỗi Gemini trả trên máy thật 2026-10-18.',
      );
    });
  });
}
