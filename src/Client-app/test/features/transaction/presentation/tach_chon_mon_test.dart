/// A5 mục 11.2b — form mở từ ảnh quét loại HOÁ ĐƠN: sheet *Thêm phần* cho tick từng món (Stitch `98133eb8…`); tiền
/// của phần = Σ món đã tick; món đã thuộc phần khác mờ, không tick được; phần chính nhận phần còn lại.
///
/// ⚠️ Tick món **tạm TẮT** từ 2026-10-08 (`kChonMonTuAnhQuet = false`, đo 6 hoá đơn thật): các ca ở đây bật nó qua
/// `choTickMon: true` để giữ đường mã sống cho A5b; ca cuối canh rằng MẶC ĐỊNH không hiện danh sách món.
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

import '../../category/presentation/category_test_fakes.dart';

class _KhoGia implements KhoAnhQuet {
  _KhoGia(this.mon);
  final List<MonHang> mon;
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
  Future<void> xoa(String? tep) async {}
  @override
  Future<void> xoaHet() async {}
}

const _mon = [
  MonHang(id: 0, ten: 'SUA TUOI VNM 180ML', soTien: 32000),
  MonHang(id: 1, ten: 'BANH MI SANDWICH', soTien: 18000),
  MonHang(id: 2, ten: 'NUOC GIAT OMO 3KG', soTien: 120000),
  MonHang(id: 3, ten: 'GIAY VS PULPPY 10C', soTien: 45000),
  MonHang(id: 4, ten: 'TRUNG GA 10Q', soTien: 40000),
  MonHang(id: 5, ten: 'GIAM GIA KM', soTien: -10000),
];

void main() {
  final anUong = makeCategory(id: 'an', name: 'Ăn uống', isDefault: true);
  final giaDinh = makeCategory(id: 'gd', name: 'Gia đình', isDefault: true);
  final muaSam = makeCategory(id: 'ms', name: 'Mua sắm', isDefault: true);

  late FakeTransactionRepository repo;
  setUp(() => repo = FakeTransactionRepository());

  DienSanBienDong quet() => dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(
        KetQuaAnhQuet(
          loai: LoaiAnhQuet.hoaDon,
          soTien: 245000,
          chieu: 'chi',
          thoiGian: DateTime(2026, 10, 7, 18, 42),
          ghiChu: 'PHO 24',
          mon: const [],
          oThieu: const {},
        ),
        anh: 'a1b2c3d4.jpg',
      )).queryParameters)!;

  Future<void> mo(WidgetTester tester,
      {DienSanBienDong? bienDong, List<MonHang> mon = _mon, bool choTickMon = true}) async {
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
                  trees: {'chi': cay([anUong, giaDinh, muaSam]), 'thu': cay(const []), 'vay_no': cay(const [])},
                  selectable: [anUong, giaDinh, muaSam],
                  keywords: const {
                    'an': ['pho'],
                  },
                ),
                wallets: [makeWallet()],
                idaccount: 1,
                huongBanDau: bienDong == null ? 'chi' : null,
                budgetLookup: (_, __) async => null,
                bienDong: bienDong,
                khoAnhQuet: _KhoGia(mon),
                choTickMon: choTickMon,
                xoaBienDong: (_, __) async {},
                khoanTrongSo: (_) async => const [],
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> moSheet(WidgetTester tester) async {
    final nut = find.byKey(const Key('dong-tach')).evaluate().isNotEmpty
        ? find.byKey(const Key('dong-tach'))
        : find.byKey(const Key('tach-them-phan'));
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester, int id) async {
    await tester.ensureVisible(find.byKey(Key('mon-$id')));
    await tester.tap(find.byKey(Key('mon-$id')));
    await tester.pump();
  }

  Future<void> xong(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('phan-xong')));
    await tester.tap(find.byKey(const Key('phan-xong')));
    await tester.pumpAndSettle();
  }

  String chu(WidgetTester tester, Key k) => tester.widget<Text>(find.byKey(k)).data!;

  testWidgets('⭐ tick OMO + GIẤY → "Đã chọn 2 món · 165.000 đ"; phần Gia đình "2 món", còn lại 80.000 đ',
      (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    expect(find.text('CHỌN MÓN TỪ HOÁ ĐƠN'), findsOneWidget);
    expect(find.byKey(const Key('phan-so-tien')), findsNothing, reason: 'có món → mặc định tick món');
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 2);
    await tick(tester, 3);
    expect(chu(tester, const Key('phan-da-chon')), 'Đã chọn 2 món · 165.000 đ');
    await xong(tester);
    expect(find.text('2 món'), findsOneWidget);
    expect(chu(tester, const Key('tach-con-lai')), '80.000 đ');
  });

  testWidgets('phần thứ hai: món của phần khác MỜ kèm tên danh mục, chạm không tick', (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 2);
    await xong(tester);
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-ms')));
    expect(find.descendant(of: find.byType(Opacity), matching: find.byKey(const Key('mon-2'))), findsOneWidget);
    expect(find.text('Gia đình'), findsWidgets);
    await tick(tester, 2);
    expect(chu(tester, const Key('phan-da-chon')), 'Đã chọn 0 món · 0 đ');
  });

  testWidgets('mở lại phần → các món vẫn tick, sửa được', (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 2);
    await tick(tester, 3);
    await xong(tester);
    await tester.ensureVisible(find.byKey(const Key('tach-phan-gd')));
    await tester.tap(find.byKey(const Key('tach-phan-gd')));
    await tester.pumpAndSettle();
    expect(chu(tester, const Key('phan-da-chon')), 'Đã chọn 2 món · 165.000 đ');
    await tick(tester, 3);
    await xong(tester);
    expect(find.text('1 món'), findsOneWidget);
    expect(chu(tester, const Key('tach-con-lai')), '125.000 đ');
  });

  testWidgets('"Nhập số tiền thủ công" → ô số, bỏ tick; phần không mang món', (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 2);
    await tester.ensureVisible(find.byKey(const Key('phan-nhap-so')));
    await tester.tap(find.byKey(const Key('phan-nhap-so')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('phan-so-tien')), '50000');
    await tester.pump();
    await xong(tester);
    expect(find.text('1 món'), findsNothing);
    expect(chu(tester, const Key('tach-con-lai')), '195.000 đ');
  });

  testWidgets('chỉ tick món âm → Xong tắt', (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 5);
    expect(tester.widget<FilledButton>(find.byKey(const Key('phan-xong'))).onPressed, isNull);
  });

  testWidgets('form gõ tay (không ảnh) → sheet đi thẳng ô số, không danh sách món', (tester) async {
    await mo(tester);
    await moSheet(tester);
    expect(find.text('CHỌN MÓN TỪ HOÁ ĐƠN'), findsNothing);
    expect(find.byKey(const Key('phan-so-tien')), findsOneWidget);
  });

  testWidgets('⭐ MẶC ĐỊNH (tick món tạm tắt) → form ảnh quét có món vẫn chỉ nhập số', (tester) async {
    await mo(tester, bienDong: quet(), choTickMon: false);
    await moSheet(tester);
    expect(find.text('CHỌN MÓN TỪ HOÁ ĐƠN'), findsNothing);
    expect(find.byKey(const Key('phan-so-tien')), findsOneWidget);
  });

  testWidgets('⭐ Lưu → phần chính = 245.000 − 165.000; hai giao dịch', (tester) async {
    await mo(tester, bienDong: quet());
    await moSheet(tester);
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tick(tester, 2);
    await tick(tester, 3);
    await xong(tester);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect([for (final a in repo.added) (a.transaction.categoryId, a.transaction.amount)],
        [('an', 80000.0), ('gd', 165000.0)]);
  });
}
