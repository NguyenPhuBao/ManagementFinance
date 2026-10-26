/// Test quét `lib/` thứ **39** — tệp đo bề rộng chữ lúc dựng (`doRongChu(`, `TextPainter(`) không dựng `LayoutBuilder(`
/// trần: chọn bố cục theo bề rộng chữ phải đi qua `BoCucTheoFont` (`core/ui/do_chu.dart`), 2026-10-26.
///
/// Vì sao: font Inter tải bằng `google_fonts` (không đóng gói sẵn) nạp **sau** khung đầu. `Text` tự đo lại khi font nạp xong,
/// còn phép đo trong `builder` của `LayoutBuilder` thì không — ràng buộc không đổi nên `builder` không chạy lại, bố cục giữ
/// lựa chọn theo font dự phòng. Máy ảo 320 dp × cỡ chữ 1,6: màn Đăng nhập mở lạnh vẽ nút *"Googl"* cụt chữ (`NhanCoDeu`).
/// Bộ test nạp font TRƯỚC khi dựng nên mọi ca bố cục khác đều mù với lỗi này.
///
/// Quét: dòng MÃ (bỏ phần sau `//`) của mỗi tệp dưới `lib/`; tệp có `doRongChu(` hoặc `TextPainter(` mà có `LayoutBuilder(`
/// là đỏ. Miễn trừ: chính `core/ui/do_chu.dart` (định nghĩa `BoCucTheoFont` bằng `LayoutBuilder`).
///
/// Giới hạn đã biết: phép đo ở tệp khác với `LayoutBuilder` (hàm đo truyền qua tham số) không thấy; `LayoutBuilder` không
/// dính phép đo trong cùng tệp cũng bị bắt — khi ấy dùng `BoCucTheoFont` (vô hại) hoặc tách tệp.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _doChu = RegExp(r'\b(doRongChu|TextPainter)\s*\(');
final _layoutBuilder = RegExp(r'\bLayoutBuilder\s*\(');

/// Bỏ phần chú thích `//` của từng dòng (đủ cho mã của dự án: không chuỗi nào trong các tệp đo chữ chứa `//`).
String _ma(String dong) {
  final i = dong.indexOf('//');
  return i < 0 ? dong : dong.substring(0, i);
}

void main() {
  test('tệp đo bề rộng chữ lúc dựng không dùng LayoutBuilder trần (đi qua BoCucTheoFont)', () {
    final vi = <String>[];
    var soTepDo = 0;
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final duong = f.path.replaceAll('\\', '/');
      if (!duong.endsWith('.dart') || duong.endsWith('lib/core/ui/do_chu.dart')) continue;
      final dong = f.readAsLinesSync().map(_ma).toList();
      if (!dong.any(_doChu.hasMatch)) continue;
      soTepDo++;
      for (var i = 0; i < dong.length; i++) {
        if (_layoutBuilder.hasMatch(dong[i])) vi.add('$duong:${i + 1}');
      }
    }
    // Tiền đề: 11 tệp đo chữ lúc dựng (đếm 2026-10-26) — chạy sai thư mục thì không thấy tệp nào và ca dưới xanh giả.
    expect(soTepDo, greaterThanOrEqualTo(10), reason: 'phép quét phải thấy các tệp đo chữ — chạy từ src/Client-app');
    expect(vi, isEmpty,
        reason: 'đo chữ trong LayoutBuilder trần thì bố cục giữ lựa chọn theo font dự phòng khi Inter nạp muộn '
            '(nút "Googl" cụt, máy ảo 2026-10-26) — đổi sang BoCucTheoFont:\n${vi.join('\n')}');
  });

  test('phép quét nhận ra khuôn vi phạm và bỏ qua chú thích', () {
    final mau = ['final w = doRongChu(context, chu, kieu);', 'return LayoutBuilder(builder: (c, r) {'].map(_ma);
    expect(mau.any(_doChu.hasMatch) && mau.any(_layoutBuilder.hasMatch), isTrue);
    expect(_layoutBuilder.hasMatch(_ma('    // `LayoutBuilder(` trong chú thích')), isFalse);
  });
}
