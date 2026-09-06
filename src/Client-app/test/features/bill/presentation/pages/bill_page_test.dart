/// Danh sách hoá đơn phải nói đúng trạng thái của từng hoá đơn.
///
/// Vì sao cần: trang này chưa từng có widget test, và nó sai bốn chỗ cùng lúc.
/// Hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN HẠN" — nói nhẹ đi một việc đã
/// hỏng rồi — với vạch màu **xanh lá** của khoản thu. Hoá đơn thật sự sắp đến
/// hạn không có nhãn riêng nào. Thanh tiến độ là hằng số `0.66`. Và tổng tiền
/// gộp cả kỳ của tháng sau.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';

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

/// Trả về đúng danh sách được giao — không cần CSDL cho một test giao diện.
class _FixedBillRepository implements BillRepository {
  _FixedBillRepository(this.bills);
  final List<Bill> bills;

  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _bill({
  required String id,
  required DateTime dueDate,
  double amount = 100000,
  String name = 'Tiền điện',
  bool isPaid = false,
  String payStatus = 'Pending',
  String? timeNotification = '3',
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: name,
      amount: amount,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: payStatus,
      isPaid: isPaid,
      timeNotification: timeNotification,
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 9, 6, 10);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> dungTrang(WidgetTester tester, List<Bill> bills) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(repository: _FixedBillRepository(bills), now: () => now);
    addTearDown(bloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(home: BillPage(now: now)),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();
  }

  Color vachMau(WidgetTester tester, String id) {
    final c = tester.widget<Container>(find.byKey(ValueKey('bill-accent-$id')));
    return (c.decoration as BoxDecoration).color!;
  }

  testWidgets('hoá đơn quá hạn ghi "QUÁ HẠN", không phải "SẮP ĐẾN HẠN"',
      (tester) async {
    await dungTrang(tester, [_bill(id: 'a', dueDate: DateTime(2026, 9, 4))]);

    expect(find.text('QUÁ HẠN'), findsOneWidget);
    expect(
      find.text('SẮP ĐẾN HẠN'),
      findsNothing,
      reason: 'Nhánh quá hạn từng gán đúng nhãn "SẮP ĐẾN HẠN" — nói với người '
          'dùng rằng còn kịp trong khi họ đã trễ.',
    );
  });

  testWidgets('vạch màu của hoá đơn quá hạn là màu lỗi, không phải xanh lá',
      (tester) async {
    await dungTrang(tester, [_bill(id: 'a', dueDate: DateTime(2026, 9, 4))]);

    expect(
      vachMau(tester, 'a'),
      AppColors.error,
      reason: 'Vạch từng dùng `AppColors.income` — đúng màu xanh lá của khoản '
          'THU — cho một hoá đơn đã trễ hạn.',
    );
  });

  testWidgets('hoá đơn trong khoảng nhắc ghi "SẮP ĐẾN HẠN"', (tester) async {
    await dungTrang(tester, [_bill(id: 'a', dueDate: DateTime(2026, 9, 8))]);

    expect(find.text('SẮP ĐẾN HẠN'), findsOneWidget,
        reason: 'Bản dựng hình Stitch có nhãn này nhưng không hoá đơn nào từng '
            'nhận được nó.');
  });

  testWidgets('hoá đơn còn xa hạn ghi "CHƯA THANH TOÁN"', (tester) async {
    await dungTrang(tester, [_bill(id: 'a', dueDate: DateTime(2026, 9, 25))]);

    expect(find.text('CHƯA THANH TOÁN'), findsOneWidget);
  });

  testWidgets('hoá đơn đã trả theo cột payStatus cũng hiện là đã trả',
      (tester) async {
    await dungTrang(tester, [
      _bill(id: 'a', dueDate: DateTime(2026, 9, 25), payStatus: 'Payed'),
    ]);

    expect(find.text('ĐÃ THANH TOÁN'), findsOneWidget,
        reason: 'Hàng do bản client cũ ghi mang `payStatus = Payed` mà `isPaid` '
            'còn false. Chỉ đọc `isPaid` là bày nút "Thanh toán" cho hoá đơn '
            'đã trả.');
    expect(find.text('Thanh toán'), findsNothing);
  });

  testWidgets('thẻ tổng chỉ tính tới hết tháng này', (tester) async {
    await dungTrang(tester, [
      _bill(id: 'a', dueDate: DateTime(2026, 9, 11), amount: 50000),
      _bill(id: 'b', dueDate: DateTime(2026, 9, 23), amount: 10000),
      _bill(id: 'c', dueDate: DateTime(2026, 10, 4), amount: 123000),
    ]);

    expect(find.textContaining('60.000'), findsOneWidget,
        reason: 'Gộp cả kỳ tháng sau thì thẻ hiện 183.000 đ trong khi tháng '
            'này chỉ nợ 60.000 đ.');
    expect(find.textContaining('2 hóa đơn chưa thanh toán'), findsOneWidget);
  });

  testWidgets('thanh tiến độ đo tỉ lệ đã trả, không phải hằng số 0,66',
      (tester) async {
    await dungTrang(tester, [
      _bill(
          id: 'a',
          dueDate: DateTime(2026, 9, 4),
          amount: 30000,
          isPaid: true,
          payStatus: 'Payed'),
      _bill(id: 'b', dueDate: DateTime(2026, 9, 20), amount: 70000),
    ]);

    final bar = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('bill-progress')));
    expect(bar.widthFactor, closeTo(0.3, 0.0001),
        reason: 'Thanh cứng 0,66 chỉ có hai trạng thái và không đo gì cả.');
  });

  testWidgets('không tràn bố cục ở 411dp', (tester) async {
    await dungTrang(tester, [
      _bill(
          id: 'a',
          dueDate: DateTime(2026, 9, 4),
          amount: 123456789,
          name: 'Hoá đơn có cái tên rất dài để thử tràn bố cục'),
    ]);

    expect(tester.takeException(), isNull);
  });
}
