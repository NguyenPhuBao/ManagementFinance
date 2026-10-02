/// Dự án C, việc đầu — thẻ "Gợi ý danh mục" theo SỐ TIỀN ở màn Thêm giao dịch (spec
/// `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`). Phép đoán có bộ test riêng
/// (`category/domain/phan_loai_so_tien_test.dart`); ở đây chỉ kiểm CHỖ NỐI.
///
/// ⚠️ Bộ mẫu chia ĐỀU ngày thường / cuối tuần: màn lấy `DateTime.now()` làm ngày giao dịch, nên bộ mẫu lệch về một nhóm
/// thứ là ca test đổi kết quả theo hôm chạy.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Mười hai mẫu chi, ví cash: Ăn uống 6 khoản 30.000 · Di chuyển 6 khoản 7.000 — mỗi danh mục 3 ngày thường + 3
/// cuối tuần. Ngưỡng của nguồn số tiền: ≥ 5 khoản ở bậc, hậu nghiệm ≥ 0,8 (ở đây ≈ 0,88).
final _muoiMauTien = mauSoTienTu([
  for (final d in [1, 2, 3, 5, 6, 12])
    (
      loai: 'chi',
      categoryId: 'food',
      ghiChu: '',
      soTien: 30000.0,
      walletId: 'cash',
      ngay: DateTime(2026, 9, d),
      daXoa: false,
    ),
  for (final d in [1, 2, 3, 5, 6, 12])
    (
      loai: 'chi',
      categoryId: 'move',
      ghiChu: '',
      soTien: 7000.0,
      walletId: 'cash',
      ngay: DateTime(2026, 9, d),
      daXoa: false,
    ),
]);

/// [_muoiMauTien] + mười khoản THU 9.000.000 cho Lương — để đoạn Thu nhập có thứ mà đoán.
final _coMauThu = [
  ..._muoiMauTien,
  ...mauSoTienTu([
    for (final d in [1, 2, 3, 4, 5, 6, 7, 8, 12, 13])
      (
        loai: 'thu',
        categoryId: 'luong',
        ghiChu: '',
        soTien: 9000000.0,
        walletId: 'cash',
        ngay: DateTime(2026, 9, d),
        daXoa: false,
      ),
  ]),
];

/// Hai ví: Ăn uống 8 khoản 30.000 ví cash · một danh mục KHÔNG chọn được (đã xoá) 6 khoản 30.000 ví bank — mỗi bên
/// chia đều ngày thường / cuối tuần. Ví cash: Ăn uống ≈ 0,91. Ví bank: danh mục đã xoá thắng, Ăn uống chỉ còn ≈ 0,13
/// → thẻ biến mất.
final _haiVi = mauSoTienTu([
  for (final d in [1, 2, 3, 4, 5, 6, 12, 13])
    (
      loai: 'chi',
      categoryId: 'food',
      ghiChu: '',
      soTien: 30000.0,
      walletId: 'cash',
      ngay: DateTime(2026, 9, d),
      daXoa: false,
    ),
  for (final d in [1, 2, 3, 5, 6, 12])
    (
      loai: 'chi',
      categoryId: 'da_xoa',
      ghiChu: '',
      soTien: 30000.0,
      walletId: 'bank',
      ngay: DateTime(2026, 9, d),
      daXoa: false,
    ),
]);

MauGhiChu _m(String c, String ghiChu) =>
    MauGhiChu(categoryId: c, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 9, 1));

/// B1: *"grab"* là Di chuyển 4/4 lần (cùng bộ của `add_transaction_goi_y_hoc_test.dart`).
final _muoiMauChu = [
  _m('move', 'grab đi làm'), _m('move', 'grab về nhà'), _m('move', 'Grab'), _m('move', 'xăng xe'),
  _m('move', 'grab sân bay'),
  _m('food', 'cafe sáng'), _m('food', 'cafe'), _m('food', 'cơm trưa'), _m('food', 'ăn sáng'), _m('food', 'cafe chiều'),
];

const _lyDoAn = 'Khoản từ 20.000 đ đến 50.000 đ bạn thường ghi cho Ăn uống (6/6 lần).';
const _lyDoDi = 'Khoản dưới 10.000 đ bạn thường ghi cho Di chuyển (6/6 lần).';

/// Store trong bộ nhớ: ghi vào [hang], đọc trả [coSan].
class _StoreGia implements GoiYPhanHoiStore {
  _StoreGia([this.coSan = const []]);
  final List<PhanHoiGoiY> coSan;
  final List<({String nguon, String amTietChinh, String goiY, String ketQua, String? chon})> hang = [];

  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) async =>
      hang.add((
        nguon: goiY.nguon,
        amTietChinh: goiY.amTietChinh,
        goiY: goiY.categoryId,
        ketQua: ketQua,
        chon: chonCategoryId,
      ));

  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => coSan;
}

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final diChuyen = makeCategory(id: 'move', name: 'Di chuyển', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);

  CategoryTree treeOf(List<Category> c) =>
      CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);

  FakeCategoryRepository categories({Map<String, List<String>> keywords = const {}}) => FakeCategoryRepository(
        trees: {'chi': treeOf([anUong, diChuyen]), 'thu': treeOf([luong]), 'vay_no': treeOf(const [])},
        selectable: [anUong, diChuyen, luong],
        keywords: keywords,
      );

  Widget app({
    bool coMoHinhSoTien = true,
    List<MauSoTien>? mauSoTien,
    List<Wallet>? wallets,
    BoPhanLoaiGhiChu? boPhanLoai,
    Map<String, List<String>> keywords = const {},
    EditTransactionArgs? initial,
    GoiYPhanHoiStore? phanHoiGoiY,
    DienSanBienDong? bienDong,
    ThemeData? theme,
  }) {
    final bloc = TransactionBloc(transactionRepository: FakeTransactionRepository());
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
                categoryRepository: categories(keywords: keywords),
                wallets: wallets ?? [makeWallet()],
                idaccount: 1,
                boSoTien: coMoHinhSoTien ? BoPhanLoaiSoTien.hoc(mauSoTien ?? _muoiMauTien) : null,
                boPhanLoai: boPhanLoai,
                initial: initial,
                phanHoiGoiY: phanHoiGoiY,
                budgetLookup: (_, __) async => null,
                bienDong: bienDong,
                viTheoNguon: bienDong == null ? null : InMemoryViTheoNguonStore(),
                xoaBienDong: bienDong == null ? null : (_, __) async {},
                khoanTrongSo: bienDong == null ? null : (_) async => const [],
                hangBienDongCho: bienDong == null ? null : (_) async => const [],
              ),
            ),
          ],
        ),
        // Trang thêm `push` CỨNG '/add/category' (như `app_router` thật) — route phải ở cấp gốc.
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categories(keywords: keywords),
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(theme: theme, routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  Future<void> choGoiY(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  /// Gõ từng phím của bàn phím 16 phím rồi chờ hết độ trễ gợi ý.
  Future<void> go(WidgetTester tester, List<String> phim) async {
    final banPhim = find.byKey(const Key('ban-phim-so'));
    for (final p in phim) {
      final nut = find.descendant(of: banPhim, matching: find.text(p));
      await tester.ensureVisible(nut);
      await tester.tap(nut);
      await tester.pump();
    }
    await choGoiY(tester);
  }

  Future<void> goGhiChu(WidgetTester tester, String ghiChu) async {
    await tester.enterText(find.byKey(const Key('ghi-chu-giao-dich')), ghiChu);
    await choGoiY(tester);
  }

  Future<void> chonDoan(WidgetTester tester, String doan) async {
    await tester.ensureVisible(find.byKey(Key('transaction-type-$doan')));
    await tester.tap(find.byKey(Key('transaction-type-$doan')));
    await choGoiY(tester);
  }

  Future<void> chonQuaBang(WidgetTester tester, String ten) async {
    await tester.ensureVisible(find.text('Danh mục'));
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khoản chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ten));
    await tester.pumpAndSettle();
  }

  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  group('thẻ theo số tiền hiện khi ghi chú không giúp được', () {
    testWidgets('⭐ ghi chú TRỐNG + gõ 35.000 → thẻ Ăn uống với câu lý do theo bậc (theme thật)', (tester) async {
      await mo(tester, app(theme: AppTheme.lightTheme));
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: 'số tiền 0 thì chưa có gì để đoán');
      await go(tester, ['3', '5', '000']);
      expect(tester.takeException(), isNull);
      expect(find.text('Gợi ý danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text(_lyDoAn), findsOneWidget);
    });

    testWidgets('gõ 7.000 → thẻ Di chuyển, bậc thấp nhất', (tester) async {
      await mo(tester, app());
      await go(tester, ['7', '000']);
      expect(find.text(_lyDoDi), findsOneWidget);
    });

    testWidgets('không có mô hình số tiền → gõ số tiền không sinh thẻ nào (hành vi trước dự án C)', (tester) async {
      await mo(tester, app(coMoHinhSoTien: false));
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ ghi chú CÓ CHỮ mà B1 và từ khoá đều im → KHÔNG có thẻ số tiền', (tester) async {
      // Người dùng chốt 2026-10-02 sau phép đo CSDL thật: 3/4 lần thẻ sai là khoản có ghi chú (*"ca phe sang"* 10.000
      // → Di chuyển) — thẻ nói ngược chữ vừa gõ. Nguồn số tiền chỉ dành cho ô ghi chú TRỐNG.
      await mo(tester, app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMauChu)));
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await goGhiChu(tester, 'điện thoại');
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ thẻ số tiền đang hiện → gõ chữ đầu tiên vào ghi chú → thẻ biến mất NGAY, không chờ độ trễ',
        (tester) async {
      await mo(tester, app());
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ghi-chu-giao-dich')), 'c');
      await tester.pump();
      expect(find.text('Gợi ý danh mục'), findsNothing,
          reason: 'thẻ còn đứng đó 300 ms nữa là người dùng thấy nó cãi lại chữ họ đang gõ');
      await choGoiY(tester);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('đã có ghi chú rồi mới gõ số tiền → không có thẻ số tiền', (tester) async {
      await mo(tester, app());
      await goGhiChu(tester, 'điện thoại');
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ B1 lên tiếng thì thẻ là của B1, không phải của số tiền', (tester) async {
      await mo(tester, app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMauChu)));
      await go(tester, ['3', '5', '000']);
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Bạn thường ghi “grab” cho Di chuyển (4/4 lần).'), findsOneWidget);
      expect(find.text(_lyDoAn), findsNothing);
    });

    testWidgets('⭐ thẻ B1 đang hiện → đổi đoạn Thu rồi về Chi → thẻ B1 KHÔNG tự bật lại (hành vi trước dự án C)',
        (tester) async {
      // Số tiền / ví / ngày / đoạn không phải tín hiệu của B1: có mô hình số tiền cũng không được hẹn lại `_loadSuggestion`
      // cho một ghi chú có chữ — luật "đổi đoạn → thẻ bị huỷ, không ghi phản hồi" của B1 dựa vào đó.
      await mo(tester, app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMauChu)));
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Bạn thường ghi “grab” cho Di chuyển (4/4 lần).'), findsOneWidget);
      await chonDoan(tester, 'thu');
      await chonDoan(tester, 'chi');
      expect(find.text('Gợi ý danh mục'), findsNothing);
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: 'gõ số tiền cũng không gọi lại B1');
    });

    testWidgets('⭐ từ khoá lên tiếng thì thẻ là của từ khoá', (tester) async {
      await mo(
          tester,
          app(keywords: {
            'move': ['xe'],
          }));
      await go(tester, ['3', '5', '000']);
      await goGhiChu(tester, 'xe');
      expect(find.text('Khớp với “xe” trong ghi chú.'), findsOneWidget);
      expect(find.text(_lyDoAn), findsNothing);
    });

    testWidgets('xoá hết ghi chú → thẻ quay về nguồn số tiền', (tester) async {
      await mo(tester, app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMauChu)));
      await go(tester, ['3', '5', '000']);
      await goGhiChu(tester, 'grab tối');
      expect(find.text(_lyDoAn), findsNothing);
      await goGhiChu(tester, '');
      expect(find.text(_lyDoAn), findsOneWidget);
    });

    testWidgets('⭐ ô Nhập nhanh điền số tiền mà không ra danh mục → thẻ theo số tiền hiện', (tester) async {
      await mo(tester, app());
      await tester.enterText(find.byKey(const Key('nhap-nhanh-o')), '35k');
      await tester.pump();
      await tester.tap(find.byKey(const Key('nhap-nhanh-dien')));
      await choGoiY(tester);
      expect(find.text(_lyDoAn), findsOneWidget);
    });

    testWidgets('⭐ đổi số tiền sang bậc khác → thẻ đổi theo', (tester) async {
      await mo(tester, app());
      await go(tester, ['7', '000']);
      expect(find.text(_lyDoDi), findsOneWidget);
      await go(tester, ['0']); // 70.000 — bậc 50–100k không có mẫu nào
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('phép tính gõ dở (20000+) → chưa tính; đủ hai vế (20000+15000) → tính trên tổng', (tester) async {
      await mo(tester, app());
      await go(tester, ['2', '0', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await go(tester, ['+']);
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: 'toán tử lẻ ở cuối: chưa phải một số tiền');
      await go(tester, ['4', '0', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: '20.000 + 40.000 = 60.000 → bậc 50–100k, không mẫu');
    });
  });

  group('thẻ theo số tiền KHÔNG hiện', () {
    testWidgets('đã chọn danh mục → gõ số tiền không hiện thẻ', (tester) async {
      await mo(tester, app());
      await chonQuaBang(tester, 'Di chuyển');
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('đoạn Chuyển khoản → không', (tester) async {
      await mo(tester, app());
      await chonDoan(tester, 'transfer');
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ đoạn Thu nhập: không mẫu thu nào → thẻ biến mất; về Chi tiêu → hiện lại', (tester) async {
      await mo(tester, app());
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await chonDoan(tester, 'thu');
      expect(find.text('Gợi ý danh mục'), findsNothing);
      await chonDoan(tester, 'chi');
      expect(find.text(_lyDoAn), findsOneWidget);
    });

    testWidgets('⭐ đoạn Thu nhập CÓ mẫu thu: 9.000.000 → Lương; cùng số ấy ở đoạn Chi tiêu thì im', (tester) async {
      await mo(tester, app(mauSoTien: _coMauThu));
      await go(tester, ['9', '000', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: 'không khoản CHI nào ở bậc 5–10 triệu');
      await chonDoan(tester, 'thu');
      expect(find.text('Khoản từ 5.000.000 đ đến 10.000.000 đ bạn thường ghi cho Lương (10/10 lần).'), findsOneWidget);
    });

    testWidgets('chế độ sửa một khoản chưa có danh mục → không', (tester) async {
      final goc = TransactionEntity(
        id: 't1',
        walletId: 'cash',
        idaccount: 1,
        categoryId: null,
        amount: 3500,
        type: 'chi',
        note: '',
        date: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await mo(tester, app(initial: EditTransactionArgs(transaction: goc)));
      // Màn sửa mở với 16 phím ẨN (đã có số tiền) — chạm khối số tiền để hiện, rồi gõ thêm một số: 3.500 → 35.000.
      // Phải GÕ thật: không cú chạm nào thì không đường nào hẹn tính, và ca này xanh cả khi bỏ chốt (đo bằng bản sai).
      await tester.tap(find.byKey(const Key('so-tien-cham')));
      await tester.pumpAndSettle();
      await go(tester, ['0']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('form mở từ biến động số dư → không', (tester) async {
      const khoa = 'bienDong:MB Bank|35000|chi|2026-09-02T12:01';
      final tin = TinBienDong(
        soTien: 35000,
        chieu: 'chi',
        thoiGian: DateTime(2026, 9, 2, 12, 1),
        noiDung: '',
        nguon: kNguonMb,
        duoiTaiKhoan: '7777',
      );
      final bd = dienSanBienDongTuQuery(Uri.parse(deeplinkBienDong(tin, dedupeKey: khoa)).queryParameters)!;
      await mo(tester, app(bienDong: bd));
      await choGoiY(tester);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ hai lần bo_qua của nguồn so_tien trong store → không hiện', (tester) async {
      final bq = [
        for (final d in [20, 21])
          PhanHoiGoiY(
            nguon: kNguonGoiYSoTien,
            amTietChinh: '20000-50000',
            goiYCategoryId: 'food',
            ketQua: kKetQuaGoiYBoQua,
            createdAt: DateTime(2026, 9, d),
          ),
      ];
      await mo(tester, app(phanHoiGoiY: _StoreGia(bq)));
      await go(tester, ['3', '5', '000']);
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });
  });

  group('phản hồi nguồn so_tien', () {
    testWidgets('⭐ Chọn → danh mục được điền, một hàng chon', (tester) async {
      final store = _StoreGia();
      await mo(tester, app(phanHoiGoiY: store));
      await go(tester, ['3', '5', '000']);
      await tester.ensureVisible(find.text('Chọn danh mục này'));
      await tester.tap(find.text('Chọn danh mục này'));
      await tester.pumpAndSettle();
      expect(find.text('Gợi ý danh mục'), findsNothing);
      expect(find.text('Ăn uống'), findsOneWidget, reason: 'hàng Danh mục nay mang tên danh mục đã chọn');
      expect(store.hang.single,
          (nguon: 'so_tien', amTietChinh: '20000-50000', goiY: 'food', ketQua: 'chon', chon: 'food'));
      await luu(tester);
      expect(store.hang, hasLength(1), reason: 'đã phân xử ở nút Chọn — lúc lưu không ghi hàng thứ hai');
    });

    testWidgets('⭐ Bỏ qua → một hàng bo_qua; đổi đoạn rồi quay lại KHÔNG bật lại thẻ trong lượt này', (tester) async {
      final store = _StoreGia();
      await mo(tester, app(phanHoiGoiY: store));
      await go(tester, ['3', '5', '000']);
      await tester.ensureVisible(find.text('Bỏ qua'));
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();
      expect(store.hang.single,
          (nguon: 'so_tien', amTietChinh: '20000-50000', goiY: 'food', ketQua: 'bo_qua', chon: null));
      await chonDoan(tester, 'thu');
      await chonDoan(tester, 'chi');
      expect(find.text('Gợi ý danh mục'), findsNothing);
    });

    testWidgets('⭐ thẻ đang hiện → chọn danh mục KHÁC qua bảng → lưu → một hàng khac', (tester) async {
      final store = _StoreGia();
      await mo(tester, app(phanHoiGoiY: store));
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await chonQuaBang(tester, 'Di chuyển');
      expect(store.hang, isEmpty, reason: 'chưa lưu thì chưa phân xử');
      await luu(tester);
      expect(store.hang.single,
          (nguon: 'so_tien', amTietChinh: '20000-50000', goiY: 'food', ketQua: 'khac', chon: 'move'));
    });

    testWidgets('⭐ thẻ đang hiện → đổi số tiền sang bậc KHÔNG có gợi ý → chọn qua bảng → lưu → không ghi',
        (tester) async {
      final store = _StoreGia();
      await mo(tester, app(phanHoiGoiY: store));
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn), findsOneWidget);
      await go(tester, ['0']); // 350.000
      expect(find.text('Gợi ý danh mục'), findsNothing);
      await chonQuaBang(tester, 'Di chuyển');
      await luu(tester);
      expect(store.hang, isEmpty, reason: 'thẻ bị huỷ vì số tiền sang bậc khác không phải phán xét');
    });

    testWidgets('⭐ đổi VÍ làm thẻ biến mất → chọn qua bảng → lưu → không ghi', (tester) async {
      final store = _StoreGia();
      final bank = makeWallet(id: 'bank', name: 'Ngân hàng').copyWith(isDefault: false);
      await mo(tester, app(phanHoiGoiY: store, mauSoTien: _haiVi, wallets: [makeWallet(), bank]));
      await go(tester, ['3', '5', '000']);
      expect(find.text(_lyDoAn.replaceFirst('(6/6 lần)', '(8/14 lần)')), findsOneWidget);
      await tester.ensureVisible(find.text('Ví thanh toán'));
      await tester.tap(find.text('Ví thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngân hàng'));
      await choGoiY(tester);
      expect(find.text('Gợi ý danh mục'), findsNothing, reason: 'ví bank: số đông là một danh mục không chọn được');
      await chonQuaBang(tester, 'Di chuyển');
      await luu(tester);
      expect(store.hang, isEmpty, reason: 'thẻ bị huỷ vì đổi ví không phải phán xét của người dùng');
    });

    testWidgets('⭐ chọn qua bảng RỒI mới đổi số tiền sang bậc khác → lưu → không ghi', (tester) async {
      final store = _StoreGia();
      await mo(tester, app(phanHoiGoiY: store));
      await go(tester, ['3', '5', '000']);
      await chonQuaBang(tester, 'Di chuyển');
      await go(tester, ['0']); // 350.000
      await luu(tester);
      expect(store.hang, isEmpty, reason: 'gợi ý cũ nói về bậc 20–50k; khoản đang lưu là 350.000');
    });
  });

  testWidgets('bố cục 360 × 640, theme thật, 16 phím đang mở: thẻ dựng được, không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mo(tester, app(theme: AppTheme.lightTheme));
    await go(tester, ['3', '5', '000']);
    expect(tester.takeException(), isNull);
    expect(find.text(_lyDoAn), findsOneWidget);
  });
}
