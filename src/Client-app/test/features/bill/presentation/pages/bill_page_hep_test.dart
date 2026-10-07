/// G74 — thẻ hoá đơn ở màn HẸP (Realme để cỡ hiển thị lớn: mật độ 540 → 320 dp).
///
/// Quét 2026-10-07: số tiền chỉ còn *"100.0…"*, ngày hạn gãy *"Hạn 12/1 ⏎
/// 0/2026"*, tên *"Kiem t…"*. Đo bằng font thật ở 320 dp: chip *"CHƯA THANH
/// TOÁN"* (110 dp) để lại cho cột chữ 68 dp trong khi *"Hạn 25/09/2026"* cần
/// 107; nút *Thanh toán* (lề 24 mỗi bên) để lại cho số tiền 58 dp trong khi
/// *"100.000 đ"* cần 74. Ở 360 dp số tiền vừa **khít** 74/74 — G51 chỉ đo ở đó.
///
/// Người dùng chọn (2026-10-07): **chỉ xếp chồng khi chật** — đo bề rộng thật,
/// không vừa thì chip xuống dưới cột chữ và số tiền lên dòng riêng; màn rộng
/// giữ y như cũ.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
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
import 'package:flowmoney/features/bill/domain/bill_pay_status.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

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

Bill _bill({double amount = 100000, bool daTra = false}) => Bill(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Kiem tra dien',
      amount: amount,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 25),
      payStatus: daTra ? kBillPayed : kBillPending,
      isPaid: daTra,
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
    await napFontThat();
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

  /// Text của THẺ (không phải thẻ tổng / khối Nhận xét): lấy trong dòng hoá đơn.
  Finder trongThe(String chu) => find.descendant(
        of: find.byKey(const ValueKey('bill-row-b1')),
        matching: find.text(chu),
      );

  /// Chữ được vẽ trọn: không ellipsis, và không xuống dòng (bề rộng hộp chứa đủ
  /// bề rộng một dòng — `didExceedMaxLines` không bắt được ca gãy hai dòng của
  /// `maxLines: 2`).
  void veTron(WidgetTester tester, String chu, String vi) {
    final o = trongThe(chu);
    expect(o, findsOneWidget, reason: 'phải tìm đúng "$chu" trong thẻ hoá đơn');
    final rp = tester.renderObject<RenderParagraph>(o);
    expect(rp.didExceedMaxLines, isFalse, reason: '$vi: "$chu" bị cắt');
    expect(rp.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(rp.size.width + 0.5),
        reason: '$vi: "$chu" không vừa một dòng (gãy hoặc cụt)');
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G74 · $rong dp, chưa trả: số tiền, tên, ngày hạn đều vẽ trọn', (tester) async {
      await moTrang(tester, _bill(), rong);
      expect(tester.takeException(), isNull);
      veTron(tester, '100.000 đ', '$rong dp');
      veTron(tester, 'Kiem tra dien', '$rong dp');
      veTron(tester, 'Hạn 25/09/2026', '$rong dp');
      veTron(tester, 'CHƯA THANH TOÁN', '$rong dp');
      final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
      expect(nut.right, lessThanOrEqualTo(rong), reason: 'nút không tràn khỏi màn');
    });

    testWidgets('G74 · $rong dp, đã trả: số tiền và chip vẽ trọn', (tester) async {
      await moTrang(tester, _bill(daTra: true), rong);
      // Hoá đơn đã trả nằm ở tab "Lịch sử", không ở tab mở sẵn.
      await tester.tap(find.textContaining('Lịch sử'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      veTron(tester, '100.000 đ', '$rong dp đã trả');
      veTron(tester, 'ĐÃ THANH TOÁN', '$rong dp đã trả');
      veTron(tester, 'Hạn 25/09/2026', '$rong dp đã trả');
    });
  }

  testWidgets('G74 · 360 dp: dáng cũ GIỮ NGUYÊN — chip cùng hàng tên, số tiền cùng hàng nút',
      (tester) async {
    await moTrang(tester, _bill(), 360);
    expect(tester.takeException(), isNull);
    final ten = tester.getRect(trongThe('Kiem tra dien'));
    final chip = tester.getRect(trongThe('CHƯA THANH TOÁN'));
    expect(chip.top, lessThan(ten.bottom),
        reason: 'màn đủ chỗ thì chip vẫn ở góc phải, ngang hàng tên');
    expect(chip.left, greaterThan(ten.right));
    final soTien = tester.getRect(trongThe('100.000 đ'));
    final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
    expect((soTien.center.dy - nut.center.dy).abs(), lessThan(4),
        reason: 'màn đủ chỗ thì số tiền vẫn cùng hàng với nút Thanh toán');
  });

  testWidgets('G74 · 320 dp: chật thì chip xuống dưới tên, số tiền lên trên hàng nút',
      (tester) async {
    await moTrang(tester, _bill(), 320);
    final ten = tester.getRect(trongThe('Kiem tra dien'));
    final han = tester.getRect(trongThe('Hạn 25/09/2026'));
    final chip = tester.getRect(trongThe('CHƯA THANH TOÁN'));
    expect(chip.top, greaterThanOrEqualTo(han.bottom),
        reason: 'chip xếp dưới cột chữ để tên và ngày hạn được trọn bề ngang');
    // `chip` là hộp CHỮ, thụt 8 dp so với mép chip (lề trong).
    expect(chip.left - 8, closeTo(ten.left, 1), reason: 'chip thẳng lề với tên');
    final soTien = tester.getRect(trongThe('100.000 đ'));
    final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
    expect(soTien.bottom, lessThanOrEqualTo(nut.top),
        reason: 'số tiền lên dòng riêng, hàng dưới chỉ còn bút · thùng rác · nút');
    final but = tester.getRect(find.byIcon(Icons.edit));
    expect((but.center.dy - nut.center.dy).abs(), lessThan(4),
        reason: 'bút và thùng rác vẫn ở hàng nút');
  });

  testWidgets('G74 · 300 dp, số tiền 13 chữ số: vẫn ellipsis, không tràn', (tester) async {
    await moTrang(tester, _bill(amount: 9999999999999), 300);
    expect(tester.takeException(), isNull);
    final nut = tester.getRect(find.widgetWithText(ElevatedButton, 'Thanh toán'));
    expect(nut.right, lessThanOrEqualTo(300));
  });
}
