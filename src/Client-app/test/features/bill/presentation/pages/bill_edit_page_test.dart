/// Form sửa hoá đơn phải dựng được ở bề rộng điện thoại thật.
///
/// Vì sao cần: hai form hoá đơn không có widget test nào cho tới 2026-09-06,
/// và form Thêm hoá ra tràn ở **bốn** chỗ tại 411dp — không ai thấy vì bộ test
/// và skill `chay-app` đều chạy Chrome ở 1280px. Form Sửa dùng lại phần lớn bố
/// cục ấy nên phải có lưới an toàn riêng.
///
/// Form Sửa còn là **đường duy nhất trong app** để vá hoá đơn do bản client cũ
/// tạo ra (thiếu ví/danh mục, đang kẹt hàng đợi đẩy), nên nó hỏng là người
/// dùng mất luôn đường sửa.
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
import 'package:flowmoney/features/bill/presentation/pages/bill_edit_page.dart';

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

class _StubBillRepository implements BillRepository {
  @override
  Stream<List<Bill>> watchBills(int idaccount) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _hoaDon({DateTime? dueDate}) => Bill(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện tháng này',
      amount: 350000,
      startDate: DateTime(2026, 9, 4),
      dueDate: dueDate ?? DateTime(2026, 10, 4),
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 4),
    );

void main() {
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

  Future<void> dungTrangSua(WidgetTester tester, {Bill? bill}) async {
    tester.view.physicalSize = const Size(411, 2400);
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
    final blocBill = BillBloc(repository: _StubBillRepository());
    addTearDown(blocBill.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: blocBill),
      ],
      child: MaterialApp(
        home: BillEditPage(id: 'b1', bill: bill ?? _hoaDon()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không tràn bố cục ở 411dp', (tester) async {
    await dungTrangSua(tester);

    expect(tester.takeException(), isNull,
        reason: 'Form Sửa dùng lại bố cục của form Thêm, nơi đã tìm thấy bốn '
            'chỗ tràn ở bề rộng điện thoại thật.');
  });

  testWidgets('nạp sẵn giá trị của hoá đơn đang sửa', (tester) async {
    await dungTrangSua(tester);

    expect(find.text('Tiền điện tháng này'), findsOneWidget,
        reason: 'Tên hoá đơn phải điền sẵn, nếu không người dùng gõ lại từ đầu.');
  });

  testWidgets('hạn trả lệch chu kỳ thì cảnh báo trước khi lưu đè',
      (tester) async {
    // Bắt đầu 04/09 + chu kỳ tháng ⇒ hạn phải là 04/10. Hoá đơn này mang
    // 20/09, kiểu cửa sổ trả tuỳ ý mà bản client cũ và Admin-web tạo ra được.
    await dungTrangSua(tester, bill: _hoaDon(dueDate: DateTime(2026, 9, 20)));

    expect(
      find.textContaining('không khớp chu kỳ', skipOffstage: false),
      findsOneWidget,
      reason: 'Lưu lại là đổi hạn trả của người dùng. Đổi ngầm đúng lớp lỗi '
          'im lặng mà dự án đã dính nhiều lần.',
    );
  });

  testWidgets('chu kỳ là thanh chọn ngang như form Thêm, không phải dropdown',
      (tester) async {
    await dungTrangSua(tester);

    final o = [
      kBillCycleWeek,
      kBillCycleMonth,
      kBillCycleQuarter,
      kBillCycleYear,
    ]
        .map((v) => tester.getRect(find.byKey(ValueKey('bill-cycle-$v'))))
        .toList();

    expect(o.map((r) => r.top).toSet(), hasLength(1),
        reason: 'Form Thêm đã đổi sang thanh chọn phân đoạn ngang (06/09) '
            'còn form Sửa vẫn là `DropdownButtonFormField` — cùng một ô '
            'chu kỳ mà hai form hai kiểu.');
    expect(o.last.right, lessThanOrEqualTo(411),
        reason: 'Không tràn mép ở bề rộng điện thoại thật.');
    expect(find.byType(DropdownButtonFormField<String>), findsNothing,
        reason: 'Dropdown chu kỳ cũ phải đi hẳn, không được để hai bộ chọn '
            'cùng điều khiển một giá trị.');
  });

  testWidgets('chạm chu kỳ trên form Sửa thì ngày đến hạn tính lại',
      (tester) async {
    // Bắt đầu 04/09, chu kỳ tháng ⇒ hạn 04/10. Chọn quý ⇒ 04/12.
    await dungTrangSua(tester);

    await tester.tap(find.byKey(const ValueKey('bill-cycle-$kBillCycleQuarter')));
    await tester.pumpAndSettle();

    expect(find.text('04/12/2026'), findsOneWidget,
        reason: 'Ngày đến hạn luôn suy từ ngày bắt đầu + chu kỳ; đổi chu kỳ '
            'mà hạn không đổi là lựa chọn chưa ăn vào `BillSchedule`.');
  });
}
