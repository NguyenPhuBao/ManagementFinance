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
}
