/// G63 — cờ `bi_tu_choi_trung_ten` là cột CỤC BỘ: không được lọt vào đường đồng bộ (spec mục 8, bẫy 7).
///
/// PostgreSQL không có cột tương ứng; một khoá lọt vào payload đẩy là ví kẹt hàng đợi vĩnh viễn, im lặng — đúng thứ
/// G63 sinh ra để chữa. `sync_engine.dart` hỏi "ví nào bị giữ" qua cổng `CongViBiGiu` (bản thật `ViBiGiuDongBo` → `ViTrungTenNguon`), nên nó và cổng không cần biết tên cột.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/duong_dong_bo.dart';

void main() {
  final duongDongBo = tepDuongDongBo();

  test('phép quét thấy đường đồng bộ (có engine, bộ chuẩn hoá, cổng ví bị giữ)', () {
    expect(
      duongDongBo,
      containsAll([
        'lib/core/sync/sync_engine.dart',
        'lib/core/sync/sync_payload_normalizer.dart',
        'lib/core/sync/cong_vi_bi_giu.dart',
      ]),
      reason: 'Liệt kê thư mục hỏng (chạy sai thư mục, dấu \\ của Windows) thì các ca dưới xanh vì không đọc gì.',
    );
  });

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
