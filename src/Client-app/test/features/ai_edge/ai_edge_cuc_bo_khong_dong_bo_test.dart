/// Test quét thứ MƯỜI LĂM: hai thứ của schema v24 — cột `categories.ai_co_dinh`
/// và bảng `ai_rebalancing_feedbacks` — KHÔNG được lọt vào đường đồng bộ.
///
/// ## Canh chừng điều gì
///
/// Cờ Cố định là **cục bộ** (cùng khuôn `wallets.allow_negative`): server không
/// có cột tương ứng, nên một khoá `ai_co_dinh` lọt vào payload là hoặc bị
/// `mapEntityFields` bỏ qua im lặng (quy tắc 4 `CLAUDE.md`), hoặc — nếu backend
/// có ngày thêm cột — thành một trường đồng bộ **không ai thiết kế**. Bảng phản
/// hồi thì cùng lý lẽ với `AppNotifications` (quy tắc 9): dữ liệu suy ra trên
/// từng máy, đưa vào `SyncEntityType` là chạm bảy bảng ánh xạ phía backend mà
/// không được gì.
///
/// ## Vì sao KHÔNG bỏ dòng chú thích (khác test quét 14)
///
/// Một chú thích nhắc tên cột trong `sync_engine.dart` là dấu hiệu ai đó đang
/// định đưa nó vào. Ở đây mọi lần nhắc đều đáng để dừng lại đọc.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const cam = [
    'aiCoDinh',
    'ai_co_dinh',
    'AiRebalancingFeedback',
    'ai_rebalancing_feedbacks',
    'aiRebalancingFeedbacks',
  ];

  const duongDongBo = [
    'lib/core/sync/sync_engine.dart',
    'lib/core/sync/sync_payload_normalizer.dart',
    'lib/core/sync/sync_models.dart',
  ];

  test('ba tệp của đường đồng bộ không nhắc tới hai thứ cục bộ v24', () {
    final loi = <String>[];
    for (final p in duongDongBo) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p phải tồn tại');
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        for (final c in cam) {
          if (dongs[i].contains(c)) loi.add('$p:${i + 1}: $c');
        }
      }
    }
    expect(loi, isEmpty,
        reason: 'Cột/bảng cục bộ v24 lọt vào đường đồng bộ:\n${loi.join('\n')}');
  });

  test('hợp đồng payload không có khoá ai_co_dinh', () {
    final f = File('test/core/sync/sync_payload_contract_test.dart');
    expect(f.existsSync(), isTrue);
    final s = f.readAsStringSync();
    for (final c in cam) {
      expect(s.contains(c), isFalse, reason: 'hợp đồng payload nhắc tới $c');
    }
  });
}
