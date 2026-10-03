/// Chia sẻ biên lai — màn Thêm giao dịch mở từ một hàng biến động MANG ẢNH biên lai (spec
/// `2026-10-02-chia-se-bien-lai-design.md` mục 3, 7, 8).
///
/// Ba điều đáng canh, cả ba hỏng im lặng:
/// 1. **Ảnh bị xoá khi Lưu / Bỏ qua** — người dùng chốt ảnh chỉ sống tới lúc ấy; sót là ảnh mang số tài khoản nằm
///    lại trên máy.
/// 2. **Câu trên dải nguồn nói đúng nguồn của SỐ LIỆU**: đọc từ ảnh thì *"Từ biên lai…"* (kèm *"hãy kiểm lại"* khi đọc
///    bằng luật chung); hàng tin ngân hàng chỉ được gắn ảnh thì vẫn *"Từ thông báo…"*.
/// 3. **Tệp ảnh đã mất thì form vẫn mở** — ảnh là thứ để đối chiếu, không phải điều kiện ghi.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/kho_bien_lai.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/core/notification/ten_tep_bien_lai.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

/// PNG 1 × 1 trong suốt.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');
  final mb = makeWallet(id: 'mb', name: 'MB').copyWith(type: 'bank', isDefault: false);

  final tin = TinBienDong(
    soTien: 150000,
    chieu: 'chi',
    thoiGian: DateTime(2026, 10, 2, 18, 45),
    noiDung: 'PHO 24',
    nguon: kNguonMb,
  );
  final khoa = dedupeKeyBienDong(tin);

  late Directory dir;
  late KhoBienLai kho;
  late FakeTransactionRepository repo;
  late List<String> daXoaHang;

  File tepAnh(String ten) => File('${dir.path}/$kThuMucBienLai/$ten');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('form_bien_lai');
    kho = KhoBienLai(thuMuc: () async => dir);
    tepAnh('aaaa.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_png);
    repo = FakeTransactionRepository();
    daXoaHang = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  DienSanBienDong tuLink(String link) => dienSanBienDongTuQuery(Uri.parse(link).queryParameters)!;

  /// Hàng SINH RA từ biên lai, đọc bằng [cachDoc].
  DienSanBienDong bienLai({String cachDoc = 'chung'}) =>
      tuLink(deeplinkBienDong(tin, dedupeKey: khoa, anh: 'aaaa.png', cachDoc: cachDoc));

  Widget app(DienSanBienDong d, {ThemeData? theme, InMemoryViTheoNguonStore? store}) {
    final bloc = TransactionBloc(transactionRepository: repo);
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    final router = GoRouter(
      initialLocation: '/start/add',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, __) => const Scaffold(body: Text('Trang trước')),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, __) => AddTransactionPage(
                transactionBloc: bloc,
                categoryRepository: FakeCategoryRepository(
                  trees: {'chi': cay([anUong]), 'thu': cay([luong]), 'vay_no': cay(const [])},
                  selectable: [anUong, luong],
                  keywords: const {
                    'food': ['pho'],
                  },
                ),
                wallets: [tienMat, mb],
                idaccount: 1,
                budgetLookup: (_, __) async => null,
                bienDong: d,
                viTheoNguon: store ?? InMemoryViTheoNguonStore(),
                xoaBienDong: (id, k) async => daXoaHang.add(k),
                khoanTrongSo: (_) async => const [],
                hangBienDongCho: (_) async => const [],
                khoBienLai: kho,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(theme: theme, routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, DienSanBienDong d,
      {ThemeData? theme, Size? khung, InMemoryViTheoNguonStore? store}) async {
    if (khung != null) {
      tester.view.physicalSize = khung;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(app(d, theme: theme, store: store));
    await tester.pumpAndSettle();
  }

  final anhNho = find.byKey(const Key('bien-lai-anh-nho'));

  testWidgets('⭐ form từ biên lai (360 × 800, theme thật): số liệu điền sẵn, dải nguồn có ảnh + "hãy kiểm lại", không tràn',
      (tester) async {
    await mo(tester, bienLai(), theme: AppTheme.lightTheme, khung: const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('150.000 đ'), findsOneWidget);
    expect(find.text('Từ biên lai MB Bank · 02/10 18:45'), findsOneWidget);
    expect(find.text('Đọc từ ảnh — hãy kiểm lại'), findsOneWidget);
    final khungAnh = tester.getRect(anhNho);
    expect(khungAnh.size, const Size(48, 64));
    expect(khungAnh.top, greaterThanOrEqualTo(0));
    expect(khungAnh.bottom, lessThanOrEqualTo(800), reason: 'đo VỊ TRÍ: find thấy cả widget ngoài khung nhìn');
    expect(repo.added, isEmpty, reason: 'KHÔNG tự lưu — người dùng bấm ✓');
  });

  testWidgets('360 × 640 (màn thấp), theme thật: không tràn', (tester) async {
    await mo(tester, bienLai(), theme: AppTheme.lightTheme, khung: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(anhNho, findsOneWidget);
  });

  testWidgets('đọc bằng MẪU RIÊNG đã đo → "Từ biên lai…" nhưng KHÔNG có dòng nhắc kiểm lại', (tester) async {
    await mo(tester, bienLai(cachDoc: 'mau'));
    expect(find.text('Từ biên lai MB Bank · 02/10 18:45'), findsOneWidget);
    expect(find.byKey(const Key('bien-lai-dong-phu')), findsNothing);
  });

  testWidgets('⭐ biên lai CHƯA ĐỌC ĐƯỢC: số tiền 0, 16 phím số HIỆN sẵn, dòng "nhìn ảnh để nhập", vẫn có ảnh',
      (tester) async {
    final d = tuLink(deeplinkBienLaiChuaDoc(
        nguon: kNguonBienLai,
        luc: DateTime(2026, 10, 2, 18, 45),
        noiDung: '',
        anh: 'aaaa.png',
        dedupeKey: 'bienDong:bienLai|aaaa.png'));
    await mo(tester, d, theme: AppTheme.lightTheme, khung: const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.byKey(const Key('ban-phim-so')), findsOneWidget,
        reason: 'chưa có số tiền thì người dùng phải gõ — ẩn 16 phím là bắt họ chạm thêm một lần');
    expect(find.text('Từ biên lai · 02/10 18:45'), findsOneWidget);
    expect(find.text('Chưa đọc được số tiền — nhìn ảnh để nhập'), findsOneWidget);
    expect(anhNho, findsOneWidget);
  });

  testWidgets('⭐ hàng TIN ngân hàng được gắn ảnh (anh, không doc): vẫn "Từ thông báo…", có ảnh, không dòng nhắc',
      (tester) async {
    final link = themAnhVaoDeeplink(deeplinkBienDong(tin, dedupeKey: khoa), 'aaaa.png', DateTime(2026, 10, 2, 18, 45));
    await mo(tester, tuLink(link));
    expect(find.text('Từ thông báo MB Bank · 02/10 18:45'), findsOneWidget);
    expect(anhNho, findsOneWidget);
    expect(find.byKey(const Key('bien-lai-dong-phu')), findsNothing);
  });

  testWidgets('hàng tin ngân hàng thường (không ảnh) không đổi: không ảnh nhỏ', (tester) async {
    await mo(tester, tuLink(deeplinkBienDong(tin, dedupeKey: khoa)));
    expect(find.text('Từ thông báo MB Bank · 02/10 18:45'), findsOneWidget);
    expect(anhNho, findsNothing);
  });

  testWidgets('chạm ảnh nhỏ → xem ảnh to; nút Đóng có tooltip; đóng thì về form', (tester) async {
    await mo(tester, bienLai());
    await tester.tap(anhNho);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bien-lai-anh-to')), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bien-lai-anh-to')), findsNothing);
    expect(find.text('Từ biên lai MB Bank · 02/10 18:45'), findsOneWidget);
  });

  testWidgets('⭐ nút ✕ đọc được cả trên biên lai NỀN SÁNG: tương phản ✕ trắng / nền nút (đặt lên ảnh trắng) ≥ 3:1',
      (tester) async {
    // Nghiệm thu Realme 2026-10-03: ✕ trắng không nền gần như chìm khi ảnh xám nhạt (biên lai MB nền xanh đậm thì
    // rõ — nên lượt đo đầu không thấy). Nút nằm ĐÈ góc trên của ảnh, nên trường hợp tệ nhất là ảnh trắng sau nút.
    await mo(tester, bienLai());
    await tester.tap(anhNho);
    await tester.pumpAndSettle();
    final nut = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip('Đóng'), matching: find.byType(IconButton)));
    final nen = nut.style?.backgroundColor?.resolve(<WidgetState>{}) ?? Colors.transparent;
    final tren = Color.alphaBlend(nen, Colors.white);
    final tuongPhan = (Colors.white.computeLuminance() + 0.05) / (tren.computeLuminance() + 0.05);
    expect(tuongPhan, greaterThanOrEqualTo(3.0),
        reason: 'WCAG 1.4.11 (thành phần không phải chữ) đòi 3:1; ✕ không nền trên ảnh trắng là 1:1 — vô hình');
  });

  testWidgets('⭐ Bỏ qua → hàng bị xoá VÀ tệp ảnh bị xoá, không tạo giao dịch', (tester) async {
    await mo(tester, bienLai());
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(daXoaHang, [khoa]);
    expect(tepAnh('aaaa.png').existsSync(), isFalse,
        reason: 'người dùng chốt: ảnh chỉ sống tới lúc Lưu / Bỏ qua — sót là ảnh mang số tài khoản nằm lại máy');
    expect(repo.added, isEmpty);
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('⭐ Lưu → giao dịch đúng số tiền / giờ trên biên lai, hàng bị xoá VÀ tệp ảnh bị xoá', (tester) async {
    final store = InMemoryViTheoNguonStore();
    await store.ghi(1, kNguonMb, null, 'mb');
    await mo(tester, bienLai(), store: store);
    expect(find.text('Ăn uống'), findsOneWidget, reason: 'danh mục đoán trên nội dung biên lai, cùng luật với tin ngân hàng');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(repo.added.single.transaction.amount, 150000);
    expect(repo.added.single.transaction.walletId, 'mb', reason: 'ví nhớ theo nguồn dùng chung với D1');
    expect(repo.added.single.transaction.date, DateTime(2026, 10, 2, 18, 45));
    expect(daXoaHang, [khoa]);
    expect(tepAnh('aaaa.png').existsSync(), isFalse);
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('tệp ảnh đã mất → form vẫn mở và điền sẵn, không ảnh nhỏ, không ném', (tester) async {
    tepAnh('aaaa.png').deleteSync();
    await mo(tester, bienLai());
    expect(tester.takeException(), isNull);
    expect(find.text('150.000 đ'), findsOneWidget);
    expect(anhNho, findsNothing);
    expect(find.text('Từ biên lai MB Bank · 02/10 18:45'), findsOneWidget);
  });
}
