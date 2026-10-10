/// A5 mục 11 — tách một khoản chi theo danh mục trên form Thêm giao dịch: phần chính nhận phần còn lại, Lưu ghi N
/// giao dịch trong một lượt (một toast, đóng một lần), ngân sách xét TỪNG phần.
library;

import 'dart:io';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/ocr/kho_anh_quet.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';
import '../../category/presentation/category_test_fakes.dart';

class _KhoGia implements KhoAnhQuet {
  final List<String?> daXoa = [];
  @override
  Future<Directory> Function() get thuMuc => throw UnimplementedError();
  @override
  Future<String?> luu(String duongDanNguon) async => null;
  @override
  Future<String?> duongDan(String tep) async => null;
  @override
  Future<void> luuMon(String tep, List<MonHang> mon) async {}
  @override
  Future<List<MonHang>> docMon(String tep) async => const [];
  @override
  Future<void> xoa(String? tep) async => daXoa.add(tep);
  @override
  Future<void> xoaHet() async {}
}

void main() {
  final anUong = makeCategory(id: 'an', name: 'Ăn uống', isDefault: true);
  final giaDinh = makeCategory(id: 'gd', name: 'Gia đình', isDefault: true);
  final muaSam = makeCategory(id: 'ms', name: 'Mua sắm', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);

  late FakeTransactionRepository repo;
  setUp(() => repo = FakeTransactionRepository());

  BudgetView nganSach(String dm, String ten, {required String overSpending}) {
    final now = DateTime.now();
    return BudgetView(
      budget: BudgetEntity(
        id: 'b$dm',
        idaccount: 1,
        categoryId: dm,
        amount: 10000,
        spent: 9000,
        overSpending: overSpending,
        startDate: DateTime(now.year, now.month, 1),
        recurrence: true,
        updatedAt: now,
      ),
      categoryName: ten,
    );
  }

  Widget app({
    String huong = 'chi',
    Map<String, BudgetView> nganSachTheoDm = const {},
    DienSanBienDong? bienDong,
    KhoAnhQuet? kho,
    List<(int, String)>? daXoaHang,
  }) {
    final bloc = TransactionBloc(transactionRepository: repo);
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    final cats = FakeCategoryRepository(
      trees: {'chi': cay([anUong, giaDinh, muaSam]), 'thu': cay([luong]), 'vay_no': cay(const [])},
      selectable: [anUong, giaDinh, muaSam, luong],
      keywords: const {
        'an': ['pho'],
      },
    );
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
                categoryRepository: cats,
                wallets: [makeWallet()],
                idaccount: 1,
                huongBanDau: bienDong == null ? huong : null,
                budgetLookup: (_, dm) async => nganSachTheoDm[dm],
                bienDong: bienDong,
                khoAnhQuet: kho,
                xoaBienDong: (id, k) async => daXoaHang?.add((id, k)),
                khoanTrongSo: (_) async => const [],
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: cats,
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, {String huong = 'chi', Map<String, BudgetView> ns = const {}}) async {
    await tester.pumpWidget(app(huong: huong, nganSachTheoDm: ns));
    await tester.pumpAndSettle();
  }

  Future<void> chonDanhMuc(WidgetTester tester, String ten) async {
    // Nhãn đổi thành 'Danh mục chính' khi đã tách.
    final hang = find.textContaining('Danh mục').first;
    await tester.ensureVisible(hang);
    await tester.tap(hang);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khoản chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ten));
    await tester.pumpAndSettle();
  }

  Future<void> goTong(WidgetTester tester) async {
    for (final k in ['4', '1', '2', '000']) {
      await tester.ensureVisible(find.text(k).last);
      await tester.tap(find.text(k).last);
    }
    await tester.pump();
  }

  Future<void> themPhan(WidgetTester tester, String dm, String soTien) async {
    final nut = find.byKey(const Key('dong-tach')).evaluate().isNotEmpty
        ? find.byKey(const Key('dong-tach'))
        : find.byKey(const Key('tach-them-phan'));
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('phan-danh-muc-$dm')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('phan-so-tien')), soTien);
    await tester.pump();
    await tester.tap(find.byKey(const Key('phan-xong')));
    await tester.pumpAndSettle();
  }

  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  testWidgets('dòng "Tách theo danh mục" chỉ khi tạo mới khoản CHI — không Thu, không Chuyển', (tester) async {
    await mo(tester);
    expect(find.byKey(const Key('dong-tach')), findsOneWidget);
    await mo(tester, huong: 'thu');
    expect(find.byKey(const Key('dong-tach')), findsNothing);
    await mo(tester, huong: 'transfer');
    expect(find.byKey(const Key('dong-tach')), findsNothing);
  });

  testWidgets('⭐ thêm phần: sheet chỉ danh mục CHI khác danh mục chính; khối hiện, còn lại tự tính', (tester) async {
    await mo(tester);
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await tester.ensureVisible(find.byKey(const Key('dong-tach')));
    await tester.tap(find.byKey(const Key('dong-tach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phan-danh-muc-gd')), findsOneWidget);
    expect(find.byKey(const Key('phan-danh-muc-ms')), findsOneWidget);
    expect(find.byKey(const Key('phan-danh-muc-an')), findsNothing, reason: 'danh mục chính không tách khỏi chính nó');
    expect(find.byKey(const Key('phan-danh-muc-luong')), findsNothing, reason: 'danh mục thu không cho khoản chi');
    await tester.tap(find.byKey(const Key('phan-danh-muc-gd')));
    await tester.enterText(find.byKey(const Key('phan-so-tien')), '120000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phan-xong')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('khoi-tach')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('tach-con-lai'))).data, '292.000 đ');
    expect(find.byKey(const Key('dong-tach')), findsNothing, reason: 'có phần rồi thì thêm qua "+ Thêm phần" của khối');
    expect(find.text('Danh mục chính'), findsOneWidget);
  });

  testWidgets('còn lại ≤ 0 → không lưu, toast lỗi', (tester) async {
    final bat = batThongBao();
    await mo(tester);
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '412000');
    await luu(tester);
    expect(repo.added, isEmpty);
    expect(bat.cau, contains('Phần còn lại phải lớn hơn 0'));
  });

  testWidgets('đổi danh mục chính sang danh mục đang tách → phần ấy gộp vào chính', (tester) async {
    await mo(tester);
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '120000');
    await chonDanhMuc(tester, 'Gia đình');
    expect(find.byKey(const Key('tach-phan-gd')), findsNothing);
    expect(find.byKey(const Key('khoi-tach')), findsNothing);
  });

  testWidgets('✕ bỏ phần cuối → khối biến mất, form như cũ', (tester) async {
    await mo(tester);
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '120000');
    await tester.ensureVisible(find.byKey(const Key('tach-bo-gd')));
    await tester.tap(find.byKey(const Key('tach-bo-gd')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('khoi-tach')), findsNothing);
    expect(find.byKey(const Key('dong-tach')), findsOneWidget);
  });

  testWidgets('⭐ Lưu 3 phần → MỘT lượt addTransactions, số tiền đúng, MỘT toast, đóng một lần', (tester) async {
    final bat = batThongBao();
    await mo(tester);
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '120000');
    await themPhan(tester, 'ms', '42000');
    expect(tester.widget<Text>(find.byKey(const Key('tach-so-giao-dich'))).data, 'Sẽ lưu 3 giao dịch');
    await luu(tester);
    expect(repo.luotThemNhieu, [3]);
    expect([for (final a in repo.added) (a.transaction.categoryId, a.transaction.amount)],
        [('an', 250000.0), ('gd', 120000.0), ('ms', 42000.0)]);
    expect(bat.cau, ['Đã lưu 3 giao dịch']);
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('ngân sách Chặn bị vượt ở HAI phần → MỘT hộp liệt kê cả hai; Huỷ không lưu, Vẫn ghi lưu cả lô',
      (tester) async {
    await mo(tester, ns: {
      'gd': nganSach('gd', 'Gia đình', overSpending: BudgetOverSpending.stop),
      'ms': nganSach('ms', 'Mua sắm', overSpending: BudgetOverSpending.stop),
    });
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '120000');
    await themPhan(tester, 'ms', '42000');
    await luu(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Gia đình'), findsWidgets);
    expect(find.textContaining('ngân sách Mua sắm vượt'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);
    await luu(tester);
    await tester.tap(find.text('Vẫn ghi'));
    await tester.pumpAndSettle();
    expect(repo.luotThemNhieu, [3]);
  });

  testWidgets('ngân sách Cảnh báo bị vượt → toast "Đã lưu 3 giao dịch. Ngân sách … đã vượt hạn mức."', (tester) async {
    final bat = batThongBao();
    await mo(tester, ns: {'gd': nganSach('gd', 'Gia đình', overSpending: BudgetOverSpending.over)});
    await goTong(tester);
    await chonDanhMuc(tester, 'Ăn uống');
    await themPhan(tester, 'gd', '120000');
    await themPhan(tester, 'ms', '42000');
    await luu(tester);
    expect(bat.cau.single, startsWith('Đã lưu 3 giao dịch. Ngân sách'));
  });

  testWidgets('form từ ảnh quét có tách → xoá ảnh, KHÔNG gọi xoaBienDong', (tester) async {
    final kho = _KhoGia();
    final daXoaHang = <(int, String)>[];
    final bienDong = dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(
      KetQuaAnhQuet(
        loai: LoaiAnhQuet.hoaDon,
        soTien: 412000,
        chieu: 'chi',
        thoiGian: DateTime(2026, 10, 7, 18, 42),
        ghiChu: 'PHO 24',
        mon: const [],
        oThieu: const {},
      ),
      anh: 'a1b2c3d4.jpg',
    )).queryParameters)!;
    await tester.pumpWidget(app(bienDong: bienDong, kho: kho, daXoaHang: daXoaHang));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống'), findsOneWidget, reason: 'danh mục đoán từ ghi chú (từ khoá "pho")');
    await themPhan(tester, 'gd', '120000');
    await luu(tester);
    expect(repo.luotThemNhieu, [2]);
    expect(kho.daXoa.toSet(), {'a1b2c3d4.jpg'});
    expect(daXoaHang, isEmpty);
  });
}
