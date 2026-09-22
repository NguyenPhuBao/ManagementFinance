/// Trang Sổ giao dịch khi kỳ đang xem **không có giao dịch nào** (2026-09-21).
///
/// Hai ca dưới đây sinh ra từ lượt **nghiệm thu máy ảo 411dp** của lát "phạm vi
/// kỳ + lọc tiền" — cả hai đều hỏng **im lặng** nên 3200 ca cũ đều xanh:
///
/// 1. Câu trạng thái rỗng vẫn nói *"trong tháng này"*, là chữ còn sót lại từ
///    thời trang khoá theo tháng. Từ lát ấy trang xem được **tuần · tháng · quý
///    · năm · khoảng tuỳ chọn**, nên với bốn đơn vị còn lại câu ấy nói về một
///    khoảng thời gian **khác** thứ người dùng đang xem.
///
/// 2. Thẻ tổng in `+0 đ` và `-0 đ`. Dự án đã chốt **số 0 không mang dấu** và có
///    sẵn `CurrencyFormatter.formatCoDau` cho đúng việc này — luật ấy ra đời
///    ngày 2026-09-15 từ một lỗi y hệt ở bảng "Phân bổ theo ví", cũng do máy ảo
///    bắt được. Cột *Thu net* ở đây vốn đã dùng `formatCoDau` nên **đúng**, chỉ
///    hai cột kia gọi thẳng `formatIncome`/`formatExpense`; tức một thẻ đang
///    hiện hai quy ước cạnh nhau.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
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

/// Kỳ nào cũng rỗng — đúng trạng thái hai ca này nói về.
class _KyRongRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) =>
      Stream.value(const <TransactionEntity>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _KyRongRepository()),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ **BẮT BUỘC gọi ở cuối MỖI ca**, trong thân ca chứ không phải
  /// `addTearDown` — xem chú thích dài ở `so_giao_dich_chon_ky_test.dart`.
  /// Thiếu nó là **treo cả tệp**, không phải một ca đỏ.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '7',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
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

  testWidgets('câu trạng thái rỗng KHÔNG nói riêng về tháng', (tester) async {
    await moTrang(tester);

    expect(
      find.textContaining('tháng này'),
      findsNothing,
      reason: 'trang xem được tuần / quý / năm / khoảng tuỳ chọn, nên "tháng '
          'này" nói về một khoảng khác thứ đang hiện trên header — người dùng '
          'xem Quý 3 rỗng mà đọc được rằng "tháng này" chưa có gì',
    );
    expect(
      find.textContaining('kỳ này'),
      findsOneWidget,
      reason: 'câu thay thế phải đúng cho cả năm đơn vị; header ngay trên đã '
          'nói kỳ nào nên không cần nhắc lại tên kỳ',
    );

    await dongTrang(tester);
  });

  testWidgets('thẻ tổng của kỳ rỗng KHÔNG in "+0 đ" hay "-0 đ"',
      (tester) async {
    await moTrang(tester);

    expect(
      find.text('+0 đ'),
      findsNothing,
      reason: 'số 0 không mang dấu — "+0 đ" đọc như một con số dương bằng '
          'không; cùng luật đã áp cho bảng Phân bổ theo ví ngày 2026-09-15',
    );
    expect(
      find.text('-0 đ'),
      findsNothing,
      reason: 'như trên, và đây là vế dễ đọc nhầm hơn: "-0 đ" trông như một '
          'khoản chi',
    );
    expect(
      find.text('0 đ'),
      findsNWidgets(3),
      reason: 'ĐÒI KẾT QUẢ chứ không chỉ đòi vắng mặt: cả ba cột Thu nhập / '
          'Chi tiêu / Thu net phải hiện số 0 trần. Thiếu vế này thì một bản '
          'sai xoá hẳn thẻ tổng cũng làm hai kỳ vọng trên xanh',
    );

    await dongTrang(tester);
  });
}
