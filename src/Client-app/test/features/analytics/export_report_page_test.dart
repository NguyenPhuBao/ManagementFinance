/// Trang **Xuất báo cáo** với repository giả.
///
/// Canh chừng điều gì: trang này từng là **số cứng** — chip ví ghi
/// "Techcombank"/"Tiền mặt" bịa ra, lịch sử xuất ghi `BaoCao_Thang6.pdf` bịa
/// ra, nút xuất chỉ hiện snackbar. Tệp này canh phần chỉ widget mới sai được:
/// ví lấy từ CSDL chứ không từ hằng số, bộ lọc người dùng chọn đi **nguyên
/// vẹn** xuống repository, và khổ 411dp của điện thoại thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/analytics/data/bao_cao_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/presentation/pages/export_report_page.dart';
import 'package:flowmoney/features/analytics/presentation/pages/report_preview_page.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
  }
}

class _RepoGia implements BaoCaoRepository {
  int? idNhan;
  LocBaoCao? locNhan;

  @override
  Future<BaoCao> layBaoCao(int idaccount, {required LocBaoCao loc}) async {
    idNhan = idaccount;
    locNhan = loc;
    return dungBaoCao(const [], loc: loc);
  }

  @override
  Stream<List<LuaChonLoc>> watchVi(int idaccount) => Stream.value(const [
        LuaChonLoc(id: 'w1', ten: 'Ví chính'),
        LuaChonLoc(id: 'w2', ten: 'Ngân hàng ACB'),
      ]);

  @override
  Stream<List<LuaChonLoc>> watchDanhMuc(int idaccount) => Stream.value(const [
        LuaChonLoc(id: 'c_an', ten: 'Ăn uống'),
        LuaChonLoc(id: 'c_xe', ten: 'Di chuyển'),
      ]);
}

void main() {
  late _RepoGia repo;
  final now = DateTime(2026, 9, 8, 12);

  setUpAll(() => initializeDateFormatting('vi_VN', null));

  setUp(() async {
    repo = _RepoGia();
    if (sl.isRegistered<BaoCaoRepository>()) {
      await sl.unregister<BaoCaoRepository>();
    }
    sl.registerFactory<BaoCaoRepository>(() => repo);
  });

  tearDown(() async {
    if (sl.isRegistered<BaoCaoRepository>()) {
      await sl.unregister<BaoCaoRepository>();
    }
  });

  /// Mở trang ở đúng khổ điện thoại thật (411dp), không phải 800×600 mặc định
  /// của bộ test: nút "Xem trước báo cáo" nằm cuối trang, và ở khổ rộng giả
  /// mọi thứ vừa màn hình nên test không bao giờ đi qua đường cuộn thật.
  Future<void> moTrang(WidgetTester t) async {
    t.view.physicalSize = const Size(411 * 3, 900 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await t.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        // Theme thật: nó đặt `minimumSize` chiều rộng vô hạn cho
        // `ElevatedButton`, thứ chỉ nổ ở chỗ không chặn bề ngang.
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExportReportPage(clock: () => now),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> bamXemTruoc(WidgetTester t) async {
    final nut = find.text('Xem trước báo cáo');
    await t.ensureVisible(nut);
    await t.pumpAndSettle();
    await t.tap(nut);
    await t.pumpAndSettle();
  }

  testWidgets('chip ví lấy từ CSDL, không còn ví bịa', (t) async {
    await moTrang(t);

    expect(find.text('Ví chính'), findsOneWidget);
    expect(find.text('Ngân hàng ACB'), findsOneWidget);
    expect(find.text('Techcombank'), findsNothing,
        reason: 'Ví "Techcombank" là hằng số của bản Stitch. Người dùng nào '
            'không có ví tên ấy vẫn thấy nó, và lọc theo nó thì báo cáo rỗng '
            'mà không lỗi nào báo.');
  });

  testWidgets('không còn khối lịch sử xuất bịa', (t) async {
    await moTrang(t);

    expect(find.textContaining('BaoCao_Thang6'), findsNothing);
    expect(find.textContaining('LỊCH SỬ XUẤT'), findsNothing,
        reason: 'Lịch sử xuất cần một bảng cục bộ để ghi lại; chưa có bảng thì '
            'khối ấy chỉ là hai dòng chữ bịa.');
  });

  testWidgets('mặc định Tháng này: bộ lọc gửi xuống đúng biên tháng của đồng hồ',
      (t) async {
    await moTrang(t);
    await bamXemTruoc(t);

    expect(repo.idNhan, 10,
        reason: 'Quy tắc 2: `idaccount` chỉ đến từ phiên đăng nhập.');
    expect(repo.locNhan!.from, DateTime(2026, 9, 1));
    expect(repo.locNhan!.to, DateTime(2026, 10, 1));
    expect(repo.locNhan!.walletId, isNull);
    expect(repo.locNhan!.categoryId, isNull);
  });

  testWidgets('chọn Tháng trước thì khoảng gửi xuống đổi theo', (t) async {
    await moTrang(t);
    await t.tap(find.text('Tháng trước'));
    await t.pump();
    await bamXemTruoc(t);

    expect(repo.locNhan!.from, DateTime(2026, 8, 1));
    expect(repo.locNhan!.to, DateTime(2026, 9, 1));
  });

  testWidgets('chọn một ví thì id ví đi xuống repository', (t) async {
    await moTrang(t);
    await t.tap(find.text('Ngân hàng ACB'));
    await t.pump();
    await bamXemTruoc(t);

    expect(repo.locNhan!.walletId, 'w2',
        reason: 'Chip hiện TÊN nhưng bộ lọc phải đi bằng ID. Gửi tên xuống là '
            'lọc không khớp gì cả — và báo cáo rỗng trông y hệt "tháng này '
            'chưa tiêu gì".');
  });

  testWidgets('chọn một danh mục thì id danh mục đi xuống repository', (t) async {
    await moTrang(t);
    await t.tap(find.text('Tất cả danh mục'));
    await t.pumpAndSettle();
    await t.tap(find.text('Di chuyển').last);
    await t.pumpAndSettle();
    await bamXemTruoc(t);

    expect(repo.locNhan!.categoryId, 'c_xe');
  });

  testWidgets('bấm Xem trước thì mở màn Xem trước báo cáo', (t) async {
    await moTrang(t);
    await bamXemTruoc(t);

    expect(find.byType(ReportPreviewPage), findsOneWidget,
        reason: 'Đây là chỗ nút cũ chỉ hiện snackbar rồi thôi.');
  });

  testWidgets('411dp: không tràn bố cục', (t) async {
    await moTrang(t);
    expect(t.takeException(), isNull);
  });
}
