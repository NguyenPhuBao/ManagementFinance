/// Màn Quản lý ví sau khi có tính năng lưu trữ ví.
///
/// Thiết kế Stitch: màn *"Quản lý ví - có mục Đã lưu trữ"*
/// (`2c950ea26ebf4a4590a26d0742d2a7dd`, dự án `5106367939423432838`). Ba thứ
/// màn ấy quy định và tệp này canh:
///
/// 1. Ví lưu trữ **không** nằm lẫn trong danh sách ví thường; chúng nằm dưới
///    một mục riêng có tiêu đề "ĐÃ LƯU TRỮ (n)".
/// 2. Thẻ tổng tài sản mang một dòng chú thích nói rõ vì sao con số nhỏ đi —
///    nếu không, người dùng lưu trữ một ví rồi thấy tổng tụt mà không hiểu.
/// 3. Menu ba chấm mang hành động lưu trữ, và chữ của nó **đổi theo trạng
///    thái** của chính ví ấy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_list_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocGia extends AuthBloc {
  _AuthBlocGia() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

/// Repository giả giữ trạng thái thật trong bộ nhớ, để `setArchived` có hiệu
/// lực nhìn thấy được ở lượt tải lại — chứ không chỉ đếm số lần gọi.
class _RepoBoNho implements WalletRepository {
  _RepoBoNho(this._vi);

  final List<WalletEntity> _vi;

  /// Lỗi mà `setArchived` sẽ ném ra, nếu ca test muốn dựng đường hỏng.
  Object? loiKhiLuuTru;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => List.of(_vi);

  @override
  Future<double> getTotalBalance(int idaccount) async => _vi
      .where((w) => w.includeInTotal && w.status == 'active')
      .fold<double>(0, (s, w) => s + w.balance);

  @override
  Future<void> setArchived(String id, {required bool luuTru}) async {
    if (loiKhiLuuTru != null) throw loiKhiLuuTru!;
    final i = _vi.indexWhere((w) => w.id == id);
    _vi[i] = _vi[i].copyWith(status: luuTru ? 'inactive' : 'active');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _vi(
  String id,
  String ten, {
  double soDu = 1000000,
  String status = 'active',
  bool isDefault = false,
}) =>
    WalletEntity(
      id: id,
      idaccount: 10,
      name: ten,
      type: 'cash',
      balance: soDu,
      status: status,
      isDefault: isDefault,
      updatedAt: DateTime(2026, 9, 10),
    );

Future<void> _moTrang(WidgetTester tester, WalletRepository repo) async {
  if (sl.isRegistered<WalletCubit>()) {
    await sl.unregister<WalletCubit>();
  }
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: repo));
  addTearDown(() async {
    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
  });

  final auth = _AuthBlocGia();
  addTearDown(auth.close);
  auth.dat(AuthSuccess(
    user: UserModel(
      id: '10',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    ),
  ));

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn, nên widget
      // test phải dựng bằng chính theme ấy thay vì theme mặc định.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WalletListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('không có ví lưu trữ thì KHÔNG hiện mục "Đã lưu trữ"',
      (tester) async {
    await _moTrang(tester, _RepoBoNho([_vi('w1', 'Tiền mặt')]));

    expect(find.textContaining('ĐÃ LƯU TRỮ'), findsNothing,
        reason: 'Mục rỗng bày ra là thêm một khối nhiễu vào màn hình cho phần '
            'lớn người dùng — họ chưa lưu trữ ví nào.');
  });

  testWidgets('ví lưu trữ nằm dưới mục riêng, không lẫn vào danh sách chính',
      (tester) async {
    await _moTrang(
      tester,
      _RepoBoNho([
        _vi('w1', 'Tiền mặt'),
        _vi('w2', 'Thẻ cũ', status: 'inactive'),
      ]),
    );

    expect(find.text('ĐÃ LƯU TRỮ (1)'), findsOneWidget,
        reason: 'Số đếm nằm ngay trên tiêu đề mục, theo thiết kế Stitch.');
    expect(find.text('Thẻ cũ'), findsOneWidget,
        reason: 'Lưu trữ là ĐÓNG BĂNG chứ không phải xoá — ví vẫn phải xem '
            'được, nếu không người dùng không có đường nào bỏ lưu trữ.');
    expect(find.text('LƯU TRỮ'), findsOneWidget,
        reason: 'Huy hiệu phân biệt ví lưu trữ với ví thường, đúng như huy '
            'hiệu MẶC ĐỊNH đã có.');
  });

  testWidgets('thẻ tổng tài sản nói rõ vì sao con số nhỏ đi', (tester) async {
    await _moTrang(
      tester,
      _RepoBoNho([
        _vi('w1', 'Tiền mặt', soDu: 5000000),
        _vi('w2', 'Thẻ cũ', soDu: 9000000, status: 'inactive'),
      ]),
    );

    expect(find.textContaining('1 ví đã lưu trữ'), findsOneWidget,
        reason: 'Thiếu dòng này thì người dùng lưu trữ một ví, thấy tổng tài '
            'sản tụt 9 triệu, và không màn nào nói vì sao.');
  });

  testWidgets('menu ba chấm của ví ĐANG HOẠT ĐỘNG có mục "Lưu trữ"',
      (tester) async {
    await _moTrang(tester, _RepoBoNho([_vi('w1', 'Tiền mặt')]));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Lưu trữ'), findsOneWidget);
    expect(find.text('Bỏ lưu trữ'), findsNothing);
  });

  testWidgets('menu ba chấm của ví ĐÃ LƯU TRỮ có mục "Bỏ lưu trữ"',
      (tester) async {
    await _moTrang(
      tester,
      _RepoBoNho([
        _vi('w1', 'Tiền mặt'),
        _vi('w2', 'Thẻ cũ', status: 'inactive'),
      ]),
    );

    // Ví lưu trữ nằm sau ví thường, nên nút ba chấm của nó là nút cuối.
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Bỏ lưu trữ'), findsOneWidget,
        reason: 'Chữ phải đổi theo trạng thái của chính ví ấy. Một chữ "Lưu '
            'trữ" cố định trên ví đã lưu trữ là người dùng bấm mà không biết '
            'nó sẽ làm gì.');
    expect(find.text('Lưu trữ'), findsNothing);
  });

  testWidgets('bấm "Lưu trữ" thì ví chuyển sang mục Đã lưu trữ', (tester) async {
    final repo = _RepoBoNho([
      _vi('w1', 'Tiền mặt', isDefault: true),
      _vi('w2', 'Thẻ cũ'),
    ]);
    await _moTrang(tester, repo);

    expect(find.textContaining('ĐÃ LƯU TRỮ'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle();

    // Hộp thoại xác nhận phải nói rõ hai bộ chạy tự động sẽ DỪNG. Chốt
    // chặn cố ý KHÔNG cản ví đang gắn mục tiêu hay hoá đơn tự động — lưu
    // trữ là lối thoát cho đúng những ví ấy — nên câu cảnh báo này là chỗ
    // duy nhất người dùng biết được điều đó trước khi bấm.
    expect(find.text('Lưu trữ ví?'), findsOneWidget);
    expect(find.textContaining('tự động'), findsOneWidget,
        reason: 'Im lặng ở đây là người dùng mất một kỳ nạp mục tiêu hoặc '
            'một lần trả hoá đơn mà không biết.');

    await tester.tap(find.widgetWithText(TextButton, 'Lưu trữ'));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ LƯU TRỮ (1)'), findsOneWidget,
        reason: 'Đây là vòng đầy đủ: bấm menu → repository ghi → danh sách tải '
            'lại. Đứt ở bất kỳ khâu nào thì người dùng bấm xong không thấy gì '
            'đổi, và bấm lại lần nữa.');
    expect(repo._vi.firstWhere((w) => w.id == 'w2').status, 'inactive');
  });

  testWidgets('bấm Huỷ trên hộp thoại thì KHÔNG lưu trữ gì', (tester) async {
    final repo = _RepoBoNho([
      _vi('w1', 'Tiền mặt', isDefault: true),
      _vi('w2', 'Thẻ cũ'),
    ]);
    await _moTrang(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();

    expect(repo._vi.firstWhere((w) => w.id == 'w2').status, 'active',
        reason: 'Nút Huỷ mà vẫn ghi là hộp thoại xác nhận thành một thông báo '
            'suông — tệ hơn không có, vì nó dạy người dùng tin vào nó.');
    expect(find.textContaining('ĐÃ LƯU TRỮ'), findsNothing);
  });

  testWidgets('bỏ lưu trữ KHÔNG hỏi lại — nó không mất gì', (tester) async {
    final repo = _RepoBoNho([
      _vi('w1', 'Tiền mặt'),
      _vi('w2', 'Thẻ cũ', status: 'inactive'),
    ]);
    await _moTrang(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ lưu trữ'));
    await tester.pumpAndSettle();

    expect(repo._vi.firstWhere((w) => w.id == 'w2').status, 'active',
        reason: 'Bỏ lưu trữ là hành động khôi phục, không mất gì. Bắt xác nhận '
            'chỉ là một cú chạm thừa trên đường người dùng hay đi nhất ở mục '
            'này.');
    expect(find.textContaining('ĐÃ LƯU TRỮ'), findsNothing);
  });

  testWidgets('chốt chặn của tầng dưới hiện ra màn hình, không nuốt lặng',
      (tester) async {
    final repo = _RepoBoNho([_vi('w1', 'Tiền mặt', isDefault: true)])
      ..loiKhiLuuTru = Exception('Ví "Tiền mặt" đang là ví mặc định.');
    await _moTrang(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Lưu trữ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ví mặc định'), findsWidgets,
        reason: 'Hai chốt chặn ở datasource ném CacheException. Nuốt lặng là '
            'người dùng bấm "Lưu trữ" mà không có gì xảy ra và không lời giải '
            'thích nào.');
  });
}
