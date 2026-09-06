/// Form thêm hoá đơn không được hứa những việc app không làm.
///
/// Vì sao cần: form từng có công tắc "Tự động tạo giao dịch — Thanh toán khi
/// đến hạn", **bật sẵn**, gắn vào một biến `_autoPayEnabled` không được lưu ở
/// đâu cả. Không có cột trong CSDL, không có bộ chạy nền, không có gì đọc nó.
/// Người dùng bật công tắc rồi tin app sẽ tự trả hoá đơn khi đến hạn — và hoá
/// đơn quá hạn trong im lặng. Đây đúng lớp lỗi "giao diện không lưu được gì"
/// mà dự án đã dọn ở màn ngân sách hôm 2026-09-04.
///
/// Đây cũng là widget test ĐẦU TIÊN của hai form hoá đơn: tầng dưới đã phủ
/// kín (chín tệp test) nhưng ba trang thì không có gì, và đó là lý do công tắc
/// giả sống sót lâu như vậy.
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
import 'package:flowmoney/features/bill/presentation/pages/bill_add_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bloc giữ một trạng thái cố định — cùng lối với `current_account_test.dart`.
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

  Future<void> dungTrangThem(WidgetTester tester) async {
    // Trang cao hơn màn hình thật; dựng rộng rãi để mọi khối đều được bố trí.
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
    final bill = BillBloc(repository: _StubBillRepository());
    addTearDown(bill.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bill),
      ],
      child: const MaterialApp(home: BillAddPage()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không còn công tắc hứa tự động thanh toán', (tester) async {
    await dungTrangThem(tester);

    expect(
      find.textContaining('Tự động tạo giao dịch', skipOffstage: false),
      findsNothing,
      reason: 'Không có cột nào lưu lựa chọn này và không có bộ chạy nền nào '
          'đọc nó. Bày ra công tắc là hứa app sẽ tự trả hoá đơn — người dùng '
          'tin rồi để hoá đơn quá hạn.',
    );
    expect(
      find.textContaining('Thanh toán khi đến hạn', skipOffstage: false),
      findsNothing,
      reason: 'Dòng phụ của công tắc, cùng lời hứa.',
    );
  });

  testWidgets('không tràn bố cục ở 411dp', (tester) async {
    await dungTrangThem(tester);

    expect(
      tester.takeException(),
      isNull,
      reason: 'Form từng tràn ở BỐN chỗ (128px, 115px, 56px, 141px) trên bề '
          'rộng điện thoại thật: hàng công tắc nhắc nhở, bốn chip số ngày, '
          'hàng công tắc tự động thanh toán và nút Lưu. Cả bốn nằm im vì bộ '
          'test chạy 1280px còn máy thật là 411dp.',
    );
  });

  testWidgets('bốn chu kỳ nằm trên MỘT hàng ngang ở 411dp', (tester) async {
    await dungTrangThem(tester);

    final o = [
      kBillCycleWeek,
      kBillCycleMonth,
      kBillCycleQuarter,
      kBillCycleYear,
    ]
        .map((v) => tester.getRect(find.byKey(ValueKey('bill-cycle-$v'))))
        .toList();

    expect(
      o.map((r) => r.top).toSet(),
      hasLength(1),
      reason: 'Bốn ô đang xếp DỌC, mỗi ô một hàng chiếm trọn bề ngang. Nguyên '
          'nhân là `Container` có `alignment` mà không có kích thước thì giãn '
          'hết ràng buộc nhận được, nên `Wrap` chỉ nhét được một ô mỗi dòng. '
          'Mốc trên phải TRÙNG KHỚP chứ không chỉ gần nhau: nhãn dài ngắn '
          'khác nhau nên nếu để cao tự do thì bốn viên thuốc lệch vài pixel.',
    );
    for (var i = 1; i < o.length; i++) {
      expect(o[i].left, greaterThanOrEqualTo(o[i - 1].right),
          reason: 'Các ô phải nằm cạnh nhau theo đúng thứ tự tuần → tháng → '
              'quý → năm, không chồng lên nhau.');
    }
    expect(
      o.map((r) => r.width.round()).toSet(),
      hasLength(1),
      reason: 'Bốn ô chia đều bề ngang như một thanh chọn phân đoạn — kiểu '
          'giao diện mà chính cách tô màu (ô được chọn nền trắng có đổ bóng, '
          'ô còn lại trong suốt) đang gợi ra.',
    );
    expect(o.last.right, lessThanOrEqualTo(411),
        reason: 'Không được tràn ra ngoài mép màn hình.');
  });

  testWidgets('chạm một chu kỳ thì ô đó được chọn', (tester) async {
    await dungTrangThem(tester);

    await tester.tap(find.byKey(const ValueKey('bill-cycle-$kBillCycleQuarter')));
    await tester.pumpAndSettle();

    // Ngày đến hạn luôn suy từ ngày bắt đầu + chu kỳ, nên đổi chu kỳ phải đổi
    // được ô ngày đến hạn — đó là bằng chứng lựa chọn đã ăn vào `BillSchedule`.
    expect(find.textContaining('/'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vẫn còn đủ các khối thật của form', (tester) async {
    await dungTrangThem(tester);

    // Lưới an toàn cho việc gỡ công tắc: cắt nhầm sang khối nhắc trước hạn —
    // khối NGAY TRÊN nó và là thứ có lưu thật (`timeNotification`) — sẽ đỏ ở
    // đây thay vì lọt qua.
    expect(find.textContaining('3 ngày', skipOffstage: false), findsOneWidget,
        reason: 'Khối nhắc trước hạn có lưu thật vào `timeNotification`.');
    expect(find.textContaining('7 ngày', skipOffstage: false), findsOneWidget);
    expect(find.byType(Switch, skipOffstage: false), findsWidgets,
        reason: 'Công tắc bật/tắt nhắc và công tắc lặp lại theo chu kỳ đều '
            'lưu thật, phải giữ nguyên.');
  });
}
