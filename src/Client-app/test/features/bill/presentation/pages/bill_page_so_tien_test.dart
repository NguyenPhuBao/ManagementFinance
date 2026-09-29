/// G51 — số tiền trên thẻ hoá đơn không được bị cắt khi còn chỗ.
///
/// Hàng dưới của thẻ từng là `Flexible(Text(amount))` · bút · thùng rác ·
/// `Spacer()` · nút Thanh toán: `Flexible` và `Spacer` cùng `flex: 1` nên CHIA
/// ĐÔI chỗ trống — số tiền bị trần ở một nửa dù `Spacer` sẵn sàng co về 0. Trên
/// Realme 360 dp mọi thẻ in *"10.0…"*, *"3.00…"* (nghiệm thu B2, 2026-09-29).
///
/// ⚠️ Font của bộ test rộng gấp đôi font thật (bẫy 4.4): ở 360 dp chuỗi nào cũng
/// cụt nên ca sẽ không phân biệt được gì — khổ đo được chọn bằng phép thử trên
/// bản cũ (cắt) và bản mới (không cắt).
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _FixedBillRepository implements BillRepository {
  _FixedBillRepository(this.bills);
  final List<Bill> bills;
  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);
  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => const {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _bill(double amount) => Bill(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Kiem',
      amount: amount,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 25),
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
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 9, 19, 10);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> moTrang(WidgetTester tester, Bill bill, double rong) async {
    tester.view.physicalSize = Size(rong, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(repository: _FixedBillRepository([bill]), now: () => now);
    addTearDown(bloc.close);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: BillPage(now: now)),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();
  }

  /// Chuỗi số tiền còn xuất hiện ở thẻ tổng quan và khối Nhận xét — lọc đúng
  /// `Text` của thẻ hoá đơn: một dòng, `ellipsis`, cỡ 16.
  bool biCat(WidgetTester tester, String chuoi) {
    final o = find.byWidgetPredicate((w) =>
        w is Text &&
        w.data == chuoi &&
        w.maxLines == 1 &&
        w.overflow == TextOverflow.ellipsis &&
        w.style?.fontSize == 16);
    expect(o, findsOneWidget, reason: 'phải tìm đúng Text số tiền của thẻ hoá đơn');
    return tester.renderObject<RenderParagraph>(o).didExceedMaxLines;
  }

  // Đo 2026-09-29 với font test: bản cũ cắt "100.000 đ" ở 411 · 500 · 600, không
  // cắt từ 700; bản sửa không cắt từ 500. 411 vẫn cắt vì font test rộng gấp đôi
  // (≈ 205 dp thật) — nên ca canh đứng ở 500 và 600.
  for (final rong in [500.0, 600.0]) {
    testWidgets('khổ $rong: số tiền KHÔNG bị cắt khi còn chỗ (G51)', (tester) async {
      await moTrang(tester, _bill(100000), rong);
      expect(biCat(tester, '100.000 đ'), isFalse,
          reason: 'Flexible(số tiền) cạnh Spacer cùng flex 1 thì chia đôi chỗ trống — '
              'trên Realme 360 dp mọi thẻ in "10.0…"');
    });
  }

  testWidgets('nút Thanh toán vẫn sát mép phải, bút đứng ngay sau số tiền', (tester) async {
    await moTrang(tester, _bill(100000), 600);
    final oSoTien = find.byWidgetPredicate(
        (w) => w is Text && w.data == '100.000 đ' && w.style?.fontSize == 16);
    final soTien = tester.getRect(oSoTien);
    // Đo bề rộng CHỮ, không đo hộp: số tiền `Expanded` thì hộp giãn tới sát bút
    // nên "hộp → bút" vẫn là 12 trong khi chữ đứng một đằng, bút một nẻo.
    final rongChu =
        tester.renderObject<RenderParagraph>(oSoTien).getMaxIntrinsicWidth(double.infinity);
    final but = tester.getRect(find.byIcon(Icons.edit));
    final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
    final dauThe = tester.getRect(find.text('Kiem'));
    expect(but.left - (soTien.left + rongChu), closeTo(12, 1),
        reason: 'bút và thùng rác đi liền sau số tiền, không bị đẩy sang sát nút');
    expect(nut.left, greaterThan(but.right + 24),
        reason: 'chỗ trống còn lại nằm giữa cụm số tiền và nút, không phải cuối hàng');
    expect(nut.right, lessThanOrEqualTo(600 - 16),
        reason: 'nút không tràn khỏi thẻ');
    expect(soTien.left, closeTo(dauThe.left, 60), reason: 'số tiền vẫn ở đầu hàng');
  });

  testWidgets('số tiền 13 chữ số ở 411: vẫn ellipsis, nút không bị đẩy ra ngoài', (tester) async {
    await moTrang(tester, _bill(9999999999999), 411);
    expect(tester.takeException(), isNull);
    final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
    expect(nut.right, lessThanOrEqualTo(411));
  });
}
