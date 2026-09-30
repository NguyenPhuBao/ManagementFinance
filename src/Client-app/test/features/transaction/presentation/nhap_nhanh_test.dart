/// C2 — ô *Nhập nhanh* ở màn Thêm giao dịch (spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §3): gõ một câu,
/// bấm **Điền** → form được ĐIỀN SẴN những ô đọc được; người dùng xem lại rồi bấm ✓ (bất biến ④ nhóm C: không tự lưu).
///
/// Phép đọc câu có bộ test riêng (`domain/doc_cau_giao_dich_test.dart`); ở đây kiểm CHỖ NỐI — mỗi ô phải đi qua đúng
/// đường người dùng vẫn đi, để hệ quả của nó chạy như khi chạm tay.
library;

import 'dart:async';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../category/presentation/category_test_fakes.dart';

class _StoreGia implements GoiYPhanHoiStore {
  final List<({String goiY, String ketQua, String? chon})> hang = [];

  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) async =>
      hang.add((goiY: goiY.categoryId, ketQua: ketQua, chon: chonCategoryId));

  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => const [];
}

/// Runtime giả cho nhánh AI (C2 §2.8): mỗi phiên lấy từ [taoPhien]; nạp tức thì.
class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.taoPhien);
  final PhienCongCu Function() taoPhien;
  bool _san = false;
  int soLanNap = 0;
  int soPhien = 0;
  @override
  bool get dangSan => _san;
  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    _san = true;
  }

  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    soPhien++;
    return taoPhien();
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Future<void> huy() async {}
  @override
  Future<void> dong() async {}
}

/// Lượt sinh treo — chỉ dừng khi bị huỷ, như engine thật.
class _PhienTreo implements PhienCongCu {
  final _luong = StreamController<SuKienLuot>();
  @override
  Stream<SuKienLuot> sinhLuot() => _luong.stream;
  @override
  Future<void> traKetQua(String ten, Map<String, dynamic> json) async {}
  @override
  Future<void> huy() async {
    if (!_luong.isClosed) await _luong.close();
  }

  @override
  Future<void> dong() async {}
}

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final diChuyen = makeCategory(id: 'move', name: 'Di chuyển', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);

  // Ví mặc định là Techcombank, để "tiền mặt" trong câu là một thay đổi đo được.
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt').copyWith(isDefault: false);
  final tcb = makeWallet(id: 'tcb', name: 'Techcombank').copyWith(type: 'bank');

  FakeCategoryRepository categories({Map<String, List<String>> keywords = const {}}) {
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    return FakeCategoryRepository(
      trees: {'chi': cay([anUong, diChuyen]), 'thu': cay([luong]), 'vay_no': cay(const [])},
      selectable: [anUong, diChuyen, luong],
      keywords: keywords,
    );
  }

  MauGhiChu m(String c, String ghiChu) =>
      MauGhiChu(categoryId: c, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 9, 1));
  final moHinh = BoPhanLoaiGhiChu.hoc([
    for (var i = 0; i < 5; i++) m('move', 'grab'),
    for (var i = 0; i < 5; i++) m('food', 'cafe sáng'),
  ]);

  Widget app({
    FakeTransactionRepository? repo,
    EditTransactionArgs? initial,
    Map<String, String>? viHayDung,
    BoPhanLoaiGhiChu? boPhanLoai,
    GoiYPhanHoiStore? phanHoiGoiY,
    ThemeData? theme,
    DocCauBangAi? docAi,
    Map<String, List<String>> keywords = const {},
  }) {
    final bloc = TransactionBloc(transactionRepository: repo ?? FakeTransactionRepository());
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
                wallets: [tienMat, tcb],
                idaccount: 1,
                initial: initial,
                viHayDung: viHayDung,
                boPhanLoai: boPhanLoai,
                phanHoiGoiY: phanHoiGoiY,
                docAi: docAi,
                budgetLookup: (_, __) async => null,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(theme: theme, routerConfig: router);
  }

  Future<void> dien(WidgetTester tester, String cau) async {
    await tester.enterText(find.byKey(const Key('nhap-nhanh-o')), cau);
    // Gõ ghi chú trước đó làm vùng cuộn trượt xuống — nút Điền ở đầu vùng cuộn có thể đã ra khỏi khung.
    await tester.ensureVisible(find.byKey(const Key('nhap-nhanh-dien')));
    await tester.tap(find.byKey(const Key('nhap-nhanh-dien')));
    // 350 ms: qua nhịp hoãn 300 ms của gợi ý danh mục, để ca "không hiện thẻ gợi ý" có nghĩa.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  String ghiChu(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('ghi-chu-giao-dich'))).controller!.text;
  String tomTat(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('nhap-nhanh-tom-tat'))).data!;
  String ngayForm(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  testWidgets('⭐ "hôm qua ăn phở 45k tiền mặt" → số tiền, ngày, ví, ghi chú và dòng tóm tắt', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Techcombank • 100.000 đ'), findsOneWidget, reason: 'tiền đề: ví mặc định');

    await dien(tester, 'hôm qua ăn phở 45k tiền mặt');

    final homQua = DateTime.now().subtract(const Duration(days: 1));
    expect(find.text('45.000 đ'), findsOneWidget, reason: 'con số lớn đầu màn');
    expect(find.text(ngayForm(homQua)), findsOneWidget);
    expect(find.text('Tiền mặt • 100.000 đ'), findsOneWidget);
    expect(ghiChu(tester), 'ăn phở');
    expect(tomTat(tester), 'Đã điền: 45.000 đ · Hôm qua · Tiền mặt');
  });

  testWidgets('bấm Điền đóng bàn phím hệ thống — bàn phím số và ✓ quay lại (G58 ẩn chúng khi đang gõ)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await dien(tester, '45k');
    expect(tester.widget<TextField>(find.byKey(const Key('nhap-nhanh-o'))).focusNode!.hasFocus, isFalse,
        reason: 'ô còn focus thì bàn phím hệ thống còn mở, 16 phím số và nút ✓ vẫn ẩn — người dùng không lưu được');
  });

  testWidgets('câu chỉ có số tiền → CHỈ số tiền đổi; ví, ngày, ghi chú giữ nguyên', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ghi-chu-giao-dich')), 'ghi chú cũ');
    await tester.pumpAndSettle();

    await dien(tester, '45k');

    expect(find.text('45.000 đ'), findsOneWidget);
    expect(find.text('Techcombank • 100.000 đ'), findsOneWidget);
    expect(find.text(ngayForm(DateTime.now())), findsOneWidget);
    expect(ghiChu(tester), 'ghi chú cũ', reason: 'câu không để lại chữ nào cho ghi chú — ô ấy "không đọc được"');
  });

  testWidgets('câu không đọc được → câu mời điền tay, không ô nào đổi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await dien(tester, 'xin chào');

    expect(tomTat(tester), kCauChuaDocDuoc);
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.text('Techcombank • 100.000 đ'), findsOneWidget);
    expect(ghiChu(tester), '');
  });

  testWidgets('⚠️ ví đọc từ câu KHÔNG bị luật "ví hay dùng theo danh mục" đè', (tester) async {
    // Ăn uống hay dùng Techcombank; câu nói tiền mặt. Thiếu cờ _nguoiDungDaChonVi thì _chonDanhMuc kéo ví về TCB.
    await tester.pumpWidget(app(viHayDung: {'food': 'tcb'}));
    await tester.pumpAndSettle();

    await dien(tester, '45k tiền mặt ăn uống');

    expect(find.text('Ăn uống'), findsOneWidget, reason: 'tiền đề: danh mục đọc được từ tên trong câu');
    expect(find.text('Tiền mặt • 100.000 đ'), findsOneWidget);
  });

  testWidgets('⚠️ đang có danh mục CHI mà câu nói khoản thu → danh mục chi bị bỏ (đi qua _chonHuong)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await dien(tester, '45k ăn uống');
    expect(find.text('Ăn uống'), findsOneWidget, reason: 'tiền đề');

    await dien(tester, 'được cho 500k');

    expect(find.text('Ăn uống'), findsNothing,
        reason: 'gán thẳng _huong là để danh mục chi đứng dưới đoạn Thu — hai sự thật trái nhau');
    expect(find.text('Chọn danh mục'), findsOneWidget);
  });

  testWidgets('câu nói khoản THU + tên danh mục thu → lưu ra khoản thu đúng danh mục', (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(repo: repo));
    await tester.pumpAndSettle();

    await dien(tester, 'hôm qua nhận lương 9tr tiền mặt');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final t = repo.added.single.transaction;
    final homQua = DateTime.now().subtract(const Duration(days: 1));
    expect(t.amount, 9000000);
    expect(t.type, 'thu');
    expect(t.categoryId, 'luong');
    expect(t.walletId, 'cash');
    expect((t.date.year, t.date.month, t.date.day), (homQua.year, homQua.month, homQua.day));
    expect(t.note, 'nhận lương');
  });

  testWidgets('⭐ danh mục từ B1: hiện câu lý do, KHÔNG hiện thẻ gợi ý, lưu thì ghi phản hồi "chon"', (tester) async {
    final store = _StoreGia();
    await tester.pumpWidget(app(boPhanLoai: moHinh, phanHoiGoiY: store));
    await tester.pumpAndSettle();

    await dien(tester, 'grab 50k tiền mặt');

    expect(find.text('Di chuyển'), findsOneWidget);
    expect(find.text('Bạn thường ghi “grab” cho Di chuyển (5/5 lần).'), findsOneWidget);
    expect(find.text('Gợi ý danh mục'), findsNothing,
        reason: 'ghi chú đặt SAU danh mục — _onNoteChanged thấy đã có danh mục thì không hẹn gợi ý');

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(store.hang.single, (goiY: 'move', ketQua: kKetQuaGoiYChon, chon: 'move'),
        reason: 'người dùng chốt: danh mục điền từ B1 ghi phản hồi như thẻ gợi ý');
  });

  testWidgets('danh mục từ TỪ KHOÁ (người dùng chốt 2026-09-30): điền, hiện câu lý do, lưu thì ghi phản hồi "chon"',
      (tester) async {
    final store = _StoreGia();
    await tester.pumpWidget(app(phanHoiGoiY: store, keywords: {'move': ['xăng']}));
    await tester.pumpAndSettle();

    await dien(tester, 'đổ xăng 50k');

    expect(find.text('Di chuyển'), findsOneWidget);
    expect(find.text('Khớp với “xăng” trong ghi chú.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(store.hang.single, (goiY: 'move', ketQua: kKetQuaGoiYChon, chon: 'move'));
  });

  // §2.9 — người dùng báo 2026-09-30: câu chuyển giữa hai ví bị điền thành khoản chi.
  testWidgets('⭐ "chuyển 500k từ tiền mặt sang techcombank" → đoạn Chuyển khoản, nguồn Tiền mặt, đích Techcombank; lưu ra '
      'khoản chuyển không danh mục', (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(repo: repo));
    await tester.pumpAndSettle();

    await dien(tester, 'chuyển 500k từ tiền mặt sang techcombank');

    expect(tomTat(tester), 'Đã điền: 500.000 đ · Chuyển ví · Tiền mặt → Techcombank');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final t = repo.added.single.transaction;
    expect(t.type, 'transfer');
    expect(t.amount, 500000);
    expect(t.walletId, 'cash');
    expect(t.walletTransfer, 'tcb');
    expect(t.categoryId, isNull);
  });

  testWidgets('⚠️ câu chỉ nêu ví đích, mà ví nguồn đang chọn lại chính là nó → ví nguồn để trống (không chuyển vào chính '
      'nó)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Techcombank • 100.000 đ'), findsOneWidget, reason: 'tiền đề: ví nguồn mặc định là Techcombank');

    await dien(tester, 'chuyển 500k vào techcombank');

    expect(tomTat(tester), 'Đã điền: 500.000 đ · Chuyển ví · sang Techcombank');
    expect(find.text('Chọn ví'), findsOneWidget, reason: 'ví nguồn');
    expect(find.text('Techcombank • 100.000 đ'), findsOneWidget, reason: 'ví đích');
  });

  testWidgets('màn SỬA giao dịch không có ô Nhập nhanh', (tester) async {
    final goc = TransactionEntity(
      id: 'tx',
      walletId: 'cash',
      idaccount: 1,
      categoryId: 'food',
      amount: 45000,
      type: 'chi',
      note: 'phở',
      date: DateTime(2026, 9, 19),
      updatedAt: DateTime(2026, 9, 19),
    );
    await tester.pumpWidget(app(initial: EditTransactionArgs(transaction: goc, category: anUong)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nhap-nhanh-o')), findsNothing);
  });

  group('C2 §2.8 — AI đọc mọi câu, luật kiểm', () {
    DocCauBangAi aiTraVe(Map<String, dynamic> thamSo, {_RuntimeGia? runtime, bool sanSang = true}) => DocCauBangAi(
          runtime: runtime ??
              _RuntimeGia(() => PhienCongCuGia([
                    [GoiCongCu(kTenCongCuDienGiaoDich, thamSo)],
                  ])),
          sanSang: () async => sanSang,
          duongTep: () async => '/gia/gemma.litertlm',
        );

    testWidgets('⭐ AI đọc được thứ luật bó tay ("ba chục") → điền, nguồn "Đọc bằng AI"', (tester) async {
      await tester.pumpWidget(app(
        docAi: aiTraVe({
          'so_tien': 30000,
          'loai': 'chi',
          'ngay': '',
          'vi': '',
          'danh_muc': 'Ăn uống',
          'ghi_chu': 'cà phê với Nam',
        }),
      ));
      await tester.pumpAndSettle();

      await dien(tester, 'cà phê với Nam mất ba chục');

      expect(find.text('30.000 đ'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(ghiChu(tester), 'cà phê với Nam');
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng AI');
    });

    // ĐỔI LẦN HAI (người dùng chốt 2026-09-30): ba ca dưới từng dùng câu "ăn phở 45k" — luật đọc đủ câu ấy nên nay nó
    // KHÔNG tới AI. Câu thay có một ô thiếu để ca vẫn đi đường AI.
    testWidgets('⚠️ AI bịa số không có trong câu → bị bỏ (không bao giờ bịa số)', (tester) async {
      await tester.pumpWidget(app(docAi: aiTraVe({'so_tien': 300000, 'loai': 'chi'})));
      await tester.pumpAndSettle();

      await dien(tester, 'cà phê mất ba chục');

      expect(find.text('300.000 đ'), findsNothing);
      expect(find.text('0 đ'), findsOneWidget);
    });

    testWidgets('máy chưa có mô hình / công tắc tắt → không chờ gì, đọc bằng luật', (tester) async {
      await tester.pumpWidget(app(docAi: aiTraVe({'so_tien': 30000}, sanSang: false)));
      await tester.pumpAndSettle();

      await dien(tester, 'quẹt thẻ ăn phở 45k');

      expect(find.text('45.000 đ'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng luật');
    });

    testWidgets('⭐ luật đọc đủ những gì câu nhắc → KHÔNG mở phiên mô hình, điền ngay, nguồn "Đọc bằng luật"',
        (tester) async {
      final runtime = _RuntimeGia(() => PhienCongCuGia([
            [const GoiCongCu(kTenCongCuDienGiaoDich, {'so_tien': 450000})],
          ]));
      await tester.pumpWidget(app(docAi: aiTraVe(const {}, runtime: runtime)));
      await tester.pumpAndSettle();

      await dien(tester, 'hôm qua 45k ăn uống tiền mặt');

      expect(runtime.soPhien, 0, reason: 'không còn ô thiếu — gọi mô hình là bắt người dùng chờ ~18 s vô ích');
      expect(find.text('45.000 đ'), findsOneWidget);
      expect(find.byKey(const Key('nhap-nhanh-dang-doc')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng luật');
    });

    testWidgets('câu còn ô thiếu ("ba chục") → mở ĐÚNG một phiên mô hình', (tester) async {
      final runtime = _RuntimeGia(() => PhienCongCuGia([
            [const GoiCongCu(kTenCongCuDienGiaoDich, {'so_tien': 30000})],
          ]));
      await tester.pumpWidget(app(docAi: aiTraVe(const {}, runtime: runtime)));
      await tester.pumpAndSettle();

      await dien(tester, 'cà phê mất ba chục');

      expect(runtime.soPhien, 1);
      expect(find.text('30.000 đ'), findsOneWidget);
    });

    testWidgets('⭐ danh mục trống → hỏi AI, AI điền danh mục (người dùng: "chỗ nào không điền được thì cho AI điền")',
        (tester) async {
      final runtime = _RuntimeGia(() => PhienCongCuGia([
            [const GoiCongCu(kTenCongCuDienGiaoDich, {'so_tien': 60000, 'loai': 'chi', 'danh_muc': 'Ăn uống'})],
          ]));
      await tester.pumpWidget(app(docAi: aiTraVe(const {}, runtime: runtime)));
      await tester.pumpAndSettle();

      await dien(tester, 'mua 2 ly trà sữa 60k');

      expect(runtime.soPhien, 1);
      expect(tomTat(tester), 'Đã điền: 60.000 đ · Ăn uống');
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng AI');
    });

    testWidgets('dòng nguồn: AI chỉ chọn lại đúng ví ĐANG chọn → "Đọc bằng luật" (người dùng chốt: chỉ khi AI đổi một ô)',
        (tester) async {
      await tester.pumpWidget(app(docAi: aiTraVe({'so_tien': 45000, 'loai': 'chi', 'vi': 'Techcombank'})));
      await tester.pumpAndSettle();
      expect(find.text('Techcombank • 100.000 đ'), findsOneWidget, reason: 'tiền đề: ví đang chọn');

      await dien(tester, 'quẹt thẻ ăn phở 45k');

      expect(find.text('Techcombank • 100.000 đ'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng luật');
    });

    testWidgets('đang đọc → "Đang đọc bằng AI…" + Huỷ; Huỷ thì điền NGAY bằng luật', (tester) async {
      await tester.pumpWidget(app(docAi: aiTraVe(const {}, runtime: _RuntimeGia(_PhienTreo.new))));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('nhap-nhanh-o')), 'quẹt thẻ ăn phở 45k');
      await tester.tap(find.byKey(const Key('nhap-nhanh-dien')));
      // Vòng xoay chạy mãi — pumpAndSettle không bao giờ lặng.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('nhap-nhanh-dang-doc')), findsOneWidget);
      expect(find.text('0 đ'), findsOneWidget, reason: 'chưa điền gì trong lúc chờ');

      await tester.tap(find.byKey(const Key('nhap-nhanh-huy')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('nhap-nhanh-dang-doc')), findsNothing);
      expect(find.text('45.000 đ'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('nhap-nhanh-nguon'))).data, 'Đọc bằng luật');
    });

    testWidgets('chạm vào ô Nhập nhanh → nạp mô hình ngầm (người dùng chốt)', (tester) async {
      final runtime = _RuntimeGia(() => PhienCongCuGia(const []));
      await tester.pumpWidget(app(docAi: aiTraVe(const {}, runtime: runtime)));
      await tester.pumpAndSettle();
      expect(runtime.soLanNap, 0, reason: 'mở màn không nạp 2,41 GB');

      await tester.tap(find.byKey(const Key('nhap-nhanh-o')));
      await tester.pumpAndSettle();
      expect(runtime.soLanNap, 1);
    });
  });

  group('bố cục ở khổ hẹp, theme thật', () {
    void kho(WidgetTester tester, {double banPhim = 0}) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: banPhim);
      addTearDown(tester.view.reset);
    }

    testWidgets('360 × 640: không tràn, sau khi điền vẫn thấy ✓ và bàn phím số', (tester) async {
      kho(tester);
      await tester.pumpWidget(app(theme: AppTheme.lightTheme, boPhanLoai: moHinh));
      await tester.pumpAndSettle();
      await dien(tester, 'hôm qua grab 50k tiền mặt, ăn sáng 30k');

      expect(tester.takeException(), isNull, reason: 'Flutter báo tràn qua reportError chứ không ném ra chỗ gọi');
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('000'), findsOneWidget);
    });

    testWidgets('⚠️ theme thật: ô trong khung KHÔNG có nền và viền riêng (máy thật hiện một ô trắng có viền)', (tester) async {
      await tester.pumpWidget(app(theme: AppTheme.lightTheme));
      await tester.pumpAndSettle();
      // InputDecorator nhận decoration ĐÃ gộp theme — chỗ lộ `enabledBorder` / `filled` của theme app.
      final d = tester
          .widget<InputDecorator>(
              find.descendant(of: find.byKey(const Key('nhap-nhanh-o')), matching: find.byType(InputDecorator)))
          .decoration;
      expect(d.filled, isFalse);
      expect(d.enabledBorder, InputBorder.none);
      expect(d.focusedBorder, InputBorder.none);
    });

    testWidgets('bàn phím HỆ THỐNG mở (đang gõ câu, G58): không tràn, ô Nhập nhanh nằm trên bàn phím', (tester) async {
      kho(tester, banPhim: 260);
      await tester.pumpWidget(app(theme: AppTheme.lightTheme));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final o = tester.getRect(find.byKey(const Key('nhap-nhanh-o')));
      expect(o.height, greaterThan(0));
      expect(o.bottom, lessThanOrEqualTo(640 - 260 + 0.5), reason: 'người dùng phải thấy chữ mình đang gõ');
    });
  });
}
