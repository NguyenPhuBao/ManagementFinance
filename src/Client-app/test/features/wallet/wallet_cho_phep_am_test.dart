/// Cờ "ví được phép âm" — **G27** (2026-09-17).
///
/// Canh chừng điều gì: cờ này có **hai** nơi đọc và chúng làm **hai việc khác
/// nhau** — bộ luật thông báo bỏ qua hai loại cảnh báo (canh ở
/// `notification_rules_goal_wallet_test.dart`), còn màn Quản lý ví bỏ **màu
/// đỏ**. Tệp này canh vế thứ hai, cộng đường đi của cờ qua hai màn nhập liệu.
///
/// Màu đỏ là thứ `flutter test` bắt được mà mắt người dễ bỏ sót khi sửa: nó
/// không phải một chuỗi để `find.text`, nên ca test phải đọc thẳng `Color` của
/// widget. Để đỏ trong khi đã tắt thông báo là app tự mâu thuẫn với chính nó —
/// người dùng vẫn thấy một dấu hiệu báo động mỗi lần mở màn Ví.
library;

import 'dart:io';

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
  _AuthBlocGia() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(
        id: '7',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
  }
}

class _RepoBoNho implements WalletRepository {
  _RepoBoNho(this._vi);

  final List<WalletEntity> _vi;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => List.of(_vi);

  @override
  Future<double> getTotalBalance(int idaccount) async =>
      _vi.fold<double>(0, (s, w) => s + w.balance);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _vi({
  String id = 'v1',
  String ten = 'Thẻ tín dụng',
  double soDu = -5000000,
  bool choPhepAm = false,
}) =>
    WalletEntity(
      id: id,
      idaccount: 7,
      name: ten,
      type: 'bank',
      balance: soDu,
      allowNegative: choPhepAm,
      updatedAt: DateTime(2026, 9, 17),
    );

void main() {
  setUp(() {
    if (sl.isRegistered<AuthBloc>()) sl.unregister<AuthBloc>();
  });

  /// Trang tự lấy `WalletCubit` từ `sl`, không từ provider của cây widget —
  /// nên phải đăng ký ở đó, đúng khuôn `wallet_archive_ui_test`.
  Future<void> moTrang(WidgetTester tester, List<WalletEntity> vi) async {
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
    sl.registerFactory<WalletCubit>(
        () => WalletCubit(repository: _RepoBoNho(vi)));
    addTearDown(() async {
      if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
    });

    final auth = _AuthBlocGia();
    addTearDown(auth.close);

    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn, nên widget
      // test phải dựng bằng chính theme ấy.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WalletListPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Màu nền của khối biểu tượng ví — chỗ `_iconBg` đổ vào.
  Color? nenBieuTuong(WidgetTester tester, String tenVi) {
    final the = find.ancestor(
      of: find.text(tenVi),
      matching: find.byType(Container),
    );
    for (final c in tester.widgetList<Container>(the)) {
      final d = c.decoration;
      if (d is BoxDecoration && d.color != null && d.shape == BoxShape.circle) {
        return d.color;
      }
    }
    // Thẻ không dùng hình tròn thì lấy Container có màu đầu tiên bên trong.
    for (final c in tester.widgetList<Container>(
        find.descendant(of: the.first, matching: find.byType(Container)))) {
      final d = c.decoration;
      if (d is BoxDecoration && d.color != null) return d.color;
    }
    return null;
  }

  group('màu ở màn Quản lý ví', () {
    testWidgets('ví âm THƯỜNG vẫn mang màu cảnh báo đỏ', (tester) async {
      await moTrang(tester, [_vi(ten: 'Ví thường', choPhepAm: false)]);

      expect(nenBieuTuong(tester, 'Ví thường'), const Color(0xFFFFEBEE),
          reason: 'Ví âm ngoài ý muốn vẫn là dấu hiệu một giao dịch bị ghi '
              'nhầm — cờ mới không được làm mất cảnh báo ấy.');
    });

    testWidgets('⚠️ ví CHO PHÉP ÂM thì thôi đỏ', (tester) async {
      await moTrang(tester, [_vi(ten: 'Thẻ tín dụng', choPhepAm: true)]);

      expect(nenBieuTuong(tester, 'Thẻ tín dụng'),
          isNot(const Color(0xFFFFEBEE)),
          reason: 'Đỏ là màu báo CÓ GÌ ĐÓ SAI. Để đỏ trong khi đã tắt thông '
              'báo cho chính ví ấy là app tự mâu thuẫn, và người dùng vẫn thấy '
              'một dấu hiệu báo động mỗi lần mở màn Ví.');
    });

    testWidgets('cờ của ví này không ảnh hưởng ví khác', (tester) async {
      await moTrang(tester, [
        _vi(id: 'v1', ten: 'Thẻ tín dụng', choPhepAm: true),
        _vi(id: 'v2', ten: 'Ví thường', choPhepAm: false),
      ]);

      expect(nenBieuTuong(tester, 'Ví thường'), const Color(0xFFFFEBEE));
      expect(nenBieuTuong(tester, 'Thẻ tín dụng'),
          isNot(const Color(0xFFFFEBEE)));
    });
  });

  group('WalletEntity', () {
    test('mặc định TẮT — mọi ví đang có phải hành xử y như trước', () {
      expect(_vi().allowNegative, isFalse);
    });

    test('copyWith mang được cờ, và không đụng cờ khác', () {
      final goc = _vi(choPhepAm: false);
      final moi = goc.copyWith(allowNegative: true);

      expect(moi.allowNegative, isTrue);
      expect(moi.includeInTotal, goc.includeInTotal);
      expect(moi.status, goc.status);
    });

    test('⚠️ cờ nằm trong props — thiếu nó thì bật/tắt không phát lại state',
        () {
      // `WalletEntity` là `Equatable`. Quên cờ trong `props` nghĩa là hai ví
      // chỉ khác nhau ở cờ ấy được coi là BẰNG NHAU, và cubit bỏ qua lượt phát
      // state sau khi người dùng gạt công tắc — màn hình đứng im, im lặng.
      expect(_vi(choPhepAm: true) == _vi(choPhepAm: false), isFalse);
    });
  });

  group('⚠️ cột CỤC BỘ — không được lọt vào đường đồng bộ', () {
    // Test quét `lib/` thứ **bảy**. Cờ này không có cột tương ứng ở
    // PostgreSQL, nên một khoá lọt vào payload đẩy sẽ khiến ví **kẹt hàng đợi
    // đẩy vĩnh viễn, im lặng** — đúng sự cố mà `ewallet`/`debt` đã gây ra trên
    // cột `Type` (migration v20), và đúng lý do `wallet.status` phải chờ tới
    // G28 mới mở được.
    //
    // Đây cũng là bài học ngược chiều của G28: khi `status` còn là cột cục bộ,
    // **ba** chú thích ở ba tệp khác vẫn nói nó "đi ra máy khác qua
    // `/sync/push`". Chữ thì trôi, test quét thì không.
    const duongDongBo = [
      'lib/core/sync/sync_engine.dart',
      'lib/core/sync/sync_payload_normalizer.dart',
    ];

    for (final f in duongDongBo) {
      test('$f không nhắc tới cờ', () {
        final noiDung = File(f).readAsStringSync();

        expect(noiDung.contains('allowNegative'), isFalse,
            reason: '$f nhắc tới `allowNegative`. Cờ này là cột CỤC BỘ — '
                'PostgreSQL không có cột tương ứng, nên đẩy nó lên là ví kẹt '
                'hàng đợi vĩnh viễn mà không lỗi nào báo ra.');
        expect(noiDung.contains('allow_negative'), isFalse,
            reason: '$f nhắc tới khoá `allow_negative`.');
      });
    }

    test('hợp đồng payload ví vẫn KHÔNG có cờ', () {
      final hopDong =
          File('test/core/sync/sync_payload_contract_test.dart').readAsStringSync();

      expect(hopDong.contains('allow_negative'), isFalse,
          reason: 'Hợp đồng tên trường là nơi duy nhất ghi lại payload đẩy. '
              'Thêm cờ vào đó mà PostgreSQL chưa có cột là mở đúng cái bẫy '
              'quy tắc 4 nói tới: tên trường sai thì IM LẶNG, không báo lỗi.');
    });
  });

  group('màu SỐ TIỀN, không chỉ biểu tượng', () {
    Color? mauSoTien(WidgetTester tester, String soTien) =>
        tester.widget<Text>(find.text(soTien)).style?.color;

    // ⚠️ Luôn dựng thêm một ví DƯƠNG: với một ví duy nhất, thẻ "Tổng tài sản"
    // in ra đúng chuỗi số ấy và `find.text` khớp **hai** chỗ.
    testWidgets('ví âm thường: số tiền màu cảnh báo', (tester) async {
      await moTrang(tester, [
        _vi(ten: 'Ví thường', soDu: -100000),
        _vi(id: 'v2', ten: 'Tiền mặt', soDu: 500000),
      ]);

      expect(mauSoTien(tester, '-100.000 đ'), const Color(0xFFBA1A1A));
    });

    testWidgets('⚠️ ví cho phép âm: số tiền THÔI đỏ', (tester) async {
      // Máy ảo bắt được: bản đầu chỉ đổi màu biểu tượng, còn con số vẫn đỏ
      // chói — nửa việc, và nửa còn lại mới là thứ mắt đọc trước tiên.
      await moTrang(tester, [
        _vi(ten: 'Thẻ tín dụng', soDu: -100000, choPhepAm: true),
        _vi(id: 'v2', ten: 'Tiền mặt', soDu: 500000),
      ]);

      expect(mauSoTien(tester, '-100.000 đ'), isNot(const Color(0xFFBA1A1A)),
          reason: 'Màu ở đó là `AppColors.error` — màu cảnh báo, không phải quy '
              'ước dấu. Ví lưu trữ đã có tiền lệ: nó chuyển số âm sang xám vì '
              'cùng lý do.');
    });
  });
}
