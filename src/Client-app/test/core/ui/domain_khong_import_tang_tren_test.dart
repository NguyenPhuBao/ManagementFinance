/// Test quét `lib/` thứ **28** (spec `2026-10-15-g88-gach-4-va-quet-28-design.md` mục 4): `features/*/domain/` không import
/// tầng trên của mảng.
///
/// Domain là tầng dưới cùng (mục 4 `docs/KIEN_TRUC_CLIENT_APP.md`): luật thuần, không biết giao diện, không biết dữ liệu đến
/// từ đâu. Hai luật, đọc trên dòng `import` / `export` (nháy đơn / kép, `package:flowmoney/…` lẫn đường tương đối, BOM — khuôn
/// quét 25 luật 5 / 7; regex neo đầu dòng nên dòng chú thích `// import …` không khớp):
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

/// Tệp domain còn vi phạm (đường tương đối `src/Client-app`). Đo gốc 2026-10-15: năm tệp — rút ở Task 2 (hai tệp mượn
/// `pickHomeBudget`) và Task 3 (ba tệp mượn kiểu của repository Phân tích).
const conCho = <String>{
  'lib/features/ai_edge/domain/goi_so_trang_chu.dart',
  'lib/features/ai_edge/domain/goi_so_ngan_sach.dart',
  'lib/features/ai_edge/domain/goi_so_phan_tich.dart',
  'lib/features/ai_edge/domain/hang_tong_quan.dart',
  'lib/features/transaction/domain/tim_giao_dich.dart',
};

/// `import` / `export` + đường trong nháy; dòng đầu có thể mang BOM (U+FEFF — `readAsLinesSync` giữ nó). Dựng BOM bằng mã
/// ký tự, không gõ ký tự thật vào mã nguồn.
final dongImport = RegExp(
    '^${String.fromCharCode(0xFEFF)}?(?:import|export)\\s*[\'"]([^\'"]+)[\'"]');

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
      for (final l in f.readAsLinesSync()) {
        final m = dongImport.firstMatch(l);
        if (m == null) continue;
        final dich = m.group(1)!;
        if (dich.contains('/presentation/')) {
          ghi(d,
              "luật 1: import '$dich' — domain không biết giao diện; dời hàm thuần về domain/ của mảng sở hữu nó");
        }
        if (dich.contains('/data/') && !dich.contains('/data/models/')) {
          ghi(d,
              "luật 2: import '$dich' — domain chỉ cầm kiểu ở data/models/; dời kiểu ra data/models/");
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
