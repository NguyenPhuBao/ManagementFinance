/// Tiêu đề nhóm ngày của Sổ giao dịch đi CÙNG luật với thẻ tổng (2026-09-29).
///
/// G49 đưa thẻ tổng qua `khoanVaoThongKe` (bỏ khoản điều chỉnh số dư / mở sổ) nhưng tiêu đề mỗi nhóm ngày vẫn tự cộng
/// thô theo `type` (`transaction_page.dart`, vòng thứ tư). Thấy trên Realme: *"Thứ Năm, 10/09/2026 · +10.000 đ"* cho một
/// ngày chỉ có khoản điều chỉnh, trong khi thẻ tổng không cộng nó — một trang, hai quy ước. Người dùng chọn cho tiêu đề
/// ngày đi cùng luật.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

const int _idaccount = 7;

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

/// MỘT ngày, ba hàng: chi 55.000 · thu 20.000 · khoản điều chỉnh số dư +10.000 (không danh mục, đúng cặp dấu hiệu).
class _MotNgayRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) {
    final moc = DateTime.now().subtract(const Duration(days: 1));
    TransactionEntity tx(String id, String type, double amount, String note, String? categoryId) => TransactionEntity(
          id: id,
          walletId: 'vi',
          idaccount: _idaccount,
          categoryId: categoryId,
          amount: amount,
          type: type,
          note: note,
          date: moc,
          images: const [],
          syncStatus: 'synced',
          updatedAt: moc,
          isDeleted: false,
        );
    return Stream.value([
      tx('an', 'chi', 55000, 'an trua', 'c-food'),
      tx('luong', 'thu', 20000, 'thuong', 'c-bonus'),
      tx('dieu-chinh', 'thu', 10000, '$tienToDieuChinh: khop so du', null),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    // BẮT BUỘC: tiêu đề nhóm ngày dựng bằng `DateFormat` locale 'vi' — thiếu thì cả cây dừng dựng (xem G48).
    await initializeDateFormatting('vi');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _MotNgayRepository()),
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

  testWidgets('⭐ tổng của nhóm ngày KHÔNG cộng khoản điều chỉnh số dư — khớp thẻ tổng', (tester) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '$_idaccount', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(value: auth, child: const TransactionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('-25.000 đ'), findsNothing,
        reason: 'cộng thô: 20.000 + 10.000 (điều chỉnh) − 55.000 — tiêu đề ngày đếm khoản mà thẻ tổng đã bỏ');
    expect(find.text('-35.000 đ'), findsNWidgets(2),
        reason: 'ĐÒI KẾT QUẢ: cột Thu net của thẻ tổng VÀ tiêu đề ngày cùng nói 20.000 − 55.000');
    expect(find.text('+10.000 đ'), findsOneWidget,
        reason: 'hàng điều chỉnh vẫn HIỆN trong danh sách — chỉ không cộng vào tổng');

    await dongTrang(tester);
  });
}
