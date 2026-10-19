/// Test quét `lib/` thứ **28** (spec `2026-10-15-g88-gach-4-va-quet-28-design.md` mục 4): `features/*/domain/` không import
/// tầng trên của mảng.
///
/// Domain là tầng dưới cùng (mục 4 `docs/KIEN_TRUC_CLIENT_APP.md`): luật thuần, không biết giao diện, không biết dữ liệu đến
/// từ đâu. Hai luật, đọc trên chỉ thị `import` / `export` / `part` (kể cả vế `if (dart.library.x)` và chỉ thị nhiều dòng) qua
/// `test/helpers/chi_thi_dart.dart` (từ 2026-10-16), xét trên đích đã chuẩn hoá `dichTrongLib` (`package:flowmoney/…` lẫn
/// đường tương đối; dòng chú thích `// import …` không phải chỉ thị):
///
/// 1. Không import đường chứa `/presentation/` — mượn một hàm thuần từ tệp widget là kéo Flutter và cả cây widget vào domain
///    (`ai_edge/domain` từng mượn `pickHomeBudget` từ `home_budget_card.dart`).
/// 2. Đường chứa `/data/` thì phải chứa `/data/models/` — kiểu dữ liệu (Entity, `BudgetView`, `ThongKeKy`) là hợp lệ;
///    repository / datasource / nguồn thì không (`ThongKeKy` từng khai TRONG tệp interface repository).
///
/// Chiều `domain → application/` là quét 25 luật 7; `domain → core/database` / Drift là quét 27 luật 2 — không lặp ở đây.
/// Tệp còn vi phạm nằm trong [conCho] (chỉ-được-giảm); sạch mà quên rút thì đỏ (khuôn quét 22 / 25 / 27).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chi_thi_dart.dart';

/// Tệp domain còn vi phạm (đường tương đối `src/Client-app`). RỖNG từ 2026-10-15 (đo gốc năm tệp, rút cùng ngày: hai tệp mượn
/// `pickHomeBudget` → `budget/domain`; ba tệp mượn kiểu Phân tích → `analytics/data/models`). Thêm vào đây là mở lại một nợ —
/// phải có lý do và ngày.
const conCho = <String>{};

String _duong(FileSystemEntity e) => e.path.replaceAll('\\', '/');

/// Mọi tệp `.dart` dưới `lib/features/*/domain/` (kể cả thư mục con).
List<File> _tepDomain() => [
      for (final f in Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>())
        if (_duong(f).endsWith('.dart') && _duong(f).contains('/domain/')) f,
    ];

void main() {
  test('tiền đề: phép quét thấy đủ tệp domain (chạy từ src/Client-app)', () {
    expect(_tepDomain().length, greaterThan(80),
        reason:
            'Phải thấy features/*/domain (đo 2026-10-15: 175 tệp) — đang quét sai thư mục.');
  });

  test(
      'luật 1–2: domain không import presentation/, trong data/ chỉ data/models/ — trừ conCho rút dần',
      () {
    final viPham = <String, String>{};
    void ghi(String duong, String viSao) =>
        viPham.update(duong, (cu) => '$cu; $viSao', ifAbsent: () => viSao);
    for (final f in _tepDomain()) {
      final d = _duong(f);
      for (final duong in duongChiThi(f.readAsStringSync())) {
        final dich = dichTrongLib(d, duong);
        if (dich == null) continue; // dart: / gói ngoài
        if (dich.contains('/presentation/')) {
          ghi(d,
              "luật 1: chỉ thị '$duong' — domain không biết giao diện; dời hàm thuần về domain/ của mảng sở hữu nó");
        }
        if (dich.contains('/data/') && !dich.contains('/data/models/')) {
          ghi(d,
              "luật 2: chỉ thị '$duong' — domain chỉ cầm kiểu ở data/models/; dời kiểu ra data/models/");
        }
      }
    }
    final loi = <String>[
      for (final e in viPham.entries)
        if (!conCho.contains(e.key)) '${e.key}: ${e.value}',
      for (final c in conCho)
        if (!viPham.containsKey(c)) '$c: đã sạch — rút khỏi conCho.',
    ];
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
