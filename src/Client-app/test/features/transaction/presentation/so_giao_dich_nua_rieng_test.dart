/// Trang Sổ giao dịch nối cổng `CapGopQuyNguon` vào bảng chi tiết (Sửa, Xoá) và dòng (vuốt) — đợt 1B Task 9.
///
/// Vì sao cần: `TransactionListRow` / `TransactionDetailSheet` nhận cổng qua tham số TUỲ CHỌN. Trang quên truyền thì mọi
/// ca widget của hai widget ấy vẫn xanh, còn trên máy nửa riêng của khoản góp vẫn sửa, xoá MỘT mình — quỹ một số, ví
/// riêng một số khác, im lặng.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/cap_gop_quy_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/bat_thong_bao.dart';
import '../../../helpers/nguon_doc_gia.dart';

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

/// Kỳ nào cũng trả đúng một khoản; đếm lần `deleteTransaction` (đường xoá MỘT nửa).
class _MotKhoanRepository implements TransactionRepository {
  _MotKhoanRepository(this._khoan);

  final TransactionEntity _khoan;
  var soLanXoaMotNua = 0;

  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) => Stream.value([_khoan]);

  @override
  Future<void> deleteTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    soLanXoaMotNua++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _MotKhoanRepository repo;
  late BatThongBao bat;
  final now = DateTime.now();
  final nuaRieng = TransactionEntity(
    id: 'tx-nua-rieng',
    walletId: 'w',
    idaccount: 7,
    fundPairId: 'cap-1',
    amount: 200000,
    type: 'chi',
    note: 'Góp quỹ · Quỹ chợ',
    date: now,
    updatedAt: now,
  );

  setUp(() async {
    await initializeDateFormatting('vi');
    bat = batThongBao();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    repo = _MotKhoanRepository(nuaRieng);
    sl.registerFactory<TransactionBloc>(() => TransactionBloc(transactionRepository: repo));
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

  Future<void> moTrang(WidgetTester tester, {CapGopQuyNguon? nguon}) async {
    if (nguon != null) sl.registerSingleton<CapGopQuyNguon>(nguon);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(value: auth, child: const TransactionPage()),
      ),
      GoRoute(
        path: '/nha/gop',
        builder: (_, s) => Scaffold(body: Text('GOP ma=${s.uri.queryParameters['ma']} che=${s.uri.queryParameters['che']}')),
      ),
      GoRoute(path: '/add', builder: (_, __) => const Scaffold(body: Text('FORM-ADD'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
  }

  CapGopQuyNguon nguonCo({bool choThaoTac = true, List<String>? daXoa, bool laGop = true}) => CapGopQuyNguon(
        doc: (_) async => CapGopQuy(maCap: 'cap-1', laGop: laGop, cauXoa: 'Quỹ chợ cũng giảm 200.000 đ.', choThaoTac: choThaoTac),
        xoa: (m) async => daXoa?.add(m),
      );

  Finder dong() => find.byKey(const Key('tx-nua-rieng'));

  Future<void> chamDong(WidgetTester tester) async {
    await tester.ensureVisible(dong());
    await tester.pumpAndSettle();
    await tester.tap(dong());
    await tester.pumpAndSettle();
  }

  testWidgets('Sửa nửa riêng còn cặp: đẩy /nha/gop?ma=…&che=gop, KHÔNG /add', (tester) async {
    await moTrang(tester, nguon: nguonCo());
    await chamDong(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();

    expect(find.text('GOP ma=cap-1 che=gop'), findsOneWidget,
        reason: 'Sửa một nửa của cặp ở form thường là hai nửa lệch nhau: phải sang màn sửa theo cả cặp.');
    expect(find.text('FORM-ADD'), findsNothing);
    await dongTrang(tester);
  });

  testWidgets('Sửa nửa riêng của khoản rút: che=rut', (tester) async {
    await moTrang(tester, nguon: nguonCo(laGop: false));
    await chamDong(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('GOP ma=cap-1 che=rut'), findsOneWidget);
    await dongTrang(tester);
  });

  testWidgets('Xoá nửa riêng còn cặp: hộp mang câu của cặp, gọi xoaCap, KHÔNG phát DeleteTransactionEvent', (tester) async {
    final daXoa = <String>[];
    await moTrang(tester, nguon: nguonCo(daXoa: daXoa));
    await chamDong(tester);
    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pumpAndSettle();

    expect(find.text('Xoá khoản góp?'), findsOneWidget);
    expect(find.text('Quỹ chợ cũng giảm 200.000 đ.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(daXoa, ['cap-1']);
    expect(repo.soLanXoaMotNua, 0, reason: 'DeleteTransactionEvent gỡ một nửa → lệch cặp.');
    expect(bat.cau, ['Đã xóa giao dịch']);
    await dongTrang(tester);
  });

  testWidgets('vuốt xoá nửa riêng còn cặp: cũng xoaCap, không xoá một nửa', (tester) async {
    final daXoa = <String>[];
    await moTrang(tester, nguon: nguonCo(daXoa: daXoa));
    await tester.ensureVisible(dong());
    await tester.pumpAndSettle();
    await tester.drag(dong(), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Xoá khoản góp?'), findsOneWidget,
        reason: 'Trang phải truyền hoiCap xuống TransactionListRow; quên là vuốt xoá một nửa im lặng.');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(daXoa, ['cap-1']);
    expect(repo.soLanXoaMotNua, 0);
    await dongTrang(tester);
  });

  testWidgets('nhà chỉ xem: bảng không có Sửa, Xoá; vuốt bị từ chối', (tester) async {
    await moTrang(tester, nguon: nguonCo(choThaoTac: false));
    await chamDong(tester);
    expect(find.text('Sửa giao dịch'), findsNothing);
    expect(find.text('Xoá giao dịch'), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // đóng bảng
    await tester.pumpAndSettle();

    await tester.ensureVisible(dong());
    await tester.pumpAndSettle();
    await tester.drag(dong(), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(bat.cuoi?.cau, 'Nhà đang ở chế độ chỉ xem.');
    expect(repo.soLanXoaMotNua, 0);
    await dongTrang(tester);
  });

  testWidgets('đã rời nhà (cổng trả null): Sửa đi /add như khoản thường', (tester) async {
    await moTrang(tester, nguon: CapGopQuyNguon(doc: (_) async => null, xoa: (_) async {}));
    await chamDong(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('FORM-ADD'), findsOneWidget, reason: 'Sau khi rời nhà nửa riêng là khoản thường (02A mục 6).');
    await dongTrang(tester);
  });

  testWidgets('chưa đăng ký cổng: đường cũ, Sửa đi /add', (tester) async {
    await moTrang(tester);
    await chamDong(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('FORM-ADD'), findsOneWidget);
    await dongTrang(tester);
  });
}
