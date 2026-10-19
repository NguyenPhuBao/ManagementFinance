/// Ca canh cho `test/helpers/chi_thi_dart.dart` — bộ đọc chỉ thị Dart dùng chung của test quét 25 / 27 / 28.
///
/// Mỗi ca khoá một thứ mà phép đọc từng dòng bằng regex neo đầu dòng cũ đã mù (hoặc đã đúng và không được thoái lui).
library;

import 'package:flutter_test/flutter_test.dart';

import 'chi_thi_dart.dart';

void main() {
  group('duongChiThi', () {
    test('import thường và export', () {
      expect(duongChiThi("import 'dart:io';\nexport '../x.dart';\n"), ['dart:io', '../x.dart'],
          reason: 'Hai từ khoá cũ phải còn thấy.');
    });

    test('part có mặt, part of vắng', () {
      expect(duongChiThi("part 'app_database.g.dart';\n"), ['app_database.g.dart'],
          reason: '`part` kéo tệp khác vào CÙNG thư viện — là một phụ thuộc, quét cũ mù.');
      expect(duongChiThi("part of 'a.dart';\n"), isEmpty,
          reason: '`part of` trỏ NGƯỢC về thư viện cha, không phải phụ thuộc mới.');
    });

    test('import có điều kiện ba dòng như connection.dart trả cả bốn đường', () {
      const nguon = "import 'connection_native.dart'\n"
          "    if (dart.library.js_interop) 'connection_web.dart'\n"
          "    if (dart.library.html) 'connection_web.dart'\n"
          "    if (dart.library.io) 'connection_native.dart';\n";
      expect(duongChiThi(nguon),
          ['connection_native.dart', 'connection_web.dart', 'connection_web.dart', 'connection_native.dart'],
          reason: 'Vế `if (…)` xuống dòng là đường thật của build khác — quét cũ chỉ thấy đường chính.');
    });

    test('show xuống dòng như bill_page.dart', () {
      const nguon = "import '../../domain/bill_x.dart'\n    show A, B;\nimport 'dart:async';\n";
      expect(duongChiThi(nguon), ['../../domain/bill_x.dart', 'dart:async'],
          reason: '`show` / `hide` / `as` / `deferred as` sau đường không làm hụt chỉ thị kế tiếp.');
      expect(duongChiThi("import 'a.dart' deferred as a;\nimport 'b.dart' hide Z;\n"), ['a.dart', 'b.dart'],
          reason: '`deferred as` và `hide` sau đường cũng không được làm hụt chỉ thị.');
    });

    test('nháy kép', () {
      expect(duongChiThi('import "package:flowmoney/x.dart";\n'), ['package:flowmoney/x.dart'],
          reason: 'Nháy kép là Dart hợp lệ.');
    });

    test('BOM ở đầu tệp', () {
      final bom = String.fromCharCode(0xFEFF);
      expect(duongChiThi("${bom}import 'a.dart';\nimport 'b.dart';\n"), ['a.dart', 'b.dart'],
          reason: 'Tệp có BOM: dòng đầu mang U+FEFF trước từ khoá.');
    });

    test('dòng chú thích vắng', () {
      expect(duongChiThi("// import 'cam.dart';\n/// import 'cam.dart';\n  // export 'cam2.dart';\n"), isEmpty,
          reason: 'Từ khoá phải đứng đầu dòng (thụt lề được) — chú thích nhắc chỉ thị không phải chỉ thị.');
    });

    test('thụt lề bằng dấu cách hoặc tab vẫn thấy', () {
      expect(duongChiThi("  import 'a.dart';\n\texport 'b.dart';\n"), ['a.dart', 'b.dart'],
          reason: 'Thụt lề bằng dấu cách / tab không được làm hụt chỉ thị (regex cho phép khoảng trắng đầu dòng).');
    });

    test("import'a.dart'; không khoảng trắng", () {
      expect(duongChiThi("import'a.dart';\n"), ['a.dart'],
          reason: 'Dart hợp lệ; regex cũ `\\s*` bắt được — đừng thoái lui sang `\\s+`.');
    });

    test('mã thường không bị bắt nhầm', () {
      expect(duongChiThi("final importance = 'x';\npartition('y');\nexported('z');\n"), isEmpty,
          reason: 'Từ khoá phải là từ nguyên, ngay sau là dấu nháy.');
    });
  });

  group('dichTrongLib', () {
    test('đường tương đối có .. và .', () {
      expect(dichTrongLib('lib/features/bill/domain/a.dart', '../data/models/b.dart'),
          'lib/features/bill/data/models/b.dart',
          reason: '`..` phải lùi một thư mục — sai ở đây là luật vị trí so nhầm đích.');
      expect(dichTrongLib('lib/features/bill/domain/a.dart', './c.dart'), 'lib/features/bill/domain/c.dart',
          reason: '`.` phải bị bỏ, không để lại đoạn rỗng trong đường.');
    });

    test('package:flowmoney/ về lib/', () {
      expect(dichTrongLib('lib/core/x.dart', 'package:flowmoney/features/a/domain/b.dart'),
          'lib/features/a/domain/b.dart',
          reason: 'Đường `package:flowmoney/` phải về cùng dạng `lib/…` với đường tương đối để so được với nhau.');
    });

    test('dart: và gói ngoài là null', () {
      expect(dichTrongLib('lib/core/x.dart', 'dart:io'), isNull,
          reason: '`dart:` không thuộc lib/ — trả đường thì luật nhầm thành tệp trong dự án.');
      expect(dichTrongLib('lib/core/x.dart', 'package:drift/drift.dart'), isNull,
          reason: 'Gói ngoài không thuộc lib/ — người gọi tự xử lý.');
    });
  });
}
