/// Ba trang giao dịch **không** được rơi về tài khoản `1` khi chưa có phiên.
///
/// ## Vì sao có tệp này
///
/// `core/auth/khong_du_phong_admin_test.dart` quét `lib/` và cấm hai **hình
/// dạng** mã: `?? 1`, và (từ 2026-09-14) một tham số tên chứa `account`/`user`
/// khai mặc định `= 1`. Nhưng lưới quét chỉ thấy hình dạng — nó không biết
/// trang **làm gì** khi không có phiên. Tệp này canh chính hành vi ấy.
///
/// ⚠️ Lỗ hổng được tìm ra ngày 2026-09-14, và nó đã sống qua cả hai lượt đóng
/// G4 (bốn trang bill/goal) lẫn G35 (ba màn danh mục), vì nó viết khác:
///
///     const TransactionPage({super.key, this.idaccount = 1});
///     ...
///     currentUserId = int.tryParse(authState.user!.id) ?? widget.idaccount;
///
/// Vế `??` trỏ tới một biến, không tới hằng `1` — nên mọi lượt `grep '?? 1'`
/// đều sạch, trong khi route dựng `const TransactionPage()` nên giá trị thật
/// sự dùng vẫn là `1`, tức **tài khoản admin thật**.
///
/// Nặng nhất là `AddTransactionPage`: đó là đường **GHI**, nên giao dịch tạo
/// trong lúc phiên chưa sẵn sàng mang chủ sở hữu sai, rồi đẩy lên và vỡ
/// "Ownership mismatch" — đúng kịch bản mà docstring của
/// `core/auth/current_account.dart` mô tả khi G4 được đóng.
library;

import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  FakeCategoryRepository danhMuc() => FakeCategoryRepository(
        trees: {
          'chi': CategoryTree(
            groups: const [],
            ungroupedChildren: const [],
            defaultChildren: [anUong],
          ),
        },
        selectable: const [],
      );

  /// ⚠️ Phải đi HẾT chuỗi chốt của `_saveTransaction` thì mới chạm được chốt
  /// tài khoản — nó đứng cuối. Bản đầu của tệp này bỏ bước chọn danh mục, nên
  /// bài kiểm dừng ở chốt "Vui lòng chọn danh mục" và **xanh vì lý do sai**.
  Future<void> dienDuForm(WidgetTester tester) async {
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khoản chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    // Bàn phím số nằm dưới mép khung 600px của bộ test nên phải cuộn tới;
    // không thì tap trượt trong im lặng và số tiền vẫn 0.
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('000'));
    await tester.tap(find.text('000'));
    await tester.pump();
  }

  /// Trang thêm giao dịch **không có `AuthBloc`** và **không tiêm
  /// `idaccount`** — đúng trạng thái "chưa biết chủ sở hữu".
  ///
  /// Ví được tiêm thẳng để vượt qua chốt "Vui lòng chọn ví thanh toán"; nếu
  /// không thì bài kiểm dừng ở chốt ấy và không bao giờ chạm tới chốt tài
  /// khoản — xanh vì lý do sai.
  Widget trangKhongPhien(
    FakeCategoryRepository categoryRepository,
    FakeTransactionRepository transactionRepository,
  ) {
    final bloc = TransactionBloc(transactionRepository: transactionRepository);
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
                categoryRepository: categoryRepository,
                wallets: [makeWallet()],
                // `idaccount` CỐ Ý vắng mặt — đây là cả nội dung bài kiểm.
              ),
            ),
          ],
        ),
        // Trang thêm push cứng '/add/category', như `app_router` thật.
        //
        // ⚠️ Màn này ĐƯỢC tiêm `idaccount` còn trang ghi thì không — cố ý, và
        // đây là chỗ bài kiểm phải nói thật: trong luồng thường, thiếu phiên
        // thì màn chọn danh mục cũng rỗng, nên chốt "Vui lòng chọn danh mục"
        // chặn trước và chốt tài khoản KHÔNG BAO GIỜ chạm tới. Chốt tài khoản
        // là **lớp phòng thủ thứ hai**: nó bắt trường hợp form đã đủ dữ kiện
        // mà phiên vẫn chưa sẵn sàng (phiên rơi giữa chừng, hoặc một đường
        // dựng form khác thêm về sau). Tiêm lệch như thế này là cách duy nhất
        // dựng lại trạng thái ấy trong widget test.
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categoryRepository,
            idaccount: 7,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('không có phiên thì KHÔNG ghi giao dịch nào', (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(trangKhongPhien(danhMuc(), transactions));
    await tester.pumpAndSettle();

    await dienDuForm(tester);

    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();

    expect(transactions.added, isEmpty,
        reason: 'Ghi giao dịch khi chưa biết nó thuộc về ai là ghi dưới danh '
            'nghĩa admin (mã 1). Hàng ấy rồi sẽ đẩy lên và vỡ "Ownership '
            'mismatch" — im lặng với người dùng, và không ai lần được từ đâu.');
  });

  testWidgets('không có phiên thì nói rõ lý do, không im lặng',
      (tester) async {
    await tester
        .pumpWidget(trangKhongPhien(danhMuc(), FakeTransactionRepository()));
    await tester.pumpAndSettle();

    await dienDuForm(tester);

    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pump();

    expect(find.text('Chưa xác định được tài khoản đăng nhập'), findsOneWidget,
        reason: 'Chặn mà không nói gì là người dùng bấm Lưu nhiều lần rồi '
            'tưởng app hỏng. Cùng khuôn với G35 ở ba màn quản lý danh mục.');
  });
}
