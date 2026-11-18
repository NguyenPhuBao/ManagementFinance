/// Sổ giao dịch hiện khoản của NHÀ do tôi ghi (spec 2026-11-16 mục 3): dòng có nhãn nhà + tên ví chung; thẻ tổng KHÔNG cộng
/// khoản nhà; bấm dòng → sửa qua `/nha/khoan` khi được quyền, chỉ xem khi không; xoá đi đường của nhà, không bao giờ
/// `DeleteTransactionEvent` (xoá thẳng repository là bỏ qua vai).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/khoan_nha_cho_so_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart' show EditTransactionArgs;
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../helpers/bat_thong_bao.dart';
import '../../../helpers/nguon_doc_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

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

/// Danh sách Sổ = riêng + nhà; đếm `deleteTransaction` (đường xoá thẳng — khoản nhà KHÔNG được đi đường này).
class _SoRepository implements TransactionRepository {
  _SoRepository(this._ds);

  final List<TransactionEntity> _ds;
  var soLanXoaThang = 0;

  @override
  Stream<List<TransactionEntity>> watchKhoangKemNha(int idaccount, DateTime from, DateTime to) => Stream.value(_ds);

  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) =>
      Stream.value([for (final t in _ds) if (t.idhousehold == null) t]);

  @override
  Future<void> deleteTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    soLanXoaThang++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _SoRepository repo;
  late BatThongBao bat;
  Object? extraSua;
  final now = DateTime.now();
  final rieng = TransactionEntity(
    id: 'tx-rieng',
    walletId: 'w-rieng',
    idaccount: 7,
    amount: 100000,
    type: 'chi',
    note: 'Cà phê',
    date: now,
    updatedAt: now,
  );
  final nha = TransactionEntity(
    id: 'tx-nha',
    walletId: 'nha-v',
    idaccount: 7,
    idhousehold: 12,
    categoryId: 'nha-food',
    amount: 500000,
    type: 'chi',
    note: 'Đi chợ sáng',
    date: now,
    updatedAt: now,
  );

  setUp(() async {
    await initializeDateFormatting('vi');
    bat = batThongBao();
    extraSua = null;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    repo = _SoRepository([nha, rieng]);
    sl.registerFactory<TransactionBloc>(() => TransactionBloc(transactionRepository: repo));
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ BẮT BUỘC gọi ở cuối MỖI ca, trong thân ca — thiếu là treo cả tệp (bẫy 7.13).
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  KhoanNhaChoSoNguon cong({bool sua = true, bool xoa = true, List<String>? daXoa}) => KhoanNhaChoSoNguon(
        traTen: (_) => Stream.value(TraTenNha(
          idNha: 12,
          tenNha: 'Nhà An Bình',
          vi: [makeWallet(id: 'nha-v', name: 'Tiền chợ')],
          danhMuc: [makeCategory(id: 'nha-food', name: 'Ăn uống', idaccount: 0)],
        )),
        quyen: (_) async => (sua: sua, xoa: xoa),
        xoa: (t) async => daXoa?.add(t.id),
      );

  Future<void> moTrang(WidgetTester tester, KhoanNhaChoSoNguon? nguon) async {
    if (nguon != null) sl.registerSingleton<KhoanNhaChoSoNguon>(nguon);
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
        path: '/nha/khoan',
        builder: (_, s) {
          extraSua = s.extra;
          return const Scaffold(body: Text('FORM-NHA'));
        },
      ),
      GoRoute(path: '/add', builder: (_, __) => const Scaffold(body: Text('FORM-ADD'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
  }

  Finder dongNha() => find.byKey(const Key('tx-nha'));

  Future<void> chamDongNha(WidgetTester tester) async {
    await tester.ensureVisible(dongNha());
    await tester.pumpAndSettle();
    await tester.tap(dongNha());
    await tester.pumpAndSettle();
  }

  testWidgets('dòng nhà có nhãn nhà + tên ví chung; thẻ tổng chỉ cộng khoản riêng', (tester) async {
    await moTrang(tester, cong());
    expect(find.text('Nhà An Bình'), findsOneWidget, reason: 'viên nhãn nhà trên dòng khoản của nhà');
    expect(find.text('Ăn uống • Tiền chợ'), findsOneWidget, reason: 'tên ví chung tra từ bảng của nhà, không "Ví đã xoá"');
    expect(find.textContaining('500.000'), findsOneWidget, reason: 'chỉ ở dòng nhà — không ở thẻ tổng');
    expect(find.textContaining('100.000'), findsWidgets, reason: 'khoản riêng có ở dòng và thẻ tổng');
    await dongTrang(tester);
  });

  testWidgets('bấm dòng nhà, được sửa → Sửa đẩy /nha/khoan với đúng khoản, KHÔNG /add', (tester) async {
    await moTrang(tester, cong());
    await chamDongNha(tester);
    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('FORM-NHA'), findsOneWidget);
    expect(find.text('FORM-ADD'), findsNothing);
    expect(extraSua, isA<EditTransactionArgs>());
    expect((extraSua! as EditTransactionArgs).transaction.id, 'tx-nha');
    await dongTrang(tester);
  });

  testWidgets('không được sửa / xoá → sheet chỉ xem, không nút Sửa / Xoá', (tester) async {
    await moTrang(tester, cong(sua: false, xoa: false));
    await chamDongNha(tester);
    expect(find.text('Bạn chỉ xem được khoản này của nhà.'), findsOneWidget);
    expect(find.text('Sửa giao dịch'), findsNothing);
    expect(find.text('Xoá giao dịch'), findsNothing);
    await dongTrang(tester);
  });

  testWidgets('Xoá ở sheet → đi cổng nhà sau xác nhận, KHÔNG xoá thẳng repository', (tester) async {
    final daXoa = <String>[];
    await moTrang(tester, cong(daXoa: daXoa));
    await chamDongNha(tester);
    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá khoản này?'), findsOneWidget);
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    expect(daXoa, ['tx-nha']);
    expect(repo.soLanXoaThang, 0, reason: 'xoá thẳng qua repository là bỏ qua vai của nhà');
    expect(bat.cau, contains('Đã xoá khoản.'));
    await dongTrang(tester);
  });

  testWidgets('vuốt xoá dòng nhà khi KHÔNG được xoá → báo, không xoá gì', (tester) async {
    final daXoa = <String>[];
    await moTrang(tester, cong(xoa: false, daXoa: daXoa));
    await tester.ensureVisible(dongNha());
    await tester.pumpAndSettle();
    await tester.drag(dongNha(), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(daXoa, isEmpty);
    expect(repo.soLanXoaThang, 0);
    expect(bat.cau, contains('Bạn không xoá được khoản này của nhà.'));
    expect(dongNha(), findsOneWidget, reason: 'dòng bật lại');
    await dongTrang(tester);
  });

  testWidgets('chưa đăng ký cổng → dòng nhà vẫn hiện, vuốt xoá chỉ báo, không xoá thẳng', (tester) async {
    await moTrang(tester, null);
    await tester.ensureVisible(dongNha());
    await tester.pumpAndSettle();
    await tester.drag(dongNha(), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repo.soLanXoaThang, 0);
    await dongTrang(tester);
  });
}
