/// Form Thêm giao dịch ở CHẾ ĐỘ NHÀ (gia đình 1B, Task 3; `02A` mục 4, Stitch `5a53df6e`). Canh: không Nhập nhanh / micro /
/// tách / gợi ý / nút ba chấm; Thành viên không có chip Chuyển khoản; Lưu gắn `idhousehold`; Sửa giữ người ghi và nhà.
library;

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/features/transaction/presentation/state/che_do_nha_form.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/nha_gia.dart';
import '../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final viChung = makeWallet(id: 'chung', name: 'Tiền chợ', balance: 3200000);

  Widget dung(
    FakeTransactionRepository repo, {
    bool choChuyen = true,
    EditTransactionArgs? sua,
    String? huong,
    List<CategoryEntity> danhMuc = const [],
  }) {
    final bloc = TransactionBloc(transactionRepository: repo);
    addTearDown(bloc.close);
    final nguon = NguonThemGiaoDichGia(vi: [viChung, makeWallet(id: 'chung2', name: 'Quỹ dự phòng')], danhMuc: [anUong]);
    final router = GoRouter(
      initialLocation: '/start/khoan',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, __) => const Scaffold(body: Text('Trang trước')),
          routes: [
            GoRoute(
              path: 'khoan',
              builder: (_, __) => AddTransactionPage(
                idaccount: 20,
                laPremium: true,
                nguon: nguon,
                transactionBloc: bloc,
                initial: sua,
                huongBanDau: huong,
                nha: CheDoNhaForm(
                  idNha: 7,
                  tenNha: 'Nhà An Bình',
                  choChuyen: choChuyen,
                  duongChonDanhMuc: '/nha/khoan/category',
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/nha/khoan/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            napCay: (c) async => CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: [anUong]),
            duongQuanLy: null,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    return bocRouterNha(router);
  }

  Future<void> luu(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();
  }

  Future<void> goVaChon(WidgetTester t) async {
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
  }

  testWidgets('chế độ nhà ẩn Nhập nhanh, micro, tách, gợi ý, nút ba chấm', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    expect(find.byType(ONhapNhanh), findsNothing, reason: '02A mục 4: không Nhập nhanh ở chế độ nhà');
    expect(find.byTooltip('Thêm tuỳ chọn'), findsNothing, reason: 'nút ba chấm là handler rỗng, chế độ nhà không dựng');
    expect(find.text('Thêm phần'), findsNothing);
    expect(find.text('Nhà An Bình · ghi vào quỹ chung'), findsOneWidget, reason: 'phải đòi có, không chỉ đòi vắng');
    expect(find.text('Ví chung'), findsOneWidget, reason: 'nhãn dòng ví đổi từ "Ví thanh toán"');
    expect(find.text('Ví thanh toán'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Khoản chi của nhà'), findsOneWidget);
  });

  testWidgets('Chủ nhà có chip Chuyển khoản; Thành viên thì không', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('transaction-type-transfer')), findsOneWidget);
    await t.pumpWidget(dung(FakeTransactionRepository(), choChuyen: false));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('transaction-type-transfer')), findsNothing,
        reason: 'Thành viên không đổi được khoản thành chuyển: server từ chối rồi khoản biến mất im lặng');
    expect(find.byKey(const Key('transaction-type-thu')), findsOneWidget);
    expect(find.byKey(const Key('transaction-type-chi')), findsOneWidget);
  });

  testWidgets('tiêu đề theo chiều: Thu nhập → "Khoản thu của nhà"', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository(), huong: 'thu'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Khoản thu của nhà'), findsOneWidget);
    await t.tap(find.byKey(const Key('transaction-type-chi')));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Khoản chi của nhà'), findsOneWidget, reason: 'tiêu đề đi theo đoạn đang chọn');
  });

  testWidgets('Lưu gắn idhousehold, idaccount từ phiên', (t) async {
    final repo = FakeTransactionRepository();
    await t.pumpWidget(dung(repo));
    await t.pumpAndSettle();
    await goVaChon(t);
    await luu(t);
    final e = repo.added.single.transaction;
    expect(e.idhousehold, 7, reason: 'thiếu là khoản của nhà lưu thành khoản riêng trỏ ví nhà');
    expect(e.idaccount, 20);
    expect(e.walletId, 'chung');
    expect(e.categoryId, 'food');
  });

  testWidgets('Sửa khoản giữ người ghi và nhà', (t) async {
    final repo = FakeTransactionRepository();
    final cu = TransactionEntity(
      id: 'tx-nha',
      walletId: 'chung',
      idaccount: 10,
      idhousehold: 7,
      categoryId: 'food',
      amount: 45000,
      type: 'chi',
      note: 'đi chợ',
      date: DateTime(2026, 11, 1, 7, 30),
      images: const [],
      syncStatus: 'synced',
      isDeleted: false,
      updatedAt: DateTime(2026, 11, 1),
    );
    await t.pumpWidget(dung(repo, sua: EditTransactionArgs(transaction: cu, category: anUong)));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Sửa khoản của nhà'), findsOneWidget);
    await luu(t);
    final e = repo.updated.single.after;
    expect(e.idaccount, 10, reason: 'server giữ Idaccount người ghi; đổi là ROLE_FORBIDDEN');
    expect(e.idhousehold, 7);
    expect(e.id, 'tx-nha');
  });

  testWidgets('360 dp, 13 chữ số, có và không có bàn phím hệ thống: không tràn', (t) async {
    dat360(t);
    await t.pumpWidget(dung(FakeTransactionRepository()));
    await t.pumpAndSettle();
    for (var i = 0; i < 13; i++) {
      await t.ensureVisible(find.text('9'));
      await t.tap(find.text('9'));
    }
    await t.pump();
    expect(t.takeException(), isNull, reason: '13 chữ số là trần numeric(15,2); nhãn nhà thêm một dòng vào cột cố định');
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pump();
    expect(t.takeException(), isNull, reason: 'bàn phím hệ thống mở: 16 phím ẩn, nhãn nhà vẫn vừa');
  });
}
