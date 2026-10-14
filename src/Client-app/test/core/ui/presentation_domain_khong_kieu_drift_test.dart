/// Test quét `lib/` thứ **27** (spec Entity Hoá đơn 2026-10-14, mục 8): giao diện và domain không cầm kiểu hàng Drift.
///
/// Hai luật. (1) `presentation/` + `shared/` không nhắc tên kiểu hàng Drift — [kieuDrift] và companion tương ứng — so
/// trên dòng đã bỏ chú thích, vì docstring vùng này hay nhắc *"đối tượng `Bill`"*. (2) `features/*/domain/` không import
/// `core/database` (mục 4 `KIEN_TRUC_CLIENT_APP.md`: domain là Dart thuần). Tệp còn vi phạm nằm trong danh sách chờ
/// chỉ-được-giảm ([conChoKieu] theo kiểu, [conChoDomain]); sạch mà quên rút thì đỏ (khuôn quét 22 / 25). Kiểu KHÔNG có
/// khoá trong [conChoKieu] là kiểu đã thống nhất Entity — không chỗ chờ, nhắc tới là đỏ ngay.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kiểu hàng Drift mà giao diện từng cầm. Thêm bảng mới có hàng lên giao diện thì thêm ở đây.
const kieuDrift = [
  'Bill',
  'Wallet',
  'Category',
  'Transaction',
  'Goal',
  'Budget',
  'AppNotification'
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
};

/// Luật 1 — kiểu → tệp (tương đối `lib/`) còn cầm kiểu ấy. Điền từ lượt chạy đầu (Step 2); mỗi đợt Entity xoá một khoá.
const conChoKieu = <String, Set<String>>{
  'Wallet': {
    'features/bill/presentation/pages/bill_add_page.dart',
    'features/bill/presentation/pages/bill_edit_page.dart',
    'features/bill/presentation/widgets/bill_actions.dart',
    'features/bill/presentation/widgets/bill_payment_sheet.dart',
    'features/goal/presentation/pages/goal_detail_page.dart',
    'features/goal/presentation/widgets/chi_tiet_muc_tieu/phieu_nap_tien.dart',
    'features/goal/presentation/widgets/chi_tiet_muc_tieu/phieu_rut_tien.dart',
    'features/home/presentation/pages/home_page.dart',
    'features/transaction/presentation/bloc/them_giao_dich_cubit.dart',
    'features/transaction/presentation/bloc/them_giao_dich_state.dart',
    'features/transaction/presentation/pages/add_transaction_page.dart',
    'features/transaction/presentation/pages/transaction_page.dart',
    'features/transaction/presentation/widgets/them_giao_dich/bang_chon_vi.dart',
    'features/transaction/presentation/widgets/transaction_filter_bar.dart',
  },
  'Category': {
    'features/bill/presentation/pages/bill_add_page.dart',
    'features/bill/presentation/pages/bill_detail_page.dart',
    'features/bill/presentation/pages/bill_edit_page.dart',
    'features/bill/presentation/widgets/the_khoan_lap.dart',
    'features/budget/presentation/bloc/budget_state.dart',
    'features/budget/presentation/pages/budget_form.dart',
    'features/category/presentation/pages/category_add_page.dart',
    'features/category/presentation/pages/category_group_page.dart',
    'features/category/presentation/pages/category_page.dart',
    'features/category/presentation/pages/gan_danh_muc_page.dart',
    'features/category/presentation/widgets/chon_danh_muc_gan_sheet.dart',
    'features/home/presentation/pages/home_page.dart',
    'features/transaction/presentation/bloc/them_giao_dich_cubit.dart',
    'features/transaction/presentation/bloc/them_giao_dich_state.dart',
    'features/transaction/presentation/pages/add_transaction_page.dart',
    'features/transaction/presentation/pages/choose_category_page.dart',
    'features/transaction/presentation/pages/transaction_page.dart',
    'features/transaction/presentation/widgets/khoi_tach.dart',
    'features/transaction/presentation/widgets/sheet_them_phan.dart',
    'features/transaction/presentation/widgets/transaction_filter_bar.dart',
  },
  'Transaction': {
    'features/home/presentation/pages/home_page.dart',
  },
  'AppNotification': {
    'features/notification/presentation/pages/notification_center_page.dart',
    'features/notification/presentation/widgets/notification_panel.dart',
  },
};

/// Luật 2 — tệp `domain/` (tương đối `lib/`) còn import `core/database`. Điền từ lượt chạy đầu; Task 4–6 rút Hoá đơn.
const conChoDomain = <String>{
  'features/ai_edge/domain/ap_dung_ke_hoach.dart',
  'features/ai_edge/domain/hang_danh_muc.dart',
  'features/analytics/domain/du_bao_dong_tien.dart',
  'features/bill/domain/de_xuat_hoa_don.dart',
  'features/category/domain/ban_sao_mac_dinh.dart',
  'features/category/domain/gan_hang_loat.dart',
  'features/goal/domain/goal_auto_deposit_runner.dart',
  'features/home/domain/thu_chi_thang.dart',
  'features/transaction/domain/dien_san_bien_dong.dart',
  'features/transaction/domain/doc_cau_giao_dich.dart',
  'features/transaction/domain/khoan_lap.dart',
  'features/transaction/domain/transaction_lookup.dart',
};

/// Bỏ chú thích: dòng `//` / `///`, và đuôi ` // …` sau mã.
String boChuThich(String d) {
  if (d.trimLeft().startsWith('//')) return '';
  final i = d.indexOf(RegExp(r'\s//'));
  return i < 0 ? d : d.substring(0, i);
}

/// `Bill?` · `List<Bill>` · `Bill bill` · `, Bill)` — nhưng KHÔNG `BillBloc`, `BillEntity`, `BillRepository`.
RegExp mauKieu(String ten) =>
    RegExp('\\b$ten(\\?|>| [a-z_][A-Za-z0-9_]*\\b|,|\\))');

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
    expect(m.hasMatch('class BillBloc extends Bloc<BillEvent, BillState> {'),
        isFalse);
    expect(m.hasMatch('final BillEntity bill;'), isFalse);
    expect(
        mauCompanion('BillsCompanion')
            .hasMatch('return BillsCompanion.insert('),
        isTrue);
    expect(boChuThich('  /// đối tượng `Bill` đang giữ'), '');
    expect(boChuThich('  final Bill bill; // ảnh chụp Bill'),
        '  final Bill bill;');
  });

  test(
      'luật 1: presentation/ và shared/ không nhắc kiểu hàng Drift, trừ danh sách chờ theo kiểu (chỉ được giảm)',
      () {
    final thay = <String, Set<String>>{};
    var soTep = 0;
    for (final goc in [Directory('lib/features'), Directory('lib/shared')]) {
      for (final f in _dart(goc)) {
        final duong = _duong(f);
        if (duong.startsWith('features/') &&
            !duong.contains('/presentation/')) {
          continue;
        }
        soTep++;
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
    expect(soTep, greaterThan(100),
        reason:
            'Phép quét phải thấy tệp presentation — đang quét sai thư mục.');

    final loi = <String>[];
    for (final k in kieuDrift) {
      final co = thay[k] ?? const <String>{};
      final cho = conChoKieu[k];
      for (final t in co) {
        if (cho == null) {
          loi.add(
              '$k: $t — kiểu này đã thống nhất Entity, giao diện không được cầm hàng Drift (spec Entity mục 8).');
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
      'luật 2: features/*/domain/ không import core/database, trừ danh sách chờ (chỉ được giảm)',
      () {
    final thay = <String>{};
    for (final f in _dart(Directory('lib/features'))) {
      final duong = _duong(f);
      if (!duong.contains('/domain/')) continue;
      if (f
          .readAsLinesSync()
          .any((d) => d.startsWith('import ') && d.contains('core/database'))) {
        thay.add(duong);
      }
    }
    final loi = <String>[
      for (final t in thay)
        if (!conChoDomain.contains(t))
          '$t: domain import core/database — nhận Entity từ data/models/ (mục 4 kiến trúc).',
      for (final t in conChoDomain)
        if (!thay.contains(t)) '$t: đã sạch — rút khỏi conChoDomain.',
    ];
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
