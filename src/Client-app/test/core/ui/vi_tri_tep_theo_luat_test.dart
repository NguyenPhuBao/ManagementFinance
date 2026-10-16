/// Test quét `lib/` thứ **25** (spec dọn vị trí tệp 2026-10-10, mục 4): cây `lib/` và `test/` khớp luật vị trí tệp —
/// mục 8 `docs/KIEN_TRUC_CLIENT_APP.md`.
///
/// Một tệp đặt sai chỗ không lỗi gì lúc chạy: trang vẫn dựng, test vẫn xanh. Nó chỉ làm người sau tìm không ra, làm
/// `core` biết dần từng mảng, và làm cùng một loại tệp nằm hai chỗ ở hai mảng. Tám luật ở đây (luật 5b từ 2026-10-15: tệp core được đọc phải thuần; luật 7 từ 2026-10-15: chiều một hướng với `application/`) là phần máy canh được
/// của bảng mục 8; chỗ xếp giữa `bloc/` · `widgets/` · `state/` và hàng *"hạ tầng core cần → core/<chủ đề>"* là luật
/// đọc, không canh. 56 tệp rời dưới `data/` (đo 2026-10-15) (`*_nguon`, `*_store`, tool AI) cố ý KHÔNG canh — bảng chưa có hàng cho chúng.
///
/// Khuôn quét 22/23: vi phạm còn chờ dọn nằm trong [conCho] (đường dẫn), CHỈ ĐƯỢC GIẢM, sạch rồi quên rút thì test đỏ.
/// Luật 5 từ 2026-10-15 không còn danh sách chờ: [domainThuanChoCore] là danh sách CỐ ĐỊNH các tệp thuần core được đọc
/// (G88 gạch 4 đóng), luật 5b canh chúng thuần. Miễn trừ đích danh có lý do ở [mienTru]; thư mục miễn trừ không còn
/// tồn tại thì test cũng đỏ để rút dòng miễn trừ.
///
/// Chỉ thị (luật 5, 5b, 7) đọc qua `test/helpers/chi_thi_dart.dart` — thấy `part`, import có điều kiện, chỉ thị nhiều dòng
/// (từ 2026-10-16).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chi_thi_dart.dart';

/// Thư mục được phép ngay dưới `lib/features/<x>/` — `application/` từ 2026-10-15 (spec Entity Thông báo mục 8).
const tangMang = {'data', 'domain', 'presentation', 'application'};

/// Thư mục được phép ngay dưới `presentation/` (bảng mục 8: Bloc / Cubit · trang · widget · tệp trạng thái).
const conPresentation = {'bloc', 'pages', 'widgets', 'state'};

/// 15 chủ đề của `core/` (`notification` về `features/notification` 2026-10-15) — thêm chủ đề là một quyết định có ý thức: ghi vào đây (mục 4 tài liệu kiến trúc).
const chuDeCore = {
  'api', 'auth', 'category', 'constants', 'database', 'di', 'errors', 'nen', 'network', 'ocr',
  'realtime', 'router', 'sync', 'ui', 'utils',
};

/// Điểm ghép — tệp `core` được biết mọi mảng (mục 4 tài liệu kiến trúc). Không trần.
const diemGhep = {
  'lib/core/di/injection_container.dart',
  'lib/core/router/app_router.dart',
  'lib/core/nen/chay_nen.dart',
  // Điểm ghép thứ tư (KIEN_TRUC mục 4): chỉ biết bộ quét thông báo qua tham số boQuet.
  'lib/core/auth/phien_dieu_phoi_that.dart',
};

/// Thư mục cấp 1 được phép dưới `test/`; `helpers` và `tool` không soi gương `lib/`.
const gocTest = {'core', 'features', 'shared', 'helpers', 'tool'};

/// Thư mục miễn trừ đích danh (tương đối `src/Client-app`) → lý do. Không còn tồn tại → đỏ để rút.
// Rỗng từ 2026-10-12 (C4 chốt lối, spike gỡ).
const mienTru = <String, String>{};

/// Luật 1–4 và 6: vi phạm còn chờ dọn (đường dẫn tương đối `src/Client-app`). Điền từ lượt chạy đỏ; rút dần theo nhóm.
// Rỗng từ 2026-10-10 — thêm vào đây là mở lại một nợ, phải có lý do và ngày.
const conCho = <String>{};

/// Luật 5 (viết lại 2026-10-15 — G88 gạch 4 đóng; trước đó là ratchet tệp → số dòng, đo gốc 2026-10-10 43 dòng): tệp hạ tầng
/// `core` (ngoài [diemGhep]) chỉ được import / export `features/` khi đích nằm trong danh sách CỐ ĐỊNH này — hằng số / hàm thuần
/// của mảng mà bộ dịch payload (`SyncEngine`, `SyncPayloadNormalizer`) và câu SQL của DAO phải đọc. Quyết định người dùng
/// 2026-10-11 (G88 mục 4 📝): core được đọc hằng số / hàm thuần của mảng; thứ có trạng thái hay I/O đi qua cổng ở
/// `core/<chủ đề>/` + DI truyền bản thật (tiền lệ `core/sync/cong_so_du_vi.dart`, `cong_vi_bi_giu.dart`). Thêm tệp vào đây =
/// sửa test = có người soát; tệp trong danh sách phải THUẦN (luật 5b) và phải còn ít nhất một tệp core đọc (không thì rút).
const domainThuanChoCore = {
  'lib/features/wallet/domain/wallet_status.dart',
  'lib/features/wallet/domain/wallet_type.dart',
  'lib/features/bill/domain/bill_pay_status.dart',
  'lib/features/bill/domain/bill_recurrence.dart',
  'lib/features/goal/domain/uu_tien_hop_le.dart',
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
        if (e is File) ghi(d, 'tệp rời ngay dưới features/<x>/ — vào data/ · domain/ · presentation/ · application/');
        if (e is Directory && !tangMang.contains(_ten(e))) ghi(d, 'thư mục ngoài data/ · domain/ · presentation/ · application/');
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

    // Luật 4 — core/ chỉ gồm 15 chủ đề, không tệp rời.
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

  test('luật 5: core chỉ import features/ ở điểm ghép; hạ tầng còn lại chỉ đọc hằng / hàm thuần trong domainThuanChoCore', () {
    var tong = 0;
    final docDuoc = <String>{};
    final loi = <String>[];
    for (final g in diemGhep) {
      if (!File(g).existsSync()) loi.add('$g: điểm ghép không còn tồn tại — sửa diemGhep.');
    }
    for (final f in Directory('lib/core').listSync(recursive: true).whereType<File>()) {
      final d = _duong(f);
      if (!d.endsWith('.dart')) continue;
      for (final duong in duongChiThi(f.readAsStringSync())) {
        if (!duong.contains('features/')) continue;
        tong++;
        if (diemGhep.contains(d)) continue;
        final dich = dichTrongLib(d, duong);
        if (dich != null && domainThuanChoCore.contains(dich)) {
          docDuoc.add(dich);
        } else {
          loi.add("$d: chỉ thị '$duong' — hạ tầng core chỉ được đọc hằng / hàm thuần trong domainThuanChoCore "
              '(mục 4 kiến trúc); thứ có trạng thái hay I/O → cổng ở core/<chủ đề>/ + DI truyền bản thật, hoặc dời về features/<x>/.');
        }
      }
    }
    expect(tong, greaterThan(100), reason: 'tiền đề: phải thấy điểm ghép (DI ~100 dòng) — đang quét sai thư mục.');
    for (final t in domainThuanChoCore) {
      if (!File(t).existsSync()) {
        loi.add('$t: không còn tồn tại — sửa domainThuanChoCore.');
      } else if (!docDuoc.contains(t)) {
        loi.add('$t: không tệp hạ tầng core nào đọc nữa — rút khỏi domainThuanChoCore.');
      }
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });

  test('luật 5b: tệp trong domainThuanChoCore THUẦN — chỉ import dart: hoặc data/models/ của chính mảng nó', () {
    final loi = <String>[];
    for (final t in domainThuanChoCore) {
      if (!File(t).existsSync()) continue; // luật 5 đã báo
      final mang = t.split('/')[2]; // lib/features/<mang>/…
      for (final duong in duongChiThi(File(t).readAsStringSync())) {
        if (duong.startsWith('dart:')) continue;
        final dich = dichTrongLib(t, duong);
        if (dich != null && dich.startsWith('lib/features/$mang/data/models/')) continue;
        loi.add("$t: chỉ thị '$duong' — core đọc tệp này, mọi phụ thuộc của nó thành phụ thuộc của hạ tầng; giữ tệp thuần "
            '(dart: hoặc data/models/ của mảng), dời phần nặng ra tệp khác.');
      }
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });

  test('luật 7: data/ và domain/ không import application/ — chiều một hướng (spec Entity Thông báo 2026-10-15 mục 8)', () {
    // `import` / `export` / `part` (kể cả vế có điều kiện) qua `duongChiThi`. Đích chuẩn hoá qua `dichTrongLib`: bắt cả
    // đường tương đối (`../application/x.dart`) lẫn `package:flowmoney/`; gói ngoài (null) bỏ qua.
    bool chamApplication(String tep, String duong) => (dichTrongLib(tep, duong) ?? '').contains('/application/');
    final loi = <String>[];
    var soTep = 0;
    for (final f in Directory('lib/features').listSync(recursive: true).whereType<File>()) {
      final d = _duong(f);
      if (!d.endsWith('.dart') || !(d.contains('/data/') || d.contains('/domain/'))) continue;
      soTep++;
      if (duongChiThi(f.readAsStringSync()).any((duong) => chamApplication(d, duong))) {
        loi.add('$d: import application/ — data/ và domain/ nằm DƯỚI application (mục 4 kiến trúc); '
            'dời luật thuần về domain/, hoặc để application gọi xuống.');
      }
    }
    expect(soTep, greaterThan(150),
        reason: 'tiền đề: phải thấy features/*/data + features/*/domain (đo 2026-10-15 sau đợt Thông báo: 287 tệp) — đang quét sai thư mục.');
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
