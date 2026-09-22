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
  Future<void> moTrang(
    WidgetTester t, {
    DateTime? tuNgay,
    DateTime? denNgay,
  }) async {
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
          home: ExportReportPage(
            clock: () => now,
            tuNgay: tuNgay,
            denNgay: denNgay,
          ),
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

  /// Mở bottom sheet chọn kỳ. Tìm theo **key** chứ không theo chữ: nhãn của nút
  /// là tên kỳ đang xem ("T9 2026"), thứ đổi theo đồng hồ và theo lựa chọn.
  Future<void> moBoChon(WidgetTester t) async {
    final nut = find.byKey(const Key('nutChonPhamVi'));
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
    await moBoChon(t);
    await t.tap(find.text('T8 2026'));
    await t.pumpAndSettle();
    await bamXemTruoc(t);

    expect(repo.locNhan!.from, DateTime(2026, 8, 1));
    expect(repo.locNhan!.to, DateTime(2026, 9, 1));
  });

  // ── Bộ chọn kỳ dùng chung với trang Phân tích ─────────────────────────────
  //
  // Canh chừng điều gì: trang này từng có bộ chọn RIÊNG — bốn chip cứng
  // `PhamViThoiGian` (Tháng này · Tháng trước · Quý này · Tùy chỉnh) — trong
  // khi trang Phân tích đã có `Ky` với năm đơn vị từ P1. Hai bộ luật song song
  // cho cùng một khái niệm "kỳ" là đúng khuôn "bản chép tay thứ N" mà dự án đã
  // trả giá nhiều lần, và nó làm trang này **không xuất được theo tuần hay
  // theo năm** dù mọi phép đếm bên dưới vốn nhận khoảng bất kỳ.

  testWidgets('nút phạm vi gọi tên kỳ giống hệt trang Phân tích', (t) async {
    await moTrang(t);

    expect(find.text('Tháng này (T9 2026)'), findsOneWidget,
        reason: 'Nhãn phải đi qua `nhanOChon` — cùng hàm mà header trang Phân '
            'tích và từng dòng trong bộ chọn dùng. Lấy `nhanNgan` thì nút nói '
            '"T9 2026" trong khi dòng người dùng vừa chạm nói "Tháng này (T9 '
            '2026)": một thứ hai cách gọi tên cho cùng một kỳ.');
  });

  testWidgets('chạm nút phạm vi thì mở bộ chọn kỳ có đủ năm đơn vị',
      (t) async {
    await moTrang(t);
    await moBoChon(t);

    for (final nhan in ['Tuần', 'Tháng', 'Quý', 'Năm', 'Tuỳ chọn']) {
      expect(find.text(nhan), findsWidgets,
          reason: 'Thiếu "$nhan" nghĩa là trang vẫn dùng bộ chọn riêng của nó '
              'chứ không phải `ChonPhamViSheet` của trang Phân tích.');
    }
  });

  testWidgets('xuất được theo TUẦN — thứ bộ chip cũ không làm được', (t) async {
    await moTrang(t);
    await moBoChon(t);
    await t.tap(find.text('Tuần'));
    await t.pumpAndSettle();
    // Tuần chứa 08/09/2026 (thứ Ba) là 07/09 – 13/09 theo ISO, tức tuần 37.
    // ⚠️ Kỳ **chứa hôm nay** hiện dưới dạng "Tuần này (Tuần 37)" chứ không
    // phải nhãn đầy đủ có khoảng ngày — `_dong` của sheet đi qua `nhanOChon`.
    await t.tap(find.textContaining('Tuần 37').first);
    await t.pumpAndSettle();
    await bamXemTruoc(t);

    expect(repo.locNhan!.from, DateTime(2026, 9, 7));
    expect(repo.locNhan!.to, DateTime(2026, 9, 14),
        reason: 'Biên phải MỞ ở đầu phải — cùng quy ước với `tongThuChi` và '
            'với chính `Ky`.');
  });

  testWidgets('nút giữ nguyên chuỗi của dòng vừa chạm, kể cả kỳ đã qua',
      (t) async {
    await moTrang(t);
    await moBoChon(t);
    await t.tap(find.text('Tuần'));
    await t.pumpAndSettle();
    // ⚠️ Tuần **36**, không phải 37: đồng hồ của tệp này đứng ở 08/09/2026 nên
    // tuần 37 chính là tuần hiện tại, và kỳ chứa hôm nay đi nhánh "… này" —
    // tức nhánh vốn đã đúng từ trước. Chỗ hỏng nằm ở kỳ ĐÃ QUA.
    await t.tap(find.textContaining('Tuần 36').first);
    await t.pumpAndSettle();

    expect(find.text('Tuần 36 (31/08 – 06/09)'), findsOneWidget,
        reason: 'Nghiệm thu máy ảo 2026-09-18 bắt được nút hiện "Tuần 37" trần '
            'trong khi dòng vừa chạm nói "Tuần 37 (07/09 – 13/09)" — hai cách '
            'gọi tên cho cùng một kỳ, cách nhau đúng một cú chạm, và cái ngắn '
            'hơn KHÔNG cho biết đó là khoảng nào. `nhanOChon` rơi về nhãn ngắn '
            'khi kỳ không chứa hôm nay, vì nó sinh ra cho ô header HẸP của '
            'trang Phân tích; nút này thì chiếm trọn chiều ngang.');
  });

  testWidgets('xuất được theo NĂM', (t) async {
    await moTrang(t);
    await moBoChon(t);
    await t.tap(find.text('Năm'));
    await t.pumpAndSettle();
    // ⚠️ Tìm theo "Năm nay" chứ không theo "2026": nút phạm vi của trang nằm
    // NGAY DƯỚI sheet và nhãn của nó là "T9 2026", nên `.first` của một finder
    // chứa "2026" trúng cái nút ấy và cú chạm không đổi gì — ca test vẫn chạy
    // trơn, chỉ là đo sai chỗ.
    await t.tap(find.textContaining('Năm nay'));
    await t.pumpAndSettle();
    await bamXemTruoc(t);

    expect(repo.locNhan!.from, DateTime(2026, 1, 1));
    expect(repo.locNhan!.to, DateTime(2027, 1, 1));
  });

  testWidgets(
      'kỳ đến từ route giữ nguyên NGÀY CUỐI — biên phải cộng thêm một ngày',
      (t) async {
    // Đường vào của thông báo **Tổng kết tuần**: nó mở trang này với tuần vừa
    // khép, và `denNgay` là ngày CUỐI CÙNG ĐƯỢC TÍNH VÀO.
    await moTrang(
      t,
      tuNgay: DateTime(2026, 8, 31),
      denNgay: DateTime(2026, 9, 6),
    );
    await bamXemTruoc(t);

    expect(repo.locNhan!.from, DateTime(2026, 8, 31));
    expect(repo.locNhan!.to, DateTime(2026, 9, 7),
        reason: '⚠️ `khoangCuaPhamVi` TỰ cộng một ngày, còn `Ky.tuyChon` bắt '
            'người gọi tự cộng. Quên vế ấy là báo cáo thiếu đúng ngày cuối '
            'cùng người dùng chọn — không exception, không dòng log, chỉ một '
            'con số nhỏ hơn thực tế.');
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
