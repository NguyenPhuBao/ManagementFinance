/// Form Thêm giao dịch THƯỜNG (`/add`) chọn được ví chung của nhà và đổi TẠI CHỖ sang khoản của nhà (spec 2026-11-16 mục 2):
/// nhóm "VÍ CHUNG · tên nhà" trong bảng chọn ví, nhãn nhà + tiêu đề nhà sau khi chọn, không Nhập nhanh, Chuyển khoản / sửa
/// không có nhóm, lưu mang `idhousehold`, mất quyền thì không lưu mà vẫn giữ form.
library;

import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/vi_chung_cho_form_nguon.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';
import '../../../helpers/nha_gia.dart';
import '../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final anUongNha = makeCategory(id: 'nha-food', name: 'Ăn uống', idaccount: 0);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt').copyWith(isDefault: true);
  final viNha = makeWallet(id: 'nha-v', name: 'Tiền chợ', balance: 820000).copyWith(idhousehold: 7);

  Widget dung(
    FakeTransactionRepository repo, {
    String tenNha = 'Nhà An Bình',
    bool Function()? conDuocGhi,
    EditTransactionArgs? sua,
  }) {
    final bloc = TransactionBloc(transactionRepository: repo);
    addTearDown(bloc.close);
    final rieng = NguonThemGiaoDichGia(vi: [tienMat], danhMuc: [anUong]);
    final nha = NguonThemGiaoDichGia(vi: [viNha], danhMuc: [anUongNha]);
    final cong = ViChungChoFormNguon(() async => NhomViChung(
          idNha: 7,
          tenNha: tenNha,
          vi: [viNha],
          nguon: nha,
          conDuocGhi: conDuocGhi ?? () => true,
          duongChonDanhMuc: '/add/nha-category',
        ));
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
                idaccount: 20,
                laPremium: true,
                nguon: rieng,
                transactionBloc: bloc,
                initial: sua,
                viChung: cong,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/add/nha-category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            napCay: (c) async => CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: [anUongNha]),
            duongQuanLy: null,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    return bocRouterNha(router);
  }

  Future<void> moBangVi(WidgetTester t, String dongVi) async {
    // `.first`: ở đoạn Chuyển khoản có hai dòng ví (nguồn, đích) cùng chữ — dòng nguồn đứng trước.
    await t.ensureVisible(find.text(dongVi).first);
    await t.pumpAndSettle();
    await t.tap(find.text(dongVi).first);
    await t.pumpAndSettle();
    expect(find.text('Chọn ví thanh toán'), findsOneWidget, reason: 'tiền đề: bảng chọn ví đã mở');
  }

  Future<void> chonViNha(WidgetTester t) async {
    await moBangVi(t, 'Tiền mặt • 100.000 đ');
    await t.tap(find.text('Tiền chợ'));
    await t.pumpAndSettle();
  }

  testWidgets('bảng chọn ví có nhóm VÍ CHUNG · tên nhà và ví chung', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    await moBangVi(t, 'Tiền mặt • 100.000 đ');
    expect(find.text('VÍ CHUNG · Nhà An Bình'), findsOneWidget);
    expect(find.text('Tiền chợ'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget, reason: 'dòng ví chung mang biểu tượng ngôi nhà');
  });

  testWidgets('chọn ví chung → form đổi tại chỗ: nhãn nhà, tiêu đề nhà, "Ví chung", không Nhập nhanh', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    expect(find.byType(ONhapNhanh), findsOneWidget, reason: 'đối chứng: form cá nhân có Nhập nhanh');
    await chonViNha(t);
    expect(find.text('Nhà An Bình · ghi vào quỹ chung'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Khoản chi của nhà'), findsOneWidget);
    expect(find.text('Ví chung'), findsOneWidget);
    expect(find.byType(ONhapNhanh), findsNothing);
    expect(find.text('Trang trước'), findsNothing, reason: 'không chuyển trang');
  });

  testWidgets('chọn lại ví riêng → form về cá nhân', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    await chonViNha(t);
    await moBangVi(t, 'Tiền chợ • 820.000 đ');
    // `.first`: "Tiền mặt" vừa là tên ví vừa là nhãn loại ví ngay dưới.
    await t.tap(find.text('Tiền mặt').first);
    await t.pumpAndSettle();
    expect(find.text('Nhà An Bình · ghi vào quỹ chung'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Thêm giao dịch'), findsOneWidget);
    expect(find.byType(ONhapNhanh), findsOneWidget);
  });

  testWidgets('đoạn Chuyển khoản: bảng chọn ví không có nhóm ví chung', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('transaction-type-transfer')));
    await t.pumpAndSettle();
    await moBangVi(t, 'Tiền mặt • 100.000 đ');
    expect(find.textContaining('VÍ CHUNG'), findsNothing);
    expect(find.text('Tiền chợ'), findsNothing);
  });

  testWidgets('đường SỬA: không có nhóm ví chung', (t) async {
    final cu = TransactionEntity(
      id: 'tx',
      walletId: 'cash',
      idaccount: 20,
      categoryId: 'food',
      amount: 45000,
      type: 'chi',
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );
    await t.pumpWidget(dung(FakeTransactionRepository(), sua: EditTransactionArgs(transaction: cu, category: anUong)));
    await t.pumpAndSettle();
    await moBangVi(t, 'Tiền mặt • 100.000 đ');
    expect(find.textContaining('VÍ CHUNG'), findsNothing);
  });

  testWidgets('lưu ở chế độ nhà → idhousehold của nhà, ví chung, danh mục nhà, người ghi từ phiên', (t) async {
    final repo = FakeTransactionRepository();
    await t.pumpWidget(dung(repo));
    await t.pumpAndSettle();
    await chonViNha(t);
    await t.ensureVisible(find.text('5'));
    await t.tap(find.text('5'));
    await t.ensureVisible(find.text('000'));
    await t.tap(find.text('000'));
    await t.pump();
    await t.ensureVisible(find.text('Danh mục'));
    await t.tap(find.text('Danh mục'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ăn uống'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();
    final e = repo.added.single.transaction;
    expect(e.idhousehold, 7);
    expect(e.walletId, 'nha-v');
    expect(e.categoryId, 'nha-food', reason: 'bộ chọn danh mục mở /add/nha-category — danh mục của nhà');
    expect(e.idaccount, 20);
  });

  testWidgets('mất quyền lúc Lưu → không ghi, có câu báo, form VẪN mở (khác /nha/khoan)', (t) async {
    final bat = batThongBao();
    final repo = FakeTransactionRepository();
    await t.pumpWidget(dung(repo, conDuocGhi: () => false));
    await t.pumpAndSettle();
    await chonViNha(t);
    await t.ensureVisible(find.text('5'));
    await t.tap(find.text('5'));
    await t.pump();
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();
    expect(repo.added, isEmpty);
    expect(bat.cau, isNotEmpty);
    expect(find.text('Trang trước'), findsNothing, reason: 'giữ chữ đã nhập — người dùng còn chọn được ví riêng');
  });

  testWidgets('320 dp: tên nhà rất dài trong tiêu đề nhóm không tràn', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(dung(FakeTransactionRepository(), tenNha: 'Nhà ' * 15));
    await t.pumpAndSettle();
    await moBangVi(t, 'Tiền mặt • 100.000 đ');
    expect(t.takeException(), isNull);
  });
}
