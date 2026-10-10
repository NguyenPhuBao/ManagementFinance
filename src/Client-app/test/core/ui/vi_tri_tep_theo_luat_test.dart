/// Test quét `lib/` thứ **25** (spec dọn vị trí tệp 2026-10-10, mục 4): cây `lib/` và `test/` khớp luật vị trí tệp —
/// mục 8 `docs/KIEN_TRUC_CLIENT_APP.md`.
///
/// Một tệp đặt sai chỗ không lỗi gì lúc chạy: trang vẫn dựng, test vẫn xanh. Nó chỉ làm người sau tìm không ra, làm
/// `core` biết dần từng mảng, và làm cùng một loại tệp nằm hai chỗ ở hai mảng. Sáu luật ở đây là phần máy canh được
/// của bảng mục 8; chỗ xếp giữa `bloc/` · `widgets/` · `state/` và hàng *"hạ tầng core cần → core/<chủ đề>"* là luật
/// đọc, không canh. 52 tệp rời dưới `data/` (`*_nguon`, `*_store`, tool AI) cố ý KHÔNG canh — bảng chưa có hàng cho chúng.
///
/// Khuôn quét 22/23: vi phạm còn chờ dọn nằm trong [conCho] (đường dẫn) và [conChoCoreImport] (tệp → số dòng); cả hai
/// CHỈ ĐƯỢC GIẢM, sạch rồi quên rút thì test đỏ. Miễn trừ đích danh có lý do ở [mienTru]; thư mục miễn trừ không còn
/// tồn tại thì test cũng đỏ để rút dòng miễn trừ.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Thư mục được phép ngay dưới `lib/features/<x>/`.
const tangMang = {'data', 'domain', 'presentation'};

/// Thư mục được phép ngay dưới `presentation/` (bảng mục 8: Bloc / Cubit · trang · widget · tệp trạng thái).
const conPresentation = {'bloc', 'pages', 'widgets', 'state'};

/// 16 chủ đề của `core/` — thêm chủ đề là một quyết định có ý thức: ghi vào đây (mục 4 tài liệu kiến trúc).
const chuDeCore = {
  'api', 'auth', 'category', 'constants', 'database', 'di', 'errors', 'nen', 'network', 'notification', 'ocr',
  'realtime', 'router', 'sync', 'ui', 'utils',
};

/// Điểm ghép — tệp `core` được biết mọi mảng (mục 4 tài liệu kiến trúc). Không trần.
const diemGhep = {
  'lib/core/di/injection_container.dart',
  'lib/core/constants/app_router.dart', // Task 8 đổi sang lib/core/router/app_router.dart
  'lib/core/nen/chay_nen.dart',
};

/// Thư mục cấp 1 được phép dưới `test/`; `helpers` và `tool` không soi gương `lib/`.
const gocTest = {'core', 'features', 'shared', 'helpers', 'tool'};

/// Thư mục miễn trừ đích danh (tương đối `src/Client-app`) → lý do. Không còn tồn tại → đỏ để rút.
const mienTru = <String, String>{
  'lib/features/ai_chat/spike':
      'mã đo spike C4 sau cờ --dart-define=SPIKE_C4 — gỡ khi C4 chốt lối (spec dọn vị trí tệp 2026-10-10, quyết định 3)',
};

/// Luật 1–4 và 6: vi phạm còn chờ dọn (đường dẫn tương đối `src/Client-app`). Điền từ lượt chạy đỏ; rút dần theo nhóm.
const conCho = <String>{
  // Luật 2 — tệp rời dưới presentation/ (kế hoạch Task 4, 5).
  'lib/features/auth/presentation/an_the_cho_xoa.dart',
  'lib/features/auth/presentation/huy_yeu_cau_xoa.dart',
  'lib/features/auth/presentation/xac_nhan_dang_xuat.dart',
  'lib/features/premium/presentation/an_nhac_het_han.dart',
  'lib/features/premium/presentation/co_quyen.dart',
  'lib/features/premium/presentation/phien_goi_tu_auth.dart',
  'lib/features/wallet/presentation/an_nhac_vi_trung_ten.dart',
  'lib/features/premium/presentation/cubit',
  // Luật 4 — chủ đề core ngoài danh sách (Task 7).
  'lib/core/bill',
  // Luật 6 — test ở gốc, thư mục không soi gương (Task 9).
  'test/e2e_sqlite_to_backend_sync_test.dart',
  'test/transaction_repository_test.dart',
  'test/widget_test.dart',
  'test/features/layout',
};

/// Luật 5: tệp hạ tầng `core` còn import `features/` → số dòng tối đa. Chỉ được giảm — ngoại lệ duy nhất ghi rõ tại chỗ.
/// Đo 2026-10-10. `current_account` rời core ở Task 4. 12 tệp còn lại là nợ G88 gạch 4, không thuộc đợt này.
const conChoCoreImport = <String, int>{
  'lib/core/auth/current_account.dart': 1,
  'lib/core/notification/notification_rules.dart': 10,
  'lib/core/sync/sync_engine.dart': 6,
  'lib/core/notification/notification_scanner.dart': 5,
  'lib/core/nen/lich_nen.dart': 3,
  'lib/core/sync/sync_payload_normalizer.dart': 2,
  'lib/core/sync/noi_bo_nghe_ket_qua_day.dart': 2,
  'lib/core/notification/reminder_scheduler.dart': 2,
  'lib/core/notification/nhap_bien_lai.dart': 2,
  'lib/core/ocr/kho_anh_quet.dart': 1,
  'lib/core/notification/nhap_bien_dong.dart': 1,
  'lib/core/database/daos/wallet_dao.dart': 1,
  'lib/core/database/daos/other_daos.dart': 1,
};

String _duong(FileSystemEntity e) => e.path.replaceAll('\\', '/');
String _ten(FileSystemEntity e) => _duong(e).split('/').last;

void main() {
  test('tiền đề: phép quét thấy đủ cây (chạy từ src/Client-app)', () {
    expect(Directory('lib/features').existsSync(), isTrue, reason: 'Chạy từ src/Client-app.');
    expect(Directory('lib/features').listSync().whereType<Directory>().length, greaterThanOrEqualTo(14),
        reason: 'Phải thấy ≥ 14 mảng — đang quét sai thư mục.');
    expect(Directory('lib/core').listSync().whereType<Directory>().length, greaterThanOrEqualTo(10));
    expect(Directory('test/features').existsSync(), isTrue);
    for (final m in mienTru.keys) {
      expect(Directory(m).existsSync(), isTrue, reason: '$m không còn — rút khỏi mienTru (và khỏi docstring).');
    }
  });

  test('luật 1–4, 6: cây lib/ và test/ khớp bảng mục 8, trừ conCho rút dần', () {
    final viPham = <String, String>{};
    void ghi(String duong, String viSao) =>
        viPham.update(duong, (cu) => '$cu; $viSao', ifAbsent: () => viSao);
    bool mienTruChua(String d) => mienTru.keys.any((m) => d == m || d.startsWith('$m/'));

    // Luật 1 — gốc lib/ và từng mảng.
    for (final e in Directory('lib').listSync()) {
      if (e is File && _ten(e) != 'main.dart') ghi(_duong(e), 'tệp rời ở gốc lib/ — chỉ main.dart');
      if (e is Directory && !{'core', 'features', 'shared'}.contains(_ten(e))) ghi(_duong(e), 'thư mục lạ ở gốc lib/');
    }
    for (final mang in Directory('lib/features').listSync()) {
      if (mang is File) {
        ghi(_duong(mang), 'tệp rời ngay dưới features/ — phải thuộc một mảng');
        continue;
      }
      for (final e in (mang as Directory).listSync()) {
        final d = _duong(e);
        if (mienTruChua(d)) continue;
        if (e is File) ghi(d, 'tệp rời ngay dưới features/<x>/ — vào data/ · domain/ · presentation/');
        if (e is Directory && !tangMang.contains(_ten(e))) ghi(d, 'thư mục ngoài data/ · domain/ · presentation/');
      }
    }

    // Luật 2 — presentation/ không tệp rời, chỉ bốn thư mục con.
    for (final mang in Directory('lib/features').listSync().whereType<Directory>()) {
      final pres = Directory('${_duong(mang)}/presentation');
      if (!pres.existsSync()) continue;
      for (final e in pres.listSync()) {
        final d = _duong(e);
        if (e is File) ghi(d, 'tệp rời ngay dưới presentation/ — vào bloc/ · pages/ · widgets/ · state/');
        if (e is Directory && !conPresentation.contains(_ten(e))) {
          ghi(d, 'thư mục ngoài bloc/ · pages/ · widgets/ · state/');
        }
      }
    }

    // Luật 3 — repository ở data/repositories/, interface không gộp Impl.
    final laRepo = RegExp(r'_repository(_impl)?\.dart$');
    final coImpl = RegExp(r'^class \w+Impl\b', multiLine: true);
    for (final f in Directory('lib/features').listSync(recursive: true).whereType<File>()) {
      final d = _duong(f);
      if (!d.endsWith('.dart') || mienTruChua(d)) continue;
      final ten = _ten(f);
      if (!laRepo.hasMatch(ten)) continue;
      final cha = d.split('/').reversed.elementAt(1);
      if (cha != 'repositories') ghi(d, 'repository ngoài data/repositories/');
      if (!ten.endsWith('_impl.dart') && coImpl.hasMatch(f.readAsStringSync())) {
        ghi(d, 'interface + bản thi hành gộp một tệp — tách <x>_repository_impl.dart');
      }
    }

    // Luật 4 — core/ chỉ gồm 16 chủ đề, không tệp rời.
    for (final e in Directory('lib/core').listSync()) {
      final d = _duong(e);
      if (e is File) ghi(d, 'tệp rời ở gốc core/ — vào core/<chủ đề>/');
      if (e is Directory && !chuDeCore.contains(_ten(e))) {
        ghi(d, 'chủ đề core ngoài danh sách chuDeCore — thêm có ý thức, hoặc dời luật về features/<x>/');
      }
    }

    // Luật 6 — test/ không test ở gốc; thư mục soi gương lib/ (theo thư mục, không theo tệp).
    for (final e in Directory('test').listSync()) {
      final d = _duong(e);
      if (e is File && d.endsWith('_test.dart')) ghi(d, 'test ở gốc test/ — soi gương lib/');
      if (e is Directory && !gocTest.contains(_ten(e))) ghi(d, 'thư mục cấp 1 ngoài core · features · shared · helpers · tool');
    }
    for (final goc in ['test/core', 'test/features', 'test/shared']) {
      if (!Directory(goc).existsSync()) continue;
      for (final d in Directory(goc).listSync(recursive: true).whereType<Directory>()) {
        final rel = _duong(d);
        final guong = 'lib/${rel.substring('test/'.length)}';
        if (!Directory(guong).existsSync()) ghi(rel, 'không có thư mục soi gương $guong');
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

  test('luật 5: core chỉ import features/ ở điểm ghép; hạ tầng còn lại rút dần', () {
    final importFeatures = RegExp(r"^import '[^']*features/");
    final thay = <String, int>{};
    for (final f in Directory('lib/core').listSync(recursive: true).whereType<File>()) {
      final d = _duong(f);
      if (!d.endsWith('.dart')) continue;
      final n = f.readAsLinesSync().where(importFeatures.hasMatch).length;
      if (n > 0) thay[d] = n;
    }
    expect(thay.values.fold<int>(0, (a, b) => a + b), greaterThan(100),
        reason: 'tiền đề: phải thấy điểm ghép (DI ~80 dòng) — đang quét sai thư mục.');

    final loi = <String>[];
    for (final g in diemGhep) {
      if (!File(g).existsSync()) loi.add('$g: điểm ghép không còn tồn tại — sửa diemGhep.');
    }
    for (final e in thay.entries) {
      if (diemGhep.contains(e.key)) continue;
      final tran = conChoCoreImport[e.key];
      if (tran == null) {
        loi.add('${e.key}: ${e.value} dòng import features/ — hạ tầng core không được biết mảng (mục 4 kiến trúc); '
            'dời luật về features/<x>/ hoặc nhận hook qua DI.');
      } else if (e.value > tran) {
        loi.add('${e.key}: ${e.value} dòng, danh sách cho phép $tran — chỉ được giảm.');
      }
    }
    for (final e in conChoCoreImport.entries) {
      if (!thay.containsKey(e.key)) loi.add('${e.key}: đã sạch — rút khỏi conChoCoreImport.');
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
