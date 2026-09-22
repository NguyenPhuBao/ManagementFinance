/// G48 — đường tắt "Xem giao dịch" phải lọc sẵn ví **kể cả khi trang đã sống**
/// (2026-09-21).
///
/// ## Vì sao ca này tồn tại, và vì sao ca cũ không bắt được
///
/// Màn Quản lý ví đi `context.go('/transactions?wallet=<id>')`; route đọc query
/// param và truyền `initialWalletId`. Ca test cũ (2026-09-14) dựng trang **mới
/// tinh** nên `initState` luôn chạy và nó luôn xanh.
///
/// Nhưng `/transactions` là một `StatefulShellBranch`, và Navigator của nhánh
/// **giữ State sống**. Lần `go` thứ hai dựng một `TransactionPage` mới cùng kiểu
/// ở cùng vị trí, nên Flutter **cập nhật** State cũ thay vì tạo State mới —
/// `initState` không chạy lại và ví mới bị bỏ qua, **im lặng**. Đo trên máy ảo
/// 2026-09-21: app vừa khởi động thì lọc đúng; ghé tab Giao dịch trước rồi mới
/// dùng đường tắt thì trang hiện **toàn bộ** giao dịch, chip Ví không bật.
///
/// Ca dưới đây tái hiện đúng cơ chế ấy mà **không cần cây route thật**: dựng
/// trang với `initialWalletId = null`, rồi dựng lại **cùng vị trí** với một ví.
/// `pumpWidget` giữ State vì runtimeType và key không đổi — đúng thứ shell làm.
///
/// ⚠️ Phép sửa **không phải** gán `_filter` trong `build`: chú thích tại
/// `transaction_page.dart` giải thích vì sao lối ấy làm người dùng không bỏ lọc
/// ra được. Nó cũng **không** trả lời câu hỏi rộng hơn — bộ lọc có nên sống sót
/// qua một lần ghé tab hay không — mà chỉ chốt một điều hẹp và rõ: **một lệnh
/// điều hướng có nêu đích danh ví thì thắng bộ lọc đang có**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

const int _idaccount = 7;
const String _viTienMat = 'vi-tien-mat';
const String _viTietKiem = 'vi-tiet-kiem';

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

/// Hai khoản, hai ví — để "có lọc" và "không lọc" trông khác nhau.
class _HaiViRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    final moc = DateTime.now().subtract(const Duration(days: 1));
    return Stream.value([
      TransactionEntity(
        id: 'gd-tien-mat',
        walletId: _viTienMat,
        idaccount: _idaccount,
        amount: 111000,
        type: 'chi',
        note: 'KHOAN O TIEN MAT',
        date: moc,
        images: const [],
        syncStatus: 'synced',
        updatedAt: moc,
        isDeleted: false,
      ),
      TransactionEntity(
        id: 'gd-tiet-kiem',
        walletId: _viTietKiem,
        idaccount: _idaccount,
        amount: 222000,
        type: 'chi',
        note: 'KHOAN O TIET KIEM',
        date: moc,
        images: const [],
        syncStatus: 'synced',
        updatedAt: moc,
        isDeleted: false,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    // ⚠️ BẮT BUỘC: danh sách nhóm theo ngày dựng tiêu đề bằng `DateFormat` với
    // locale 'vi'. Thiếu dòng này thì nó ném `LocaleDataException` và **cả cây
    // dừng dựng** — mọi ca đỏ với dáng vẻ "không tìm thấy gì cả", một triệu
    // chứng chẳng liên quan gì tới nguyên nhân. Ca ở
    // `so_giao_dich_chon_ky_test.dart` không vấp chỉ vì danh sách của nó rỗng
    // nên không có tiêu đề ngày nào được dựng.
    await initializeDateFormatting('vi');

    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _HaiViRepository()),
    );

    // Hai ví thật trong CSDL — thanh lọc tra tên ví từ đây.
    for (final (id, ten) in [
      (_viTienMat, 'Tiền mặt'),
      (_viTietKiem, 'Tiết kiệm'),
    ]) {
      await db.into(db.wallets).insert(
            WalletsCompanion.insert(
              id: id,
              idaccount: _idaccount,
              name: ten,
              updatedAt: DateTime.now(),
            ),
          );
    }
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ **BẮT BUỘC gọi ở cuối MỖI ca**, trong thân ca — xem chú thích dài ở
  /// `so_giao_dich_chon_ky_test.dart`. Thiếu nó là treo cả tệp.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Dựng trang ở **cùng một vị trí trong cây**, đổi mỗi `initialWalletId`.
  /// Giữ nguyên kiểu và không đặt key, nên lần dựng thứ hai **tái dùng State** —
  /// đúng điều `StatefulShellBranch` làm khi `go` lần thứ hai.
  Future<void> dung(WidgetTester tester, String? viBanDau) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '$_idaccount',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: TransactionPage(initialWalletId: viBanDau),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mở thẳng bằng đường tắt thì lọc sẵn đúng ví', (tester) async {
    await dung(tester, _viTietKiem);

    expect(find.text('KHOAN O TIET KIEM'), findsOneWidget);
    expect(find.text('KHOAN O TIEN MAT'), findsNothing,
        reason: 'đường tắt nêu đích danh ví Tiết kiệm');

    await dongTrang(tester);
  });

  testWidgets('trang ĐÃ SỐNG mà nhận ví mới thì vẫn lọc theo ví ấy',
      (tester) async {
    // Lần đầu: người dùng ghé tab Giao dịch, không có ví nào được nêu.
    await dung(tester, null);
    expect(find.text('KHOAN O TIEN MAT'), findsOneWidget,
        reason: 'chưa lọc gì thì thấy cả hai ví');
    expect(find.text('KHOAN O TIET KIEM'), findsOneWidget);

    // Lần hai: đường tắt từ màn Quản lý ví. State cũ được tái dùng.
    await dung(tester, _viTietKiem);

    expect(
      find.text('KHOAN O TIET KIEM'),
      findsOneWidget,
      reason: 'ĐÒI KẾT QUẢ: khoản của ví được nêu phải còn đó — nếu chỉ đòi '
          'khoản kia vắng mặt thì một bản sai lọc sạch danh sách cũng xanh',
    );
    expect(
      find.text('KHOAN O TIEN MAT'),
      findsNothing,
      reason: 'G48: `initState` không chạy lại khi State được tái dùng, nên bộ '
          'lọc ví mới bị bỏ qua im lặng và người dùng thấy sổ đầy đủ — tưởng '
          'rằng chừng ấy khoản đều thuộc ví họ vừa bấm',
    );

    await dongTrang(tester);
  });

  testWidgets('ví mới KHÔNG đè bộ lọc khi đường tắt không nêu ví nào',
      (tester) async {
    await dung(tester, _viTietKiem);
    expect(find.text('KHOAN O TIEN MAT'), findsNothing);

    // Dựng lại mà không nêu ví: đây KHÔNG phải một lệnh "hãy xem mọi ví", chỉ
    // là trang được dựng lại. Giữ nguyên thứ người dùng đang xem.
    await dung(tester, null);

    expect(
      find.text('KHOAN O TIEN MAT'),
      findsNothing,
      reason: 'chỉ một lệnh điều hướng CÓ nêu ví mới được đổi bộ lọc; coi '
          '`null` là "bỏ lọc" thì mỗi lần trang dựng lại là bộ lọc tự bay mất',
    );
    expect(find.text('KHOAN O TIET KIEM'), findsOneWidget);

    await dongTrang(tester);
  });
}
