/// Giao diện của tự động thanh toán hoá đơn trên ba trang.
///
/// Vì sao cần: công tắc "Tự động tạo giao dịch" từng nằm trên form Thêm, BẬT
/// SẴN, và không lưu ở đâu (gỡ 06/09). Nay có cột thật và bộ chạy thật, nên
/// ba thứ phải đúng: công tắc **tắt sẵn** (tự chuyển tiền là quyết định người
/// dùng phải bật), form Sửa nạp và ghi được nó (đường duy nhất để TẮT), và
/// dòng danh sách cho biết hoá đơn nào đang tự trả.
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
import 'package:flowmoney/features/bill/presentation/pages/bill_add_page.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_edit_page.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';

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

/// Ghi lại companion mà form gửi lên, để test đọc được cờ.
class _GhiLaiRepository implements BillRepository {
  _GhiLaiRepository([this.bills = const []]);
  final List<Bill> bills;
  BillsCompanion? daSua;

  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);

  // Bloc đọc bản đồ khoản chi cùng lúc với danh sách; để rơi vào
  // `noSuchMethod` là trang không bao giờ tới `BillLoaded`.
  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => const {};

  @override
  Future<void> editBill(BillsCompanion bill) async => daSua = bill;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _hoaDon({required bool tuTra, DateTime? dueDate}) => Bill(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 350000,
      startDate: DateTime(2026, 9, 4),
      dueDate: dueDate ?? DateTime(2026, 10, 4),
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: tuTra,
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
  final now = DateTime(2026, 9, 6, 10);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
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
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> dung(WidgetTester tester, Widget trang,
      {required BillBloc bloc, double cao = 2400}) async {
    tester.view.physicalSize = Size(411, cao);
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
    addTearDown(bloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(home: trang),
    ));
    await tester.pumpAndSettle();
  }

  const khoa = ValueKey('bill-autopay-switch');

  group('form Thêm', () {
    testWidgets('có công tắc tự động thanh toán, TẮT sẵn', (tester) async {
      await dung(tester, const BillAddPage(),
          bloc: BillBloc(repository: _GhiLaiRepository()));

      final sw = tester.widget<Switch>(find.byKey(khoa));
      expect(sw.value, isFalse,
          reason: 'Bản trước bật sẵn. Bật sẵn là chuyển tiền dựa trên một lựa '
              'chọn người dùng chưa từng đưa ra — kể cả khi nay có bộ chạy '
              'thật đứng sau.');
      expect(find.textContaining('Tự động thanh toán'), findsOneWidget);
    });

    testWidgets('bật lên thì nói rõ trừ ví nào, lúc nào, và một thiết bị',
        (tester) async {
      await dung(tester, const BillAddPage(),
          bloc: BillBloc(repository: _GhiLaiRepository()));

      await tester.tap(find.byKey(khoa));
      await tester.pumpAndSettle();

      expect(find.textContaining('ví thanh toán', skipOffstage: false),
          findsWidgets);
      expect(find.textContaining('một thiết bị', skipOffstage: false),
          findsOneWidget,
          reason: 'Cột là cục bộ: hai máy cùng bật, cùng offline, cùng trả một '
              'kỳ là hai khoản chi. Phải nói trước, không để người dùng tự '
              'phát hiện qua số dư.');
      expect(tester.takeException(), isNull,
          reason: 'Dòng phụ dài không được làm tràn ở 411dp.');
    });
  });

  group('form Sửa', () {
    testWidgets('nạp sẵn trạng thái đang BẬT của hoá đơn', (tester) async {
      await dung(tester, BillEditPage(id: 'b1', bill: _hoaDon(tuTra: true)),
          bloc: BillBloc(repository: _GhiLaiRepository()));

      expect(tester.widget<Switch>(find.byKey(khoa)).value, isTrue);
    });

    testWidgets('tắt công tắc rồi Cập nhật thì companion mang cờ TẮT',
        (tester) async {
      final repo = _GhiLaiRepository();
      await dung(tester, BillEditPage(id: 'b1', bill: _hoaDon(tuTra: true)),
          bloc: BillBloc(repository: repo));

      await tester.tap(find.byKey(khoa));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật'));
      await tester.pumpAndSettle();
      // Form gửi sự kiện lên bloc RỒI mới `context.pop()`; harness không có
      // GoRouter nên bước pop ném assertion. Nuốt nó ở đây: thứ cần canh là
      // companion đã tới repository, không phải điều hướng.
      tester.takeException();

      expect(repo.daSua, isNotNull, reason: 'Form phải lưu được.');
      expect(repo.daSua!.autoPayEnabled.present, isTrue);
      expect(repo.daSua!.autoPayEnabled.value, isFalse,
          reason: 'Form Sửa là đường DUY NHẤT để tắt. Tắt mà không ăn xuống '
              'CSDL là app tiếp tục trừ tiền — lỗi tệ nhất ở vùng này.');
    });
  });

  group('danh sách', () {
    testWidgets('hoá đơn bật tự trả có dấu hiệu trên dòng', (tester) async {
      final bloc = BillBloc(
        repository: _GhiLaiRepository(
            [_hoaDon(tuTra: true, dueDate: DateTime(2026, 9, 20))]),
        now: () => now,
      );
      await dung(tester, BillPage(now: now), bloc: bloc, cao: 2000);
      bloc.add(LoadBillsEvent(idaccount: 10));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tự trả'), findsOneWidget,
          reason: 'Không có dấu hiệu thì người dùng phải mở từng hoá đơn để '
              'biết cái nào app sẽ tự trừ tiền.');
    });

    testWidgets('hoá đơn thường không có dấu hiệu ấy', (tester) async {
      final bloc = BillBloc(
        repository: _GhiLaiRepository(
            [_hoaDon(tuTra: false, dueDate: DateTime(2026, 9, 20))]),
        now: () => now,
      );
      await dung(tester, BillPage(now: now), bloc: bloc, cao: 2000);
      bloc.add(LoadBillsEvent(idaccount: 10));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tự trả'), findsNothing);
    });
  });
}
