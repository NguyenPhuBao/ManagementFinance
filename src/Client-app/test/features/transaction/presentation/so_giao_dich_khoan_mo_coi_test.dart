/// Trang Sổ giao dịch nối cổng `HoaDonDaXoaNguon` vào dòng (vuốt) và bảng chi tiết (chạm) — việc 4c.
///
/// Vì sao cần: `TransactionListRow` và `TransactionDetailSheet` đều nhận cổng / cờ qua tham số TUỲ CHỌN, mặc định
/// khoá. Trang quên truyền thì mọi ca widget của hai widget ấy vẫn xanh, còn trên máy khoản chi mồ côi vẫn khoá vĩnh
/// viễn — im lặng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flowmoney/core/database/app_database.dart';
import '../../../helpers/nguon_doc_gia.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/hoa_don_da_xoa_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());

  final AuthState _fixed;

  @override
  AuthState get state => _fixed;
}

/// Kỳ nào cũng trả đúng một khoản — khoản chi của một hoá đơn đã xoá.
class _MotKhoanRepository implements TransactionRepository {
  _MotKhoanRepository(this._khoan);

  final TransactionEntity _khoan;

  @override
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) =>
      Stream.value([_khoan]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final khoanMoCoi = TransactionEntity(
    id: 'tx-mo-coi',
    walletId: 'w',
    idaccount: 7,
    billId: 'b-da-xoa',
    amount: 120000,
    type: 'chi',
    note: '${kGhiChuTraHoaDon}Internet',
    // Trang mở ở tháng hiện tại; repository giả bỏ qua khoảng, nhưng dòng nhóm theo ngày của khoản.
    date: now,
    updatedAt: now,
  );

  setUp(() async {
    // BẮT BUỘC: tiêu đề nhóm ngày dựng bằng `DateFormat` locale 'vi' — thiếu thì cả cây dừng dựng.
    await initializeDateFormatting('vi');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _MotKhoanRepository(khoanMoCoi)),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ BẮT BUỘC gọi ở cuối MỖI ca, trong thân ca — xem `so_giao_dich_chon_ky_test.dart`. Thiếu là treo cả tệp.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const TransactionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dong() => find.byKey(const Key('tx-mo-coi'));

  Future<void> chamDong(WidgetTester tester) async {
    await tester.ensureVisible(dong());
    await tester.pumpAndSettle();
    await tester.tap(dong());
    await tester.pumpAndSettle();
  }

  testWidgets('chạm khoản mồ côi: bảng có Xoá, hộp xác nhận mang câu cảnh báo',
      (tester) async {
    sl.registerSingleton<HoaDonDaXoaNguon>(HoaDonDaXoaNguon((_) async => true));
    await moTrang(tester);
    await chamDong(tester);

    expect(find.text('Xoá giao dịch'), findsOneWidget,
        reason: 'Trang phải hỏi cổng TRƯỚC khi mở và truyền kết quả vào bảng.');
    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hoá đơn của khoản này đã xoá'), findsOneWidget,
        reason: 'Khoản mồ côi mở khoá nhưng phải kèm câu cảnh báo trong bảng.');
    expect(find.textContaining('Số dư ví sẽ được hoàn lại'), findsOneWidget,
        reason: 'Câu chung vẫn đứng sau câu cảnh báo (cauXacNhanXoaGiaoDich).');

    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();
    await dongTrang(tester);
  });

  testWidgets('cổng chưa đăng ký: khoản có billId vẫn KHOÁ ở bảng chi tiết',
      (tester) async {
    await moTrang(tester);
    await chamDong(tester);

    expect(find.text('Xoá giao dịch'), findsNothing,
        reason: 'Không có cổng thì khoản có billId vẫn khoá: không có nút Xoá.');
    expect(find.textContaining('không xoá được từ sổ giao dịch'), findsOneWidget,
        reason: 'sl.isRegistered → null → mặc định an toàn là khoá.');
    await dongTrang(tester);
  });

  testWidgets('vuốt khoản mồ côi: hỏi xác nhận kèm câu cảnh báo', (tester) async {
    sl.registerSingleton<HoaDonDaXoaNguon>(HoaDonDaXoaNguon((_) async => true));
    await moTrang(tester);
    await tester.ensureVisible(dong());
    await tester.pumpAndSettle();

    await tester.drag(dong(), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Xoá giao dịch?'), findsOneWidget,
        reason: 'Trang phải truyền cổng xuống TransactionListRow.');
    expect(find.textContaining('Hoá đơn của khoản này đã xoá'), findsOneWidget,
        reason: 'Vuốt xoá khoản mồ côi phải hỏi xác nhận kèm câu cảnh báo, '
            'không xoá thẳng.');

    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();
    await dongTrang(tester);
  });
}
