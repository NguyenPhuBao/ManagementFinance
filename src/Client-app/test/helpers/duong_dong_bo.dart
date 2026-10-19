import 'dart:io';

/// Mọi tệp `.dart` (trừ `.g.dart`) dưới `lib/core/sync/` — "đường đồng bộ" mà các test quét cột cục bộ đọc
/// (`vi_trung_ten_cuc_bo_test`, `wallet_cho_phep_am_test`, quét 15 `ai_edge_cuc_bo_khong_dong_bo_test`).
///
/// Đọc cả thư mục chứ không liệt kê tay: từ khi tách `SyncEngine` (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`) mã đẩy / kéo nằm ở nhiều tệp, và một danh sách cứng để
/// cột cục bộ lọt vào tệp mới mà không ca nào đỏ. Đường dẫn dạng `lib/core/sync/<tệp>`, xếp tăng dần. Chạy từ
/// `src/Client-app`.
List<String> tepDuongDongBo() => Directory('lib/core/sync')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path.replaceAll('\\', '/'))
    .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
    .toList()
  ..sort();
