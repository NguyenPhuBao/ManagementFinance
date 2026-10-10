/// Test quét `lib/` thứ **23** (spec bịt điểm rò 2026-10-10, mục 5.4): tệp giao diện không quá [tran] dòng.
///
/// Trang dài không lỗi gì lúc chạy — chỉ là mỗi lần sửa phải đọc hàng nghìn dòng để biết một khối nằm đâu, và một khối
/// lẽ ra là widget riêng lại dính vào trạng thái của cả trang. Tệp dài hơn trần phải nằm trong [mienTru] kèm trần RIÊNG
/// bằng số đo lúc ghi; trần chỉ được GIẢM; tách xuống dưới [tran] rồi mà quên rút thì test đỏ (khuôn `khong_co_nut_chet_test`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const tran = 1200;

  /// Tệp (tương đối `lib/`) → trần riêng. Số là số dòng đo ngày điền; không được tăng.
  const mienTru = <String, int>{
    'features/transaction/presentation/pages/add_transaction_page.dart': 3107,
    'features/notification/presentation/pages/notification_settings_page.dart': 1615,
    'features/goal/presentation/pages/goal_add_page.dart': 1570,
    'features/goal/presentation/pages/goal_detail_page.dart': 1480,
    'features/analytics/presentation/pages/report_preview_page.dart': 1270,
  };

  test('tệp dưới features/*/presentation không quá $tran dòng, trừ danh sách có trần riêng', () {
    final goc = Directory('lib/features');
    expect(goc.existsSync(), isTrue, reason: 'Chạy từ src/Client-app.');
    final loi = <String>[];
    final thay = <String, int>{};
    for (final f in goc.listSync(recursive: true).whereType<File>()) {
      final duong = f.path.replaceAll('\\', '/');
      if (!duong.endsWith('.dart') || !duong.contains('/presentation/')) continue;
      final key = duong.replaceFirst(RegExp(r'^lib/'), '');
      final n = f.readAsLinesSync().length;
      thay[key] = n;
      final rieng = mienTru[key];
      if (n > tran && rieng == null) {
        loi.add('$key: $n dòng > $tran — tách widget theo khối (spec mục 5), hoặc ghi vào mienTru với đúng số đo.');
      } else if (rieng != null && n > rieng) {
        loi.add('$key: $n dòng > trần riêng $rieng — trần chỉ được giảm.');
      }
    }
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
