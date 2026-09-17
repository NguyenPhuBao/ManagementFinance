/// Chỉ `SoDuViService` được ghi `wallets.balance` — test quét `lib/` thứ **sáu**.
///
/// ## Vì sao cần một test quét
///
/// Số dư ghi sai **không gây lỗi nào**. Một chỗ cộng dồn sót lại sẽ lặng lẽ làm
/// cache lệch khỏi sổ, và triệu chứng duy nhất là một con số sai trên màn hình
/// mà không ai lần được từ đâu. Trước bản này có **bảy** chỗ cộng dồn riêng
/// (`bill` 2, `goal` 4, `transaction` 1) — mỗi chỗ một cơ hội lệch.
///
/// Năm test quét `lib/` đã có (đếm bằng máy 2026-09-13): `currency_formatter_test`,
/// `wallet_picker_sources_test`, `khong_du_phong_admin_test`,
/// `sync_engine_start_owner_test`, `bill_conflict_resolver_wiring_test`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KHÔNG tệp nào ngoài SoDuViService được gọi updateBalance', () {
    // Ba tệp hợp lệ: nơi định nghĩa (DAO), nơi gọi duy nhất (service), và lớp
    // datasource chỉ chuyển tiếp xuống DAO.
    const duocPhep = [
      'core/database/daos/wallet_dao.dart',
      'features/wallet/data/services/so_du_vi_service.dart',
      'features/wallet/data/datasources/wallet_local_data_source.dart',
    ];

    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final p = f.path.replaceAll(r'\', '/');
      if (p.endsWith('.g.dart')) continue;
      if (duocPhep.any(p.endsWith)) continue;

      var i = 0;
      for (final ln in f.readAsLinesSync()) {
        i++;
        final s = ln.trim();
        if (s.startsWith('//') || s.startsWith('///')) continue;
        if (s.contains('updateBalance(')) viPham.add('$p:$i | $s');
      }
    }

    expect(viPham, isEmpty,
        reason: 'Số dư ví có ĐÚNG MỘT nơi ghi: `SoDuViService`. Mỗi chỗ cộng '
            'dồn riêng là một đường cho cache lệch khỏi sổ — im lặng, không lỗi '
            'nào báo ra.\nVi phạm:\n${viPham.join('\n')}');
  });
}
