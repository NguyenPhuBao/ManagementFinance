/// Test quét `lib/` thứ **27** (spec Entity Hoá đơn 2026-10-14, mục 8): giao diện và domain không cầm kiểu hàng Drift.
///
/// Bốn luật. (1) `presentation/` + `shared/` + `lib/core` (trừ `core/database`, `core/sync` — kể cả ba điểm ghép DI / router / nen,
/// đo 2026-10-14 = 0) + `features/*/domain/` (từ 2026-10-15) không nhắc tên kiểu hàng Drift — [kieuDrift] và companion tương ứng —
/// so trên dòng đã bỏ chú thích, vì docstring vùng này hay nhắc *"đối tượng `Bill`"*. (2) `features/*/domain/` không import
/// `core/database` hay `package:drift` (mục 4 `KIEN_TRUC_CLIENT_APP.md`: domain là Dart thuần). (3) `features/*/data/` và
/// `features/*/application/` (từ đợt Thông báo) không khai `Stream<dynamic>` · `Future<dynamic>` · `List<dynamic>` · `Iterable<dynamic>` —
/// `dynamic` là cách hàng Drift đi qua chữ ký mà luật 1 mù (`GoalRepository.watchGoalTransactions` giấu hàng `Transaction` hai tháng,
/// lộ ở lượt soát 2026-10-14). (4) Interface repository `features/*/data/repositories/*_repository.dart` không import `core/database` /
/// `package:drift` — lối chuyển tiếp **không nêu tên kiểu** (`final hang = await dao.getAll(id)`) là thứ luật 1 mù; chốt ở chữ ký
/// interface là chốt được (spec Entity Thông báo 2026-10-15 mục 9). Tệp còn vi phạm nằm trong danh sách chờ chỉ-được-giảm ([conChoKieu]
/// theo kiểu, [conChoDomain], [conChoDynamic]); sạch mà quên rút thì đỏ (khuôn quét 22 / 25). Kiểu KHÔNG có khoá trong [conChoKieu] là
/// kiểu không có chỗ chờ trong phạm vi quét — nhắc tới là đỏ ngay.
/// Mở rộng 2026-10-14 (spec Entity Giao dịch + Ví mục 8); 2026-10-15 (spec Entity Danh mục mục 9): luật 1 quét domain, luật 3;
/// 2026-10-15 (spec Entity Thông báo mục 9): `AppNotificationEvent`, luật 3 quét `application/`, luật 4, `mauKieu` bắt ` &&` / ` ||`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kiểu hàng Drift mà giao diện, domain hay `core` từng cầm. Thêm bảng mới có hàng lên các tầng ấy thì thêm ở đây.
const kieuDrift = [
  'Bill',
  'Wallet',
  'Category',
  'Transaction',
  'Goal',
  'Budget',
  'AppNotification',
  'AppNotificationEvent'
];

/// Companion của từng kiểu — Drift đặt theo tên BẢNG (`Bills` → `BillsCompanion`, `Categories` → `CategoriesCompanion`).
const companionCua = {
  'Bill': 'BillsCompanion',
  'Wallet': 'WalletsCompanion',
  'Category': 'CategoriesCompanion',
  'Transaction': 'TransactionsCompanion',
  'Goal': 'GoalsCompanion',
  'Budget': 'BudgetsCompanion',
  'AppNotification': 'AppNotificationsCompanion',
  'AppNotificationEvent': 'AppNotificationEventsCompanion',
};

/// Luật 1 — kiểu → tệp (tương đối `lib/`) còn cầm kiểu ấy. Mỗi đợt Entity xoá một khoá (Bill 2026-10-14; Wallet, Transaction cùng ngày, đợt 2; Category đợt 3 2026-10-15; AppNotification + AppNotificationEvent đợt 4 2026-10-15).
const conChoKieu = <String, Set<String>>{
  'AppNotification': {
    'core/notification/nhap_bien_dong.dart',
    'core/notification/nhap_bien_lai.dart',
    'core/notification/nhap_phien_ngan_hang.dart',
    'core/notification/notification_scanner.dart',
  },
  // Bảng sự kiện B5a (v26) — `deXuatThongBao` nhận record `SuKienNhatKy` ở Task 4 đợt Thông báo; `nhat_ky_thong_bao` về `data/` ở Task 6.
  'AppNotificationEvent': {
    'core/notification/nhat_ky_thong_bao.dart',
  },
};

/// Luật 2 — tệp `domain/` còn import `core/database` / `package:drift`. Rỗng từ 2026-10-15 (đợt Entity Danh mục); thêm tệp là đỏ ngay.
const conChoDomain = <String>{};

/// Luật 3 — tệp `features/*/data/` (tương đối `lib/`; từ đợt Thông báo quét cả `application/`) còn khai `<dynamic>` trần ở chữ ký. Điền từ lượt chạy đầu 2026-10-15; Task 5 đợt
/// Entity Danh mục rút cả hai (`watchGoalTransactions` → `Stream<List<TransactionEntity>>`).
const conChoDynamic = <String>{};

/// `Stream<dynamic>` · `Future<dynamic>` · `List<dynamic>` · `Iterable<dynamic>` (kể cả `as List<dynamic>?`) — nhưng KHÔNG
/// `Map<String, dynamic>` (JSON của `auth`, `ai_edge`). Phạm vi cố ý hẹp: không quét `core/sync` (đọc payload) và `core/router`
/// (`GoRouterRefreshStream(Stream<dynamic>)` của go_router).
final mauDynamic = RegExp(r'\b(Stream|Future|List|Iterable)<dynamic>');

/// Bỏ chú thích: dòng `//` / `///`, và đuôi ` // …` sau mã.
String boChuThich(String d) {
  if (d.trimLeft().startsWith('//')) return '';
  final i = d.indexOf(RegExp(r'\s//'));
  return i < 0 ? d : d.substring(0, i);
}

/// `Bill?` · `List<Bill>` · `Bill bill` · `, Bill)` · `as Bill;` · `Bill.fromJson(` · `is Bill &&` · `is Bill ||` — nhưng KHÔNG `BillBloc`,
/// `BillEntity`, `BillRepository`, `BillEntity.fromDrift(`. (`>[` / `>(` đã bắt qua `>`.)
RegExp mauKieu(String ten) =>
    RegExp('\\b$ten(\\?|>| [a-z_][A-Za-z0-9_]*\\b|,|\\)|;|\\.fromJson| &&| \\|\\|)');

/// Dòng import mà luật 2 cấm trong features/*/domain/: core/database hoặc package:drift.
bool importCam(String d) =>
    d.startsWith('import ') &&
    (d.contains('core/database') || d.contains('package:drift'));

/// Companion còn bắt cả dựng (`BillsCompanion(` / `.insert(`).
RegExp mauCompanion(String ten) =>
    RegExp('\\b$ten(\\?|>| [a-z_][A-Za-z0-9_]*\\b|,|\\)|\\(|\\.)');

String _duong(FileSystemEntity f) =>
    f.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?lib/'), '');

Iterable<File> _dart(Directory d) => d
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('tiền đề: phép quét thấy đủ cây và mẫu nhận đúng kiểu', () {
    expect(Directory('lib/features').existsSync(), isTrue,
        reason: 'Chạy từ src/Client-app.');
    expect(Directory('lib/features').listSync().whereType<Directory>().length,
        greaterThanOrEqualTo(14));
    final m = mauKieu('Bill');
    expect(m.hasMatch('final List<Bill> bills;'), isTrue);
    expect(m.hasMatch('Future<Bill?> getById(String id);'), isTrue);
    expect(
        m.hasMatch('void moBang(BuildContext context, Bill bill) {'), isTrue);
    expect(m.hasMatch('bill: s.extra as Bill?,'), isTrue);
    expect(m.hasMatch('final b = x as Bill;'), isTrue);
    expect(m.hasMatch('Bill.fromJson(json)'), isTrue);
    expect(m.hasMatch('if (x is Bill && x.isPaid) {'), isTrue,
        reason: 'is X && từng lọt (bàn giao đợt 3) — sau dấu cách là & chứ không phải tên biến.');
    expect(m.hasMatch('final ok = y is Bill || z;'), isTrue);
    expect(m.hasMatch('if (x is BillEntity && x.isPaid) {'), isFalse);
    expect(m.hasMatch('BillEntity.fromDrift(row)'), isFalse);
    expect(m.hasMatch('class BillBloc extends Bloc<BillEvent, BillState> {'),
        isFalse);
    expect(m.hasMatch('final BillEntity bill;'), isFalse);
    expect(
        mauCompanion('BillsCompanion')
            .hasMatch('return BillsCompanion.insert('),
        isTrue);
    expect(importCam("import 'package:drift/drift.dart' show Value;"), isTrue);
    expect(importCam("import '../../../core/database/app_database.dart';"),
        isTrue);
    expect(importCam("import 'dart:io';"), isFalse);
    expect(mauDynamic.hasMatch('  Stream<dynamic> watchGoalTransactions('), isTrue);
    expect(mauDynamic.hasMatch('final txs = (snapshot.data as List<dynamic>?) ?? [];'), isTrue);
    expect(mauDynamic.hasMatch('  Future<dynamic> f() async => null;'), isTrue,
        reason: 'Future<dynamic> là dạng bị cấm.');
    expect(mauDynamic.hasMatch('  Iterable<dynamic> get xs;'), isTrue,
        reason: 'Iterable<dynamic> là dạng bị cấm.');
    expect(mauDynamic.hasMatch('  MyStream<dynamic> s;'), isFalse,
        reason: r'\b phải loại tên ghép (MyStream không phải Stream).');
    expect(mauDynamic.hasMatch('  Future<Map<String, dynamic>> getProfile();'), isFalse,
        reason: 'JSON là Map<String, dynamic> — không phải lỗ hàng Drift.');
    expect(boChuThich('  /// đối tượng `Bill` đang giữ'), '');
    expect(boChuThich('  final Bill bill; // ảnh chụp Bill'),
        '  final Bill bill;');
  });

  test(
      'luật 1: presentation/, shared/, core/ và domain/ không nhắc kiểu hàng Drift, trừ danh sách chờ theo kiểu (chỉ được giảm)',
      () {
    final thay = <String, Set<String>>{};
    var soTepTrang = 0;
    var soTepCore = 0;
    var soTepDomain = 0;
    for (final goc in [
      Directory('lib/features'),
      Directory('lib/shared'),
      Directory('lib/core'),
    ]) {
      for (final f in _dart(goc)) {
        final duong = _duong(f);
        if (duong.startsWith('features/')) {
          if (duong.contains('/presentation/')) {
            soTepTrang++;
          } else if (duong.contains('/domain/')) {
            soTepDomain++;
          } else {
            continue; // data/ được cầm hàng Drift — đó là tầng ánh xạ.
          }
        } else if (duong.startsWith('core/database/') ||
            duong.startsWith('core/sync/')) {
          // Hạ tầng CSDL và đồng bộ cầm hàng Drift là đúng vai; mọi tệp core khác (kể cả điểm ghép) không.
          continue;
        } else if (duong.startsWith('core/')) {
          soTepCore++;
        } else {
          soTepTrang++; // shared/
        }
        final dong = f.readAsLinesSync().map(boChuThich).toList();
        for (final k in kieuDrift) {
          final mk = mauKieu(k);
          final mc = mauCompanion(companionCua[k]!);
          if (dong.any((d) => mk.hasMatch(d) || mc.hasMatch(d))) {
            thay.putIfAbsent(k, () => {}).add(duong);
          }
        }
      }
    }
    // Ba sàn ≈ nửa số đo 2026-10-15 (206 · 77 · 164) — quét sai thư mục là đỏ ở đây, không phải xanh im lặng.
    expect(soTepTrang, greaterThan(100),
        reason: 'Phép quét phải thấy tệp presentation + shared — đang quét sai thư mục.');
    expect(soTepCore, greaterThan(20),
        reason: 'Phép quét phải thấy lib/core ngoài database/sync — đang bỏ sót core.');
    expect(soTepDomain, greaterThan(80),
        reason: 'Phép quét phải thấy features/*/domain — đang bỏ sót domain.');

    final loi = <String>[];
    for (final k in kieuDrift) {
      final co = thay[k] ?? const <String>{};
      final cho = conChoKieu[k];
      for (final t in co) {
        if (cho == null) {
          loi.add(
              '$k: $t — kiểu này không có chỗ chờ trong phạm vi quét (presentation / shared / core / domain), nhắc tới là đỏ (spec Entity Danh mục mục 9).');
        } else if (!cho.contains(t)) {
          loi.add(
              '$k: $t không có trong conChoKieu — danh sách chỉ được giảm.');
        }
      }
      for (final t in cho ?? const <String>{}) {
        if (!co.contains(t)) loi.add('$k: $t đã sạch — rút khỏi conChoKieu.');
      }
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });

  test(
      'luật 2: features/*/domain/ không import core/database hay package:drift, trừ danh sách chờ (chỉ được giảm)',
      () {
    final thay = <String>{};
    var soTep = 0;
    for (final f in _dart(Directory('lib/features'))) {
      final duong = _duong(f);
      if (!duong.contains('/domain/')) continue;
      soTep++;
      if (f.readAsLinesSync().any(importCam)) {
        thay.add(duong);
      }
    }
    expect(soTep, greaterThan(80),
        reason:
            'Phép quét phải thấy features/*/domain — bộ lọc luật 2 hỏng thì đỏ ở đây, không xanh im lặng (danh sách chờ đã rỗng từ 2026-10-15).');
    final loi = <String>[
      for (final t in thay)
        if (!conChoDomain.contains(t))
          '$t: domain import core/database / package:drift — nhận Entity từ data/models/ (mục 4 kiến trúc).',
      for (final t in conChoDomain)
        if (!thay.contains(t)) '$t: đã sạch — rút khỏi conChoDomain.',
    ];
    expect(loi, isEmpty, reason: loi.join('\n'));
  });

  test(
      'luật 3: features/*/data/ và features/*/application/ không khai <dynamic> trần (Stream/Future/List/Iterable), trừ danh sách chờ (chỉ được giảm)',
      () {
    final thay = <String>{};
    var soTep = 0;
    for (final f in _dart(Directory('lib/features'))) {
      final duong = _duong(f);
      if (!duong.contains('/data/') && !duong.contains('/application/')) continue;
      soTep++;
      if (f.readAsLinesSync().map(boChuThich).any(mauDynamic.hasMatch)) {
        thay.add(duong);
      }
    }
    // Đo 2026-10-15: 105 tệp .dart dưới lib/features/*/data/ (application/ chưa có — thêm ở Task 6–7 đợt Thông báo) — sàn 50.
    expect(soTep, greaterThan(50),
        reason:
            'Phép quét phải thấy features/*/data — bộ lọc luật 3 hỏng thì đỏ ở đây, không xanh im lặng (danh sách chờ đã rỗng từ 2026-10-15).');
    final loi = <String>[
      for (final t in thay)
        if (!conChoDynamic.contains(t))
          '$t: <dynamic> trần ở tầng data / application — khai kiểu rõ (Entity), vì dynamic là cách hàng Drift lọt qua luật 1 (spec Entity Danh mục mục 9).',
      for (final t in conChoDynamic)
        if (!thay.contains(t)) '$t: đã sạch — rút khỏi conChoDynamic.',
    ];
    expect(loi, isEmpty, reason: loi.join('\n'));
  });

  test(
      'luật 4: interface repository (data/repositories/*_repository.dart) không import core/database hay package:drift',
      () {
    final loi = <String>[];
    var soTep = 0;
    for (final f in _dart(Directory('lib/features'))) {
      final duong = _duong(f);
      if (!duong.contains('/data/repositories/') || !duong.endsWith('_repository.dart')) continue;
      soTep++;
      if (f.readAsLinesSync().any(importCam)) {
        loi.add(
            '$duong: interface repository import core/database / package:drift — lối chuyển tiếp trả hàng Drift không nêu tên kiểu lọt qua luật 1; interface chỉ nhận / trả Entity và Dart thuần (spec Entity Thông báo 2026-10-15 mục 9).');
      }
    }
    // Đo 2026-10-15: 10 interface (analytics 2 · auth · bill · budget · category · goal · goi · transaction · wallet), 11 sau đợt Thông báo.
    expect(soTep, greaterThanOrEqualTo(10),
        reason: 'Phép quét phải thấy các interface repository — bộ lọc hỏng thì đỏ ở đây, không xanh im lặng.');
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
