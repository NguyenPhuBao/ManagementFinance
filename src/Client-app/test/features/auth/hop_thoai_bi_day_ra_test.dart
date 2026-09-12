/// Hộp thoại "bị đẩy ra" — chữ theo lý do, và không tràn ở 411dp.
///
/// Dựng bằng `AppTheme.lightTheme` trong `SizedBox(width: 411)`: theme của app
/// ép mọi `ElevatedButton` rộng vô hạn (bẫy 4.11 `ANALYTICS_FEATURE.md`) và
/// font của bộ test rộng gấp đôi ngoài đời (bẫy 4.4). `tester.takeException()`
/// là chỗ DUY NHẤT bắt được lỗi tràn — Flutter báo tràn qua
/// `FlutterError.reportError` chứ không ném ra chỗ gọi, nên một test chỉ
/// `pumpWidget` + `expect(find…)` vẫn xanh khi màn hình đầy sọc vàng.
///
/// Spec cưỡng chế đăng xuất §5.1 và §3.7.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/auth/presentation/pages/login_page.dart';
import 'package:flowmoney/features/auth/presentation/widgets/hop_thoai_bi_day_ra.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

/// Repository giả tối thiểu: đủ để bloc đi từ `AuthCheckRequested` tới
/// `AuthSuccess` mà không đụng mạng, CSDL hay `sl`.
class _RepoGia implements AuthRepository {
  int xoaPhienCalls = 0;

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<SessionStatus> verifySession() async => SessionStatus.valid;

  @override
  Future<UserModel?> getCurrentUser() async => UserModel(
        id: '11',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      );

  @override
  Future<void> xoaPhienTrenMay() async => xoaPhienCalls++;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void _manHinhCao(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _biKhoa = ThongBaoBuocDangXuat(
  lyDo: LyDoBuocDangXuat.biKhoa,
  nguon: NguonBuocDangXuat.socket,
  loiNhan: 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản '
      'sử dụng — chia sẻ tài khoản cho nhiều người.',
  idaccount: 11,
);

const _daXoa = ThongBaoBuocDangXuat(
  lyDo: LyDoBuocDangXuat.daXoa,
  nguon: NguonBuocDangXuat.socket,
  loiNhan: 'Account no longer exists or has been deleted',
  idaccount: 11,
);

Widget _dungHopThoai(ThongBaoBuocDangXuat thongBao) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Center(
        child: SizedBox(
          width: 411,
          child: HopThoaiBiDayRa(thongBao: thongBao),
        ),
      ),
    );

void main() {
  group('Hộp thoại', () {
    testWidgets('biKhoa: tiêu đề, biểu tượng block, câu của server', (t) async {
      await t.pumpWidget(_dungHopThoai(_biKhoa));

      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.textContaining('Vi phạm điều khoản'), findsOneWidget);
      expect(find.text('Đã hiểu'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('daXoa: tiêu đề và biểu tượng khác hẳn', (t) async {
      await t.pumpWidget(_dungHopThoai(_daXoa));

      expect(find.text('Tài khoản đã bị xoá'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
      expect(find.byIcon(Icons.block), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('loiNhan rỗng → câu mặc định theo lý do', (t) async {
      await t.pumpWidget(_dungHopThoai(const ThongBaoBuocDangXuat(
        lyDo: LyDoBuocDangXuat.biKhoa,
        nguon: NguonBuocDangXuat.socket,
      )));
      expect(find.text('Tài khoản của bạn đã bị vô hiệu hoá.'), findsOneWidget,
          reason: 'payload dị dạng vẫn phải ra một câu đọc được, không phải một '
              'khoảng trống');

      await t.pumpWidget(_dungHopThoai(const ThongBaoBuocDangXuat(
        lyDo: LyDoBuocDangXuat.daXoa,
        nguon: NguonBuocDangXuat.lamMoi,
      )));
      expect(find.text('Tài khoản của bạn đã bị xoá khỏi hệ thống.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('luôn có dòng phụ liên hệ hỗ trợ', (t) async {
      await t.pumpWidget(_dungHopThoai(_biKhoa));

      expect(find.textContaining('Liên hệ hỗ trợ'), findsOneWidget,
          reason: 'admin khoá nhầm thì đây là đường duy nhất người dùng còn lại');
    });

    testWidgets('câu server dài bất thường vẫn không tràn ở 411dp', (t) async {
      await t.pumpWidget(_dungHopThoai(ThongBaoBuocDangXuat(
        lyDo: LyDoBuocDangXuat.biKhoa,
        nguon: NguonBuocDangXuat.socket,
        loiNhan: 'Lý do: ${'rất dài ' * 40}',
      )));

      expect(t.takeException(), isNull,
          reason: 'câu này do admin gõ, client không kiểm được độ dài');
    });

    testWidgets('nút Đã hiểu đóng hộp thoại', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => hienHopThoaiBiDayRa(context, _biKhoa),
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsOneWidget);

      await t.tap(find.text('Đã hiểu'));
      await t.pumpAndSettle();

      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsNothing);
    });

    testWidgets('chạm ra ngoài KHÔNG đóng được', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => hienHopThoaiBiDayRa(context, _biKhoa),
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();

      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();

      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsOneWidget,
          reason: 'lý do bị đẩy ra là thứ phải đọc — người dùng chọn hình thức '
              'bắt bấm "Đã hiểu" (mục 2, Q3)');
    });
  });

  group('Màn Đăng nhập', () {
    /// Đưa bloc vào `AuthSuccess` bằng đúng đường mở app. Không đăng ký gì vào
    /// `sl`, nên bloc bỏ qua toàn bộ khối đồng bộ/thông báo/realtime.
    Future<AuthBloc> blocDangDangNhap(_RepoGia repo) async {
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final xong = bloc.stream.where((s) => s is AuthSuccess).first;
      bloc.add(AuthCheckRequested());
      await xong.timeout(const Duration(seconds: 5));
      return bloc;
    }

    Widget dungTrang(AuthBloc bloc) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
        );

    testWidgets('trang được dựng SAU khi state đã mang thongBao → vẫn hiện',
        (t) async {
      _manHinhCao(t);
      final bloc = await blocDangDangNhap(_RepoGia());
      final daDangXuat =
          bloc.stream.where((s) => s is AuthUnauthenticated).first;
      bloc.add(const TaiKhoanBiBuocDangXuat(_daXoa));
      await daDangXuat.timeout(const Duration(seconds: 5));

      // Đây là thứ tự THẬT: router đổi trang vì bloc vừa emit, nên trang chỉ
      // tồn tại SAU lần đổi state ấy — `BlocListener` không thể nghe được nó.
      await t.pumpWidget(dungTrang(bloc));
      await t.pumpAndSettle();

      expect(find.text('Tài khoản đã bị xoá'), findsOneWidget,
          reason: 'chỉ dựa vào BlocListener thì hộp thoại không bao giờ hiện '
              'trên đường đi thật — app_router.dart:89 refresh theo authBloc.stream');
    });

    testWidgets('trang đang mở rồi thongBao mới tới → cũng hiện', (t) async {
      _manHinhCao(t);
      final bloc = await blocDangDangNhap(_RepoGia());
      await t.pumpWidget(dungTrang(bloc));
      await t.pumpAndSettle();
      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsNothing);

      bloc.add(const TaiKhoanBiBuocDangXuat(_biKhoa));
      await t.pumpAndSettle();

      expect(find.text('Tài khoản đã bị vô hiệu hoá'), findsOneWidget);
    });

    testWidgets('AuthUnauthenticated trơn (tự đăng xuất) → KHÔNG hiện gì',
        (t) async {
      _manHinhCao(t);
      final bloc = await blocDangDangNhap(_RepoGia());
      final daDangXuat =
          bloc.stream.where((s) => s is AuthUnauthenticated).first;
      bloc.add(LogoutRequested());
      await daDangXuat.timeout(const Duration(seconds: 5));

      await t.pumpWidget(dungTrang(bloc));
      await t.pumpAndSettle();

      expect(find.byType(HopThoaiBiDayRa), findsNothing,
          reason: 'người tự bấm Đăng xuất không cần ai giải thích gì');
    });

    testWidgets('không hiện hai lần cho cùng một thông báo', (t) async {
      _manHinhCao(t);
      final bloc = await blocDangDangNhap(_RepoGia());
      final daDangXuat =
          bloc.stream.where((s) => s is AuthUnauthenticated).first;
      bloc.add(const TaiKhoanBiBuocDangXuat(_biKhoa));
      await daDangXuat.timeout(const Duration(seconds: 5));

      // Vào trang khi state đã mang thongBao (initState hiện hộp thoại), rồi
      // ép thêm một lần rebuild để chắc rằng listener không chồng thêm cái nữa.
      await t.pumpWidget(dungTrang(bloc));
      await t.pumpAndSettle();
      await t.pump();

      expect(find.byType(HopThoaiBiDayRa), findsOneWidget);
    });
  });
}
