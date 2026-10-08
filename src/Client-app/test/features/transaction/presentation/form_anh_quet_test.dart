/// A5 mục 5.6 — form Thêm giao dịch mở từ ẢNH QUÉT (khoá `quet:`). Khác D1 ở ba chỗ, cả ba hỏng im lặng nếu chép
/// nhầm đường D1:
/// 1. Ảnh quét KHÔNG gắn nguồn ngân hàng → ví mặc định được chọn sẵn (D1 để trống ví ở lần đầu của nguồn).
/// 2. Không có hàng loại 20 → Lưu / Bỏ qua không gọi `xoaBienDong`, chỉ xoá ảnh trong `KhoAnhQuet`.
/// 3. Ảnh xoá ở MỌI đường thoát (Lưu, Bỏ qua, nút ←).
library;

import 'dart:io';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/ocr/kho_anh_quet.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/font_that.dart';
import '../../category/presentation/category_test_fakes.dart';

class KhoAnhQuetGia implements KhoAnhQuet {
  final List<String?> daXoa = [];
  List<MonHang> mon = const [];

  @override
  Future<Directory> Function() get thuMuc => throw UnimplementedError();
  @override
  Future<String?> luu(String duongDanNguon) async => null;
  @override
  Future<String?> duongDan(String tep) async => null;
  @override
  Future<void> luuMon(String tep, List<MonHang> mon) async {}
  @override
  Future<List<MonHang>> docMon(String tep) async => mon;
  @override
  Future<void> xoa(String? tep) async => daXoa.add(tep);
  @override
  Future<void> xoaHet() async {}
}

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt'); // ví MẶC ĐỊNH
  final mb = makeWallet(id: 'mb', name: 'MB').copyWith(type: 'bank', isDefault: false);
  const anh = 'a1b2c3d4.jpg';

  DienSanBienDong dienSan({bool ai = false, List<double> chon = const []}) =>
      dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(
        KetQuaAnhQuet(
          loai: LoaiAnhQuet.hoaDon,
          soTien: chon.isEmpty ? 191862 : null,
          chieu: 'chi',
          thoiGian: DateTime(2026, 9, 28, 18, 42),
          ghiChu: 'PHO 24',
          mon: const [],
          oThieu: const {},
          aiLap: ai,
        ),
        anh: anh,
        luaChonTien: chon,
      )).queryParameters)!;

  late FakeTransactionRepository repo;
  late KhoAnhQuetGia kho;
  late List<(int, String)> daXoaHang;
  late int luotDocSo;

  setUp(() {
    repo = FakeTransactionRepository();
    kho = KhoAnhQuetGia();
    daXoaHang = [];
    luotDocSo = 0;
  });

  Widget app({bool ai = false, List<double> chon = const []}) {
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
                  trees: {'chi': cay([anUong]), 'thu': cay(const []), 'vay_no': cay(const [])},
                  selectable: [anUong],
                  keywords: const {
                    'food': ['pho'],
                  },
                ),
                wallets: [tienMat, mb],
                idaccount: 1,
                budgetLookup: (_, __) async => null,
                bienDong: dienSan(ai: ai, chon: chon),
                khoAnhQuet: kho,
                xoaBienDong: (id, k) async => daXoaHang.add((id, k)),
                khoanTrongSo: (_) async {
                  luotDocSo++;
                  return const [];
                },
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, {bool ai = false, List<double> chon = const []}) async {
    await tester.pumpWidget(app(ai: ai, chon: chon));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ điền tiền, ghi chú, danh mục, dải "Từ ảnh quét"; VÍ MẶC ĐỊNH được chọn sẵn; không nhắc trùng',
      (tester) async {
    await mo(tester);
    expect(find.text('191.862 đ'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Từ ảnh quét · 28/09 18:42'), findsOneWidget);
    expect(find.text('Chọn ví'), findsNothing,
        reason: 'ảnh quét không gắn nguồn ngân hàng — không có bảng nguồn → ví để học, giữ ví mặc định');
    expect(find.textContaining('Tiền mặt'), findsWidgets);
    expect(luotDocSo, 0, reason: 'nhắc trùng của D1 không áp cho ảnh quét (spec 5.6)');
    expect(repo.added, isEmpty, reason: 'KHÔNG tự lưu');
  });

  testWidgets('Lưu → một giao dịch; xoá ẢNH, KHÔNG gọi xoaBienDong; về trang trước', (tester) async {
    await mo(tester);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(repo.added.length, 1);
    expect(repo.added.single.transaction.walletId, 'cash');
    expect(kho.daXoa.toSet(), {anh});
    expect(daXoaHang, isEmpty, reason: 'không có hàng loại 20 nào cho ảnh quét');
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('Bỏ qua → không lưu, xoá ảnh, về trang trước', (tester) async {
    await mo(tester);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);
    expect(kho.daXoa.toSet(), {anh});
    expect(daXoaHang, isEmpty);
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('nút ← → xoá ảnh (dispose — mọi đường thoát)', (tester) async {
    await mo(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Trang trước'), findsOneWidget);
    expect(kho.daXoa.toSet(), {anh});
  });

  testWidgets('ai=1 → dải nói "Đọc bằng AI"', (tester) async {
    await mo(tester, ai: true);
    expect(find.text('Từ ảnh quét · 28/09 18:42 · Đọc bằng AI'), findsOneWidget);
  });

  group('A5 mục 13 — số AI và số luật lệch nhau → ô số tiền trống + hai chip', () {
    testWidgets('⭐ khối "Đọc ra hai số khác nhau" với hai chip theo thứ tự AI trước; ô số tiền TRỐNG', (tester) async {
      await mo(tester, ai: true, chon: const [16588, 79243]);
      expect(find.text('Đọc ra hai số khác nhau — chọn số đúng:'), findsOneWidget);
      final chip = find.byKey(const Key('chon-so-tien-0'));
      expect(find.descendant(of: chip, matching: find.text('16.588 đ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chon-so-tien-1')), matching: find.text('79.243 đ')),
          findsOneWidget);
      expect(find.text('16.588 đ'), findsOneWidget, reason: 'chưa chọn — số chỉ nằm trên chip, ô số tiền trống');
    });

    testWidgets('⭐ chạm chip → điền ô số tiền, chip ấy được chọn; Lưu ghi đúng số chip', (tester) async {
      await mo(tester, ai: true, chon: const [16588, 79243]);
      await tester.tap(find.byKey(const Key('chon-so-tien-1')));
      await tester.pumpAndSettle();
      expect(find.text('79.243 đ'), findsNWidgets(2), reason: 'ô số tiền + chip');
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('chon-so-tien-1'))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('chon-so-tien-0'))).selected, isFalse);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(repo.added.single.transaction.amount, 79243);
    });

    testWidgets('chạm chip kia → đổi số', (tester) async {
      await mo(tester, ai: true, chon: const [16588, 79243]);
      await tester.tap(find.byKey(const Key('chon-so-tien-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chon-so-tien-0')));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('chon-so-tien-0'))).selected, isTrue);
      expect(find.text('16.588 đ'), findsNWidgets(2));
    });

    testWidgets('320 dp, font thật: khối hai chip không tràn', (tester) async {
      await napFontThat();
      tester.view.physicalSize = const Size(960, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await mo(tester, ai: true, chon: const [1234567890, 9876543210]);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chon-so-tien-1')), findsOneWidget);
    });

    testWidgets('không có lựa chọn → không có khối', (tester) async {
      await mo(tester);
      expect(find.text('Đọc ra hai số khác nhau — chọn số đúng:'), findsNothing);
    });
  });
}
