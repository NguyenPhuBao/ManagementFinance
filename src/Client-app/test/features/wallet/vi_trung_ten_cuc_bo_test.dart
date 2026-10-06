/// G63 — cờ `bi_tu_choi_trung_ten` là cột CỤC BỘ: không được lọt vào đường đồng bộ (spec mục 8, bẫy 7).
///
/// PostgreSQL không có cột tương ứng; một khoá lọt vào payload đẩy là ví kẹt hàng đợi vĩnh viễn, im lặng — đúng thứ
/// G63 sinh ra để chữa. `sync_engine.dart` hỏi "ví nào bị giữ" qua `ViTrungTenNguon`, nên nó không cần biết tên cột.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const duongDongBo = [
    'lib/core/sync/sync_engine.dart',
    'lib/core/sync/sync_payload_normalizer.dart',
  ];

  for (final f in duongDongBo) {
    test('$f không nhắc tới cờ', () {
      final noiDung = File(f).readAsStringSync();
      expect(noiDung.contains('biTuChoiTrungTen'), isFalse,
          reason: '$f nhắc tới `biTuChoiTrungTen` — cột cục bộ, PostgreSQL không có.');
      expect(noiDung.contains('bi_tu_choi_trung_ten'), isFalse,
          reason: '$f nhắc tới khoá `bi_tu_choi_trung_ten`.');
    });
  }

  test('hợp đồng payload ví vẫn KHÔNG có cờ', () {
    final hopDong = File('test/core/sync/sync_payload_contract_test.dart').readAsStringSync();
    expect(hopDong.contains('bi_tu_choi_trung_ten'), isFalse,
        reason: 'Tên trường sai thì IM LẶNG (quy tắc 4) — đừng mở cửa ấy cho một cột server không có.');
  });
}
