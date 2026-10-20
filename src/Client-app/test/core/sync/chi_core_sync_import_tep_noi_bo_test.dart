/// Test quét `lib/` thứ **35** (2026-10-20, gợi ý của review toàn nhánh tách SyncEngine): ngoài `lib/core/sync/`, mã chỉ được
/// chạm `core/sync` qua [cuaCongKhai].
///
/// Đợt tách 2026-10-19 chẻ `sync_engine.dart` thành bốn lớp cộng tác + bốn tệp hàm thuần; lớp / hàm top-level của Dart không có
/// phạm vi thư mục, nên `ApDuLieuKeoVe`, `ThuGomThaoTacDay`, `GuiLoDongBo`, `resolveCategoryId`, `mocTuMaxSince`… nay công khai
/// cho cả package. Gọi chúng từ ngoài là đi vòng mọi cam kết thứ tự của `SyncEngine._runSync` (đẩy trước kéo, phát kết quả đẩy
/// TRƯỚC Pull, gieo sau mỗi lượt kéo — quy tắc 8) mà không qua cờ `syncing`. Tệp MỚI thêm vào `core/sync` mặc định là nội bộ.
///
/// Đọc chỉ thị `import` / `export` / `part` (kể cả vế `if (dart.library.x)` và chỉ thị nhiều dòng) qua
/// `test/helpers/chi_thi_dart.dart`, xét trên đích đã chuẩn hoá `dichTrongLib`. Chỉ áp lên `lib/` — test của hàm thuần được đọc
/// tệp nội bộ.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chi_thi_dart.dart';

/// Tệp của `core/sync` mà mã ngoài thư mục được dùng (tên tệp trong `lib/core/sync/`). Đo 2026-10-20: đúng sáu tệp này có
/// chỉ thị từ ngoài (19 chỉ thị). Thêm vào đây là mở cửa công khai mới — phải có lý do và ngày.
const cuaCongKhai = <String, String>{
  'sync_engine.dart': 'vòng đời đồng bộ — `start` / `stop` / `scheduleSync` / ba stream (11 chỗ dùng)',
  'sync_models.dart':
      'kiểu kết quả / trạng thái đồng bộ (`SyncResult`, `SyncStatus`) — người nghe pushResultStream, toast',
  'sync_payload_normalizer.dart':
      'ánh xạ giá trị server ↔ cục bộ (`categoryClassifyFromBackend`) — `category/domain/ban_sao_mac_dinh.dart`',
  'sync_checkpoint_store.dart': 'kho mốc kéo về — DI dựng bản thật',
  'cong_so_du_vi.dart': 'cổng số dư ví (G88 gạch 4) — mảng ví thi hành',
  'cong_vi_bi_giu.dart': 'cổng ví bị giữ (G63) — mảng ví thi hành',
};

/// Tệp ngoài `core/sync` còn vi phạm (đường tương đối `src/Client-app`). RỖNG từ ngày tạo (2026-10-20).
const conCho = <String>{};

const _thuMuc = 'lib/core/sync/';

String _duong(FileSystemEntity e) => e.path.replaceAll('\\', '/');

/// Lời vi phạm của tệp [duongTep] (dạng `lib/...`) với nội dung [noiDung]; cùng hàm cho phép quét thật và hai đối chứng.
List<String> viPhamCua(String duongTep, String noiDung) => [
      if (!duongTep.startsWith(_thuMuc))
        for (final duong in duongChiThi(noiDung))
          if (dichTrongLib(duongTep, duong) case final dich?)
            if (dich.startsWith(_thuMuc) && !cuaCongKhai.containsKey(dich.substring(_thuMuc.length)))
              "chỉ thị '$duong' → $dich là tệp NỘI BỘ của core/sync — đi qua SyncEngine (hoặc mở cửa ở cuaCongKhai, có lý do)",
    ];

/// Số chỉ thị hợp lệ đi vào [cuaCongKhai] của [duongTep] — đối chứng dương.
int soChiThiVaoCua(String duongTep, String noiDung) => [
      for (final duong in duongChiThi(noiDung))
        if (dichTrongLib(duongTep, duong) case final dich?)
          if (dich.startsWith(_thuMuc) && cuaCongKhai.containsKey(dich.substring(_thuMuc.length))) dich,
    ].length;

List<File> _tepNgoaiCoreSync() => [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (_duong(f).endsWith('.dart') && !_duong(f).startsWith(_thuMuc)) f,
    ];

void main() {
  test('đối chứng âm: chỉ thị vào tệp nội bộ bị bắt — tương đối, package:, export, vế điều kiện', () {
    expect(viPhamCua('lib/core/auth/x.dart', "import '../sync/thu_gom_day.dart';"), hasLength(1));
    expect(
        viPhamCua('lib/features/a/data/x.dart', "import 'package:flowmoney/core/sync/moc_keo_ve.dart';"), hasLength(1));
    expect(viPhamCua('lib/main.dart', "export 'core/sync/gui_lo_dong_bo.dart' show GuiLoDongBo;"), hasLength(1));
    expect(
        viPhamCua('lib/core/nen/x.dart', "import 'a.dart'\n    if (dart.library.io) '../sync/ap_du_lieu_keo_ve.dart';"),
        hasLength(1));
    expect(viPhamCua('lib/core/auth/x.dart', "import '../sync/sync_engine.dart';"), isEmpty,
        reason: 'Cửa công khai không phải vi phạm.');
    expect(viPhamCua('lib/core/sync/sync_engine.dart', "import 'thu_gom_day.dart';"), isEmpty,
        reason: 'Trong core/sync thì dùng tệp nội bộ là đúng.');
  });

  test('luật 2: mỗi tên trong cuaCongKhai còn là tệp thật của core/sync', () {
    final thieu = [
      for (final ten in cuaCongKhai.keys)
        if (!File('$_thuMuc$ten').existsSync()) ten,
    ];
    expect(thieu, isEmpty, reason: 'Tệp đã đổi tên / xoá — rút khỏi cuaCongKhai: $thieu');
  });

  test('luật 1: ngoài lib/core/sync/ chỉ chạm core/sync qua cuaCongKhai — trừ conCho rút dần', () {
    final tep = _tepNgoaiCoreSync();
    expect(tep.length, greaterThan(500),
        reason: 'Phải thấy cả lib/ (đo 2026-10-20: 644 tệp ngoài core/sync) — đang quét sai thư mục.');

    final viPham = <String, List<String>>{};
    var vaoCua = 0;
    for (final f in tep) {
      final d = _duong(f);
      final noiDung = f.readAsStringSync();
      vaoCua += soChiThiVaoCua(d, noiDung);
      final loi = viPhamCua(d, noiDung);
      if (loi.isNotEmpty) viPham[d] = loi;
    }
    expect(vaoCua, greaterThanOrEqualTo(15),
        reason:
            'Đối chứng dương: đo 2026-10-20 có 19 chỉ thị vào cửa công khai — thấy ít hơn là bộ đọc chỉ thị đã mù.');

    final loi = <String>[
      for (final e in viPham.entries)
        if (!conCho.contains(e.key)) '${e.key}: ${e.value.join('; ')}',
      for (final c in conCho)
        if (!viPham.containsKey(c)) '$c: đã sạch — rút khỏi conCho.',
    ];
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
