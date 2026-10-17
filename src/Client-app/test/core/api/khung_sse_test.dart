// test/core/api/khung_sse_test.dart
/// Bộ tách khung SSE — hạ tầng HTTP thuần (`core/api`), không biết mảng nào.
/// Backend chatbot phát `event: meta|delta|done|error` + `data: {json}`; gói TCP
/// cắt KHÔNG theo khung, nên bộ tách phải giữ đệm qua nhiều chunk.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/api/khung_sse.dart';

void main() {
  test('một khung trọn trong một chunk', () {
    final b = BoTachSse();
    final k = b.nhan('event: delta\ndata: {"text":"Chào"}\n\n');
    expect(k, hasLength(1));
    expect(k.single.event, 'delta');
    expect(k.single.data, '{"text":"Chào"}');
  });

  test('hai khung trong một chunk', () {
    final k = BoTachSse().nhan('event: meta\ndata: {"a":1}\n\nevent: delta\ndata: {"text":"x"}\n\n');
    expect(k.map((e) => e.event), ['meta', 'delta']);
  });

  test('khung cắt giữa DÒNG và giữa `\\n\\n` qua ba chunk → vẫn đúng một khung', () {
    final b = BoTachSse();
    expect(b.nhan('event: del'), isEmpty, reason: 'chưa hết dòng → chưa phát');
    expect(b.nhan('ta\ndata: {"text":"Quỹ khẩn "}\n'), isEmpty, reason: 'hết dòng nhưng chưa dòng trống');
    final k = b.nhan('\n');
    expect(k, hasLength(1));
    expect(k.single.data, '{"text":"Quỹ khẩn "}');
  });

  test('CRLF coi như LF', () {
    final k = BoTachSse().nhan('event: done\r\ndata: {"responseTimeMs":720}\r\n\r\n');
    expect(k.single.event, 'done');
    expect(k.single.data, '{"responseTimeMs":720}');
  });

  test('dòng bắt đầu ":" là chú thích, bỏ; khung không event → "message"', () {
    final k = BoTachSse().nhan(': keep-alive\ndata: {"x":1}\n\n');
    expect(k.single.event, 'message');
    expect(k.single.data, '{"x":1}');
  });

  test('nhiều dòng data nối bằng \\n; khoảng trắng đầu giá trị sau dấu ":" bị bỏ', () {
    final k = BoTachSse().nhan('data: dòng 1\ndata:  dòng 2\n\n');
    expect(k.single.data, 'dòng 1\n dòng 2');
  });

  test('dong(): phần dư không có dòng trống kết vẫn phát', () {
    final b = BoTachSse();
    expect(b.nhan('event: done\ndata: {"fallback":true}'), isEmpty);
    final k = b.dong();
    expect(k.single.event, 'done');
    expect(k.single.data, '{"fallback":true}');
  });

  test('chunk rỗng / chỉ dòng trống → không phát gì, không ném', () {
    final b = BoTachSse();
    expect(b.nhan(''), isEmpty);
    expect(b.nhan('\n\n\n'), isEmpty);
    expect(b.dong(), isEmpty);
  });
}
