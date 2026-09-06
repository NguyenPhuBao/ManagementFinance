/// Danh sách hoá đơn phải nói đúng trạng thái của từng hoá đơn.
///
/// Vì sao cần: trang này chưa từng có widget test, và nó sai bốn chỗ cùng lúc.
/// Hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN HẠN" — nói nhẹ đi một việc đã
/// hỏng rồi — với vạch màu **xanh lá** của khoản thu. Hoá đơn thật sự sắp đến
/// hạn không có nhãn riêng nào. Thanh tiến độ là hằng số `0.66`. Và tổng tiền
/// gộp cả kỳ của tháng sau.
library;

import 'package:drift/drift.dart' as drift;
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

  // Bloc đọc bản đồ khoản chi cùng lúc với danh sách; để rơi vào
  // `noSuchMethod` là trang không bao giờ tới `BillLoaded`.
  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => const {};

  /// Luôn hỏng — để dựng được trạng thái `BillError` mà không cần CSDL.
  @override
  Future<void> undoPayment({required String billId}) async =>
      throw const BillUndoUnavailableException('b');

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
      autoPayEnabled: false,
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

  /// Gieo một ví và một danh mục để trang tra được tên.
  Future<void> gieoViVaDanhMuc() async {
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w2',
      idaccount: 10,
      name: 'Tiết kiệm',
      balance: const drift.Value(2000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c1',
      idaccount: 10,
      name: 'Điện nước',
      classify: 'chi',
      icon: const drift.Value('receipt'),
      colour: const drift.Value('#4CAF50'),
      updatedAt: DateTime(2026, 9, 1),
    ));
  }

  Future<void> dungTrang(
    WidgetTester tester,
    List<Bill> bills, {
    bool seed = false,
  }) async {
    if (seed) await gieoViVaDanhMuc();

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

    // Hàng do bản client cũ ghi mang `payStatus = Payed` mà `isPaid` còn
    // false. Chỉ đọc `isPaid` là xếp nó vào nhóm cần trả, bày nút "Thanh
    // toán", và cộng luôn vào tổng nợ.
    expect(find.text('Cần thanh toán (0)'), findsOneWidget);
    expect(find.text('Thanh toán'), findsNothing);

    await tester.tap(find.text('Đã thanh toán (1)'));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ THANH TOÁN'), findsOneWidget);
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

  testWidgets('hai tab: hoá đơn đã trả không nằm lẫn trong nhóm cần trả',
      (tester) async {
    await dungTrang(tester, [
      _bill(id: 'a', dueDate: DateTime(2026, 9, 11), name: 'Kiem'),
      _bill(
          id: 'b',
          dueDate: DateTime(2026, 9, 16),
          name: 'Da tra roi',
          isPaid: true,
          payStatus: 'Payed'),
      _bill(id: 'c', dueDate: DateTime(2026, 9, 23), name: 'Con phai tra'),
    ]);

    expect(find.text('Kiem'), findsOneWidget);
    expect(find.text('Con phai tra'), findsOneWidget);
    expect(
      find.text('Da tra roi'),
      findsNothing,
      reason: 'Mỗi kỳ là một hàng mới, nên lịch sử đã trả trôi lẫn vào giữa '
          'những hoá đơn đang chờ — trên máy thật kỳ đã trả của "di h0c" nằm '
          'đúng giữa hai hoá đơn chưa trả.',
    );

    await tester.tap(find.textContaining('Đã thanh toán'));
    await tester.pumpAndSettle();

    expect(find.text('Da tra roi'), findsOneWidget);
    expect(find.text('Kiem'), findsNothing);
  });

  testWidgets('dòng hoá đơn cho biết danh mục và ví thanh toán',
      (tester) async {
    await dungTrang(
      tester,
      [_bill(id: 'a', dueDate: DateTime(2026, 9, 11))],
      seed: true,
    );

    expect(
      find.textContaining('Điện nước'),
      findsOneWidget,
      reason: 'Sổ giao dịch hiện "Danh mục • Ví" từ 06/09; hoá đơn chỉ có tên '
          'và hạn, nên không biết khoản chi này rơi vào danh mục nào.',
    );
    expect(
      find.textContaining('Tiền mặt'),
      findsOneWidget,
      reason: 'Ví thanh toán đã lưu sẵn trên hoá đơn nhưng không hiện ở đâu — '
          'phải bấm "Thanh toán" mới biết tiền trừ vào đâu.',
    );
  });

  testWidgets('danh mục đã xoá thì nói "đã xoá", không nói "chưa có"',
      (tester) async {
    // Đợt gộp danh mục 2026-09-05 xoá mềm năm danh mục riêng; hai hoá đơn của
    // tài khoản 10 vẫn trỏ vào hàng cũ. Bảng tra không thấy chúng nữa.
    await dungTrang(
      tester,
      [_bill(id: 'a', dueDate: DateTime(2026, 9, 11))],
      seed: false,
    );

    expect(
      find.textContaining('Danh mục đã xoá'),
      findsOneWidget,
      reason: 'Hoá đơn CÓ `categoryId` nhưng hàng danh mục đã bị xoá mềm — '
          'khác hẳn với hoá đơn chưa từng gán danh mục, và là thứ người dùng '
          'cần sửa vì khoản chi sinh ra sẽ rơi vào một danh mục không còn.',
    );
  });

  testWidgets('bảng chọn ví đưa ví của hoá đơn lên đầu và đánh dấu',
      (tester) async {
    await dungTrang(
      tester,
      [_bill(id: 'a', dueDate: DateTime(2026, 9, 11))],
      seed: true,
    );

    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ví của hoá đơn'),
      findsOneWidget,
      reason: 'Hoá đơn đã lưu ví thanh toán, nhưng luồng trả bắt chọn lại từ '
          'một danh sách không gợi ý gì.',
    );
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title as Text).data, 'Tiền mặt',
        reason: 'Ví của hoá đơn phải nằm đầu danh sách.');
  });

  testWidgets('bảng thanh toán điền sẵn số tiền của hoá đơn, sửa được',
      (tester) async {
    await dungTrang(
      tester,
      [_bill(id: 'a', dueDate: DateTime(2026, 9, 11), amount: 200000)],
      seed: true,
    );

    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();

    final o = tester.widget<TextField>(
        find.byKey(const ValueKey('bill-pay-amount')));
    expect(
      o.controller!.text,
      '200000',
      reason: 'Hoá đơn điện nước mỗi kỳ một số khác nhau. Số thô, không dấu '
          'chấm, để `CurrencyFormatter.parse` đọc như khi người dùng tự gõ — '
          'cùng quy ước với nút "Dùng số này" của form ngân sách.',
    );
  });

  testWidgets('chỉ hoá đơn đã trả mới có nút Hoàn tác', (tester) async {
    await dungTrang(tester, [
      _bill(id: 'a', dueDate: DateTime(2026, 9, 11)),
      _bill(
          id: 'b',
          dueDate: DateTime(2026, 9, 4),
          name: 'Da tra',
          isPaid: true,
          payStatus: 'Payed'),
    ]);

    expect(find.byKey(const ValueKey('bill-undo-a')), findsNothing,
        reason: 'Hoá đơn chưa trả thì không có gì để hoàn tác.');

    await tester.tap(find.text('Đã thanh toán (1)'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('bill-undo-b')),
      findsOneWidget,
      reason: 'Trả nhầm trước đây là kẹt hẳn: khoản chi bị chặn xoá ở sổ, hoá '
          'đơn không có đường về Pending, kỳ kế tiếp đã sinh ra rồi.',
    );
  });

  testWidgets('hoàn tác hỏi xác nhận và nói rõ ba hệ quả', (tester) async {
    await dungTrang(tester, [
      _bill(
          id: 'b',
          dueDate: DateTime(2026, 9, 4),
          name: 'Da tra',
          isPaid: true,
          payStatus: 'Payed'),
    ]);
    await tester.tap(find.text('Đã thanh toán (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bill-undo-b')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hoàn'), findsWidgets);
    expect(find.textContaining('gỡ kỳ kế tiếp'), findsOneWidget,
        reason: 'Hoàn tác đụng tới ba thứ (ví, khoản chi, kỳ sau) nên phải '
            'nói trước, không im lặng làm.');
  });

  testWidgets('báo lỗi KHÔNG được làm trắng cả trang', (tester) async {
    await dungTrang(tester, [
      _bill(
          id: 'b',
          dueDate: DateTime(2026, 9, 4),
          name: 'Da tra',
          isPaid: true,
          payStatus: 'Payed'),
    ]);
    await tester.tap(find.text('Đã thanh toán (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bill-undo-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hoàn tác'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'Lý do phải hiện ra.');
    expect(
      find.text('Da tra'),
      findsOneWidget,
      reason: '`BillError` và `BillOperationSuccess` là trạng thái THOÁNG QUA. '
          'Builder chỉ dựng cho `BillLoaded` rồi rơi xuống `SizedBox.shrink()` '
          'nên mọi thông báo đều xoá trắng danh sách — và không có gì dựng lại '
          'cho tới khi stream phát trạng thái mới, thứ không xảy ra khi thao '
          'tác thất bại. Thấy trên máy ảo 2026-09-06.',
    );
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
