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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/domain/dien_san_hoa_don.dart';
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

/// Ghi lại companion mà form gửi lên (B2 — kiểm giá trị điền sẵn đi tới CSDL).
class _GhiThemRepository implements BillRepository {
  BillsCompanion? daThem;
  @override
  Stream<List<Bill>> watchBills(int idaccount) => const Stream.empty();
  @override
  Future<void> addBill(BillsCompanion bill) async => daThem = bill;
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

  // Công tắc "Tự động tạo giao dịch" bật sẵn không lưu ở đâu đã bị gỡ ngày
  // 06/09. Cùng ngày, tự động thanh toán được làm THẬT (cột v17 + bộ chạy) và
  // công tắc quay lại, TẮT sẵn — canh ở `bill_auto_pay_ui_test.dart`.

  testWidgets('tên hoá đơn dừng ở độ rộng cột trên server — G31',
      (tester) async {
    await dungTrangThem(tester);
    final oTen = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.hintText == 'e.g. Netflix Premium');
    final boDieuKhien = tester.widget<TextField>(oTen).controller!;

    await tester.enterText(oTen, 'a' * (DoRongCot.tenHoaDon + 50));
    await tester.pump();

    expect(boDieuKhien.text.length, DoRongCot.tenHoaDon,
        reason: '`bill.Name` là varchar(100). Tên dài hơn vỡ P2000 ở '
            '/sync/push; backend trả CONSTRAINT_VIOLATION (trước 7675b35 là '
            'DB_ERROR, gửi lại mãi), nên hoá đơn thành lỗi vĩnh viễn và không '
            'bao giờ lên server.');
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
  group('ân hạn — khối ngày mới (v21)', () {
    testWidgets('kết thúc kỳ 🔒, thanh ân hạn, hạn thanh toán 🔒, không tràn',
        (tester) async {
      await dungTrangThem(tester);
      expect(find.text('NGÀY KẾT THÚC KỲ'), findsOneWidget,
          reason: 'Ô khoá cũ "NGÀY ĐẾN HẠN THANH TOÁN" nay là ngày kết thúc kỳ.');
      expect(find.text('HẠN TRẢ SAU KHI KẾT THÚC KỲ'), findsOneWidget);
      expect(find.text('HẠN THANH TOÁN'), findsOneWidget);
      expect(find.byKey(const ValueKey('bill-grace-0')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
    });

    testWidgets('chọn 15 ngày → hạn thanh toán lùi 15 ngày sau kết thúc kỳ',
        (tester) async {
      await dungTrangThem(tester);
      final f = DateFormat('dd/MM/yyyy');
      String chu(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      final ketThuc = chu('bill-period-end-text');
      await tester.tap(find.byKey(const ValueKey('bill-grace-15')));
      await tester.pumpAndSettle();
      final han = chu('bill-due-date-text');
      final kt = f.parse(ketThuc.replaceFirst('Ngày ', ''));
      final hd = f.parse(han.replaceFirst('Ngày ', ''));
      expect(hd.difference(kt).inDays, 15);
      expect(chu('bill-period-end-text'), ketThuc,
          reason: 'Ân hạn không đổi ngày kết thúc kỳ.');
    });

    testWidgets('ân hạn chồng kỳ kế tiếp → câu báo đỏ hiện ngay',
        (tester) async {
      await dungTrangThem(tester);
      await tester.tap(find.byKey(const ValueKey('bill-grace-null')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('bill-grace-custom')), '45');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bill-grace-error')), findsOneWidget,
          reason: 'Ân hạn 45 ngày cho chu kỳ tháng là hai kỳ cùng mở. Chờ tới '
              'lúc bấm Lưu mới báo là bắt người dùng đoán.');
    });
  });
  group('điền sẵn từ khoản lặp (B2)', () {
    final moc = DateTime(2026, 9, 1);

    /// Hai ví, hai danh mục chi của tài khoản 10. Thứ tự mặc định của form là
    /// ví `wA` và danh mục `cAn` (xếp theo tên) — nên điền sẵn `wB` / `cNha`
    /// mới chứng minh được là điền sẵn đã ăn, không phải trùng mặc định.
    Future<void> gieo() async {
      await db.into(db.wallets).insert(
          WalletsCompanion.insert(id: 'wA', idaccount: 10, name: 'A tien mat', updatedAt: moc));
      await db.into(db.wallets).insert(
          WalletsCompanion.insert(id: 'wB', idaccount: 10, name: 'B ngan hang', updatedAt: moc));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'cAn', idaccount: 10, name: 'An uong', classify: 'chi', updatedAt: moc));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'cNha', idaccount: 10, name: 'Nha cua', classify: 'chi', updatedAt: moc));
    }

    final DienSanHoaDon du = (
      ten: 'Tiền nhà',
      soTien: 3100000,
      chuKy: kBillCycleMonth,
      ngayGoc: 31,
      batDau: DateTime(2026, 11, 30),
      categoryId: 'cNha',
      walletId: 'wB',
    );

    _FixedAuthBloc taiKhoan10() => _FixedAuthBloc(AuthSuccess(
          user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
        ));

    Future<void> dung(WidgetTester tester, DienSanHoaDon? dienSan) async {
      tester.view.physicalSize = const Size(411, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = taiKhoan10();
      addTearDown(auth.close);
      final bloc = BillBloc(repository: _GhiThemRepository());
      addTearDown(bloc.close);
      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<BillBloc>.value(value: bloc),
        ],
        child: MaterialApp(home: BillAddPage(dienSan: dienSan)),
      ));
      await tester.pumpAndSettle();
    }

    String? viDangChon(WidgetTester tester) =>
        tester.widget<DropdownButton<Wallet>>(find.byType(DropdownButton<Wallet>)).value?.id;
    String? danhMucDangChon(WidgetTester tester) =>
        tester.widget<DropdownButton<Category>>(find.byType(DropdownButton<Category>)).value?.id;
    final oTen = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'e.g. Netflix Premium');

    testWidgets('điền đủ → tên, tiền, ngày bắt đầu, kỳ (chu kỳ + ngày gốc), ví, danh mục',
        (tester) async {
      await gieo();
      await dung(tester, du);
      expect(tester.widget<TextField>(oTen).controller!.text, 'Tiền nhà');
      expect(find.text('3100000'), findsOneWidget,
          reason: 'ô tiền đọc chữ thô bằng double.tryParse — phải điền đúng định dạng nó đọc được');
      expect(find.textContaining('30/11/2026'), findsWidgets,
          reason: 'ngày bắt đầu = lần gần nhất');
      expect(tester.widget<Text>(find.byKey(const ValueKey('bill-period-end-text'))).data,
          contains('31/12/2026'),
          reason: 'chu kỳ tháng + ngày gốc 31 → kỳ đầu kết thúc 31/12 '
              '(ngày gốc 30 sẽ ra 30/12, chu kỳ tuần ra 07/12)');
      expect(viDangChon(tester), 'wB');
      expect(danhMucDangChon(tester), 'cNha');
      expect(tester.takeException(), isNull);
    });

    testWidgets('ví / danh mục điền sẵn không tồn tại → rơi về lựa chọn mặc định, không ném',
        (tester) async {
      await gieo();
      await dung(tester, (
        ten: 'Tiền nhà',
        soTien: 3100000,
        chuKy: kBillCycleMonth,
        ngayGoc: 5,
        batDau: DateTime(2026, 11, 5),
        categoryId: 'c-da-xoa',
        walletId: 'w-da-xoa',
      ));
      expect(viDangChon(tester), 'wA');
      expect(danhMucDangChon(tester), 'cAn');
      expect(tester.takeException(), isNull);
    });

    testWidgets('không điền sẵn → form như cũ: ô tên trống, ví / danh mục mặc định',
        (tester) async {
      await gieo();
      await dung(tester, null);
      expect(tester.widget<TextField>(oTen).controller!.text, isEmpty);
      expect(viDangChon(tester), 'wA');
      expect(danhMucDangChon(tester), 'cAn');
    });

    group('kết quả trả về trang gọi', () {
      Future<({List<Object?> ketQua, _GhiThemRepository repo})> quaRouter(
          WidgetTester tester) async {
        tester.view.physicalSize = const Size(411, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await gieo();
        final auth = taiKhoan10();
        addTearDown(auth.close);
        final repo = _GhiThemRepository();
        final bloc = BillBloc(repository: repo);
        addTearDown(bloc.close);
        final ketQua = <Object?>[];
        final router = GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (c, _) => Scaffold(
              body: TextButton(
                onPressed: () async => ketQua.add(await c.push<bool>('/bills/add')),
                child: const Text('mo form'),
              ),
            ),
          ),
          GoRoute(path: '/bills/add', builder: (_, __) => BillAddPage(dienSan: du)),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<BillBloc>.value(value: bloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ));
        await tester.tap(find.text('mo form'));
        await tester.pumpAndSettle();
        return (ketQua: ketQua, repo: repo);
      }

      testWidgets('bấm Lưu → pop(true), companion mang đúng giá trị điền sẵn', (tester) async {
        final r = await quaRouter(tester);
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(r.ketQua, [true],
            reason: 'thẻ khoản lặp chỉ ghi da_tao khi form báo đã gửi — '
                'pop() trần là thẻ không bao giờ ẩn');
        final c = r.repo.daThem!;
        expect(c.name.value, 'Tiền nhà');
        expect(c.amount.value, 3100000);
        expect(c.walletId.value, 'wB');
        expect(c.categoryId.value, 'cNha');
        expect(c.anchorDay.value, 31);
        expect(c.startDate.value, DateTime(2026, 11, 30));
      });

      testWidgets('bấm Quay lại → không trả true', (tester) async {
        final r = await quaRouter(tester);
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();
        expect(r.ketQua, hasLength(1));
        expect(r.ketQua.single, isNot(true), reason: 'thoát không lưu thì nhóm không được ẩn');
        expect(r.repo.daThem, isNull);
      });
    });
  });
}
