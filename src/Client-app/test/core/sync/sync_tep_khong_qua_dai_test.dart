/// Test quét `lib/` thứ **34** (spec `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md` mục 5.2): tệp dưới
/// `lib/core/sync/` không quá [tran] dòng.
///
/// `SyncEngine` từng là một tệp 2.153 dòng làm bảy việc — sửa một bảng ở nhánh kéo về phải đọc qua nhánh đẩy và phân loại
/// lỗi. Tệp dài hơn trần phải nằm trong [mienTru] kèm trần RIÊNG bằng số đo lúc ghi — **số chính test này báo**
/// (`readAsLinesSync`), không phải `wc -l`; trần chỉ được GIẢM; xuống dưới [tran] rồi mà quên rút thì đỏ (khuôn quét 23
/// `tep_presentation_khong_qua_dai_test.dart`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const tran = 800;

  /// Tệp (tương đối `lib/`) → trần riêng. Số là số dòng đo ngày điền; không được tăng.
  // Rỗng từ 2026-10-19 (tách SyncEngine xong): cơ chế giữ nguyên cho tệp dài sau này — đừng xoá vòng kiểm.
  const mienTru = <String, int>{};

  test('tệp dưới core/sync không quá $tran dòng, trừ danh sách có trần riêng', () {
    final goc = Directory('lib/core/sync');
    expect(goc.existsSync(), isTrue, reason: 'Chạy từ src/Client-app.');
    final loi = <String>[];
    final thay = <String, int>{};
    for (final f in goc.listSync(recursive: true).whereType<File>()) {
      final duong = f.path.replaceAll('\\', '/');
      if (!duong.endsWith('.dart') || duong.endsWith('.g.dart')) continue;
      final key = duong.replaceFirst(RegExp(r'^lib/'), '');
      final n = f.readAsLinesSync().length;
      thay[key] = n;
      final rieng = mienTru[key];
      if (n > tran && rieng == null) {
        loi.add('$key: $n dòng > $tran — tách theo trách nhiệm (spec tách SyncEngine), hoặc ghi vào mienTru với đúng số đo.');
      } else if (rieng != null && n > rieng) {
        loi.add('$key: $n dòng > trần riêng $rieng — trần chỉ được giảm.');
      }
    }
    expect(thay.keys, contains('core/sync/sync_engine.dart'),
        reason: 'Liệt kê thư mục hỏng thì quét xanh vì không đọc gì.');
    for (final e in mienTru.entries) {
      final n = thay[e.key];
      if (n == null) {
        loi.add('${e.key}: không còn tồn tại — sửa danh sách.');
      } else if (n <= tran) {
        loi.add('${e.key}: đã xuống $n ≤ $tran — rút khỏi mienTru.');
      }
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
