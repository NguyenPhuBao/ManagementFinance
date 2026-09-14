/// Cubit của trang Phân tích, với repository giả điều khiển được.
///
/// Canh chừng điều gì: cubit là chỗ quyết định **tháng nào** được hỏi và **mã
/// tài khoản nào** được truyền xuống. Hỏi sai tháng thì trang vẽ số của tháng
/// khác mà không ai biết; truyền `idaccount` đoán bừa là quy tắc 2 `CLAUDE.md`
/// bị vi phạm. Đổi tháng mà không huỷ đăng ký cũ thì hai stream cùng phát và
/// cái tới sau thắng — không phải cái người dùng vừa chọn.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/phan_loai_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/presentation/bloc/analytics_cubit.dart';

ThongKeThang _tk(
  int nam,
  int thang, {
  double chi = 0,
  List<LatPhanLoai> lat = const [],
  Map<String?, List<DiemThoiGian>> chuoiDm = const {},
}) =>
    ThongKeThang(
      nam: nam,
      thang: thang,
      tong: TongThuChi(thu: 0, chi: chi),
      tongTruoc: const TongThuChi(thu: 0, chi: 0),
      chiTheoDanhMuc: const [],
      danhMuc: const [],
      chuoi: const [],
      latPhanLoai: lat,
      chuoiDanhMuc: chuoiDm,
    );

const _latChiThu = [
  LatPhanLoai(phanLoai: 'chi', soTien: 300, tiLe: 0.6),
  LatPhanLoai(phanLoai: 'thu', soTien: 200, tiLe: 0.4),
];

class _RepoGia implements AnalyticsRepository {
  final goi = <({int idaccount, int nam, int thang, DateTime? now})>[];
  final cacController = <StreamController<ThongKeThang>>[];
  int soLanHuy = 0;

  StreamController<ThongKeThang> get moiNhat => cacController.last;

  @override
  Stream<ThongKeThang> watchThang(
    int idaccount, {
    required int nam,
    required int thang,
    DateTime? now,
  }) {
    goi.add((idaccount: idaccount, nam: nam, thang: thang, now: now));
    final c = StreamController<ThongKeThang>();
    c.onCancel = () => soLanHuy++;
    cacController.add(c);
    return c.stream;
  }

  Future<void> dong() async {
    for (final c in cacController) {
      if (!c.isClosed) await c.close();
    }
  }
}

void main() {
  late _RepoGia repo;
  late AnalyticsCubit cubit;
  final now = DateTime(2026, 9, 8, 12);

  setUp(() {
    repo = _RepoGia();
    cubit = AnalyticsCubit(repository: repo, clock: () => now);
  });

  tearDown(() async {
    await cubit.close();
    await repo.dong();
  });

  test('chưa đăng nhập thì báo lỗi và KHÔNG hỏi repository', () {
    cubit.xem(null);
    expect(cubit.state, isA<AnalyticsError>());
    expect(repo.goi, isEmpty,
        reason: 'Không có mã tài khoản thì không đoán. Quy tắc 2 CLAUDE.md: '
            'idaccount chỉ đến từ phiên đăng nhập.');
  });

  test('mặc định hỏi đúng tháng của đồng hồ, truyền now xuống', () async {
    cubit.xem(10);

    expect(cubit.state, isA<AnalyticsLoading>());
    expect(repo.goi.single, (idaccount: 10, nam: 2026, thang: 9, now: now),
        reason: 'Trang cũ hiện "T6 2026" cứng trong khi đang là tháng 9. '
            'Tháng phải lấy từ đồng hồ, và cùng cái `now` ấy phải xuống tới '
            'repository để mốc tra ngân sách khớp.');

    repo.moiNhat.add(_tk(2026, 9, chi: 5));
    await Future<void>.delayed(Duration.zero);

    final s = cubit.state as AnalyticsLoaded;
    expect(s.thongKe.tong.chi, 5);
    expect(s.cacThang.length, 12);
    expect(s.cacThang.first, (nam: 2026, thang: 9));
  });

  test('chọn tháng khác thì huỷ đăng ký cũ và hỏi lại đúng tháng', () async {
    cubit.xem(10);
    repo.moiNhat.add(_tk(2026, 9));
    await Future<void>.delayed(Duration.zero);

    cubit.chonThang(2026, 8);
    await Future<void>.delayed(Duration.zero);

    expect(repo.soLanHuy, 1,
        reason: 'Không huỷ là hai stream cùng phát; cái phát sau thắng, và '
            'không có gì bảo đảm đó là tháng người dùng vừa chọn.');
    expect(repo.goi.last, (idaccount: 10, nam: 2026, thang: 8, now: now));
    expect(cubit.state, isA<AnalyticsLoading>());

    repo.moiNhat.add(_tk(2026, 8, chi: 7));
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as AnalyticsLoaded).thongKe.thang, 8);
  });

  test('chọn tháng khi chưa đăng nhập thì không làm gì', () {
    cubit.chonThang(2026, 8);
    expect(repo.goi, isEmpty);
  });

  test('stream phát lại thì state đổi theo', () async {
    cubit.xem(10);
    repo.moiNhat.add(_tk(2026, 9, chi: 1));
    await Future<void>.delayed(Duration.zero);
    repo.moiNhat.add(_tk(2026, 9, chi: 2));
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as AnalyticsLoaded).thongKe.tong.chi, 2);
  });

  test('stream lỗi thì ra AnalyticsError, không nổ', () async {
    cubit.xem(10);
    repo.moiNhat.addError(StateError('hỏng'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<AnalyticsError>());
  });

  group('hai lựa chọn của người dùng', () {
    Future<void> phat(ThongKeThang tk) async {
      repo.moiNhat.add(tk);
      await Future<void>.delayed(Duration.zero);
    }

    test('mặc định là nhóm Chi và không danh mục nào', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu));

      final s = cubit.state as AnalyticsLoaded;
      expect(s.phanLoaiDangXem, 'chi',
          reason: 'Chi là nhóm người dùng hỏi nhiều nhất — donut cũ chỉ vẽ Chi');
      expect(s.danhMucXuHuong, isEmpty,
          reason: 'Tập rỗng = hai đường Thu/Chi như trước');
    });

    test('BẪY 1: stream phát lại KHÔNG làm mất lựa chọn', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9,
          lat: _latChiThu, chuoiDm: {'an': const [], 'di': const []}));

      cubit.chonPhanLoai('thu');
      cubit.batTatDanhMucXuHuong('an');
      cubit.batTatDanhMucXuHuong('di');

      // Đồng bộ nền kéo về một thay đổi bất kỳ → repository phát lại.
      await phat(_tk(2026, 9,
          chi: 99, lat: _latChiThu, chuoiDm: {'an': const [], 'di': const []}));

      final s = cubit.state as AnalyticsLoaded;
      expect(s.thongKe.tong.chi, 99, reason: 'Số liệu mới phải tới nơi');
      expect(s.phanLoaiDangXem, 'thu',
          reason: 'Quên chép lựa chọn sang state mới thì cứ mỗi chu kỳ đồng bộ '
              'là chip nhảy về Chi TRONG KHI người dùng đang xem — không '
              'exception, không log');
      expect(s.danhMucXuHuong, {'an', 'di'});
    });

    test('BẪY 2: nhóm đang chọn biến mất thì rơi về Chi', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: const [
        LatPhanLoai(phanLoai: 'chi', soTien: 50, tiLe: 0.5),
        LatPhanLoai(phanLoai: 'vay_no', soTien: 50, tiLe: 0.5),
      ]));
      cubit.chonPhanLoai('vay_no');

      // Tháng mới không có khoản vay/nợ nào.
      await phat(_tk(2026, 9, lat: _latChiThu));

      expect((cubit.state as AnalyticsLoaded).phanLoaiDangXem, 'chi',
          reason: 'Giữ lựa chọn trỏ vào nhóm không tồn tại là vẽ một vòng tròn '
              'trống dưới một chip đã biến mất');
    });

    test('BẪY 2b: Chi cũng rỗng thì rơi về nhóm đầu còn phát sinh', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: const [
        LatPhanLoai(phanLoai: 'thu', soTien: 100, tiLe: 1),
      ]));

      expect((cubit.state as AnalyticsLoaded).phanLoaiDangXem, 'thu',
          reason: 'Tháng chỉ có thu mà vẫn chọn sẵn Chi là donut trống dù có '
              'dữ liệu để vẽ');
    });

    test('BẪY 3: danh mục biến mất thì bị LOẠI khỏi tập, phần còn lại giữ',
        () async {
      cubit.xem(10);
      await phat(_tk(2026, 9,
          lat: _latChiThu, chuoiDm: {'an': const [], 'di': const []}));
      cubit.batTatDanhMucXuHuong('an');
      cubit.batTatDanhMucXuHuong('di');

      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'di': const []}));

      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong, {'di'},
          reason: 'Danh mục bị xoá hay đổi tháng thì khoá không còn — đọc '
              'chuoiDanhMuc[id]! khi ấy là nổ. Nhưng chỉ loại đúng khoá ấy: '
              'xoá cả tập là người dùng mất luôn những đường còn hợp lệ');
    });

    test('bật rồi tắt cùng một danh mục', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'an': const []}));

      cubit.batTatDanhMucXuHuong('an');
      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong, {'an'});

      cubit.batTatDanhMucXuHuong('an');
      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong, isEmpty,
          reason: 'Bỏ chọn hết là về hai đường Thu/Chi');
    });

    test('TRẦN: danh mục thứ sáu KHÔNG được bật, tắt một cái thì bật được',
        () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {
        for (final k in ['a', 'b', 'c', 'd', 'e', 'f']) k: const <DiemThoiGian>[],
      }));
      for (final k in ['a', 'b', 'c', 'd', 'e']) {
        cubit.batTatDanhMucXuHuong(k);
      }
      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong.length,
          kToiDaDuongXuHuong);

      cubit.batTatDanhMucXuHuong('f');
      final s = cubit.state as AnalyticsLoaded;
      expect(s.danhMucXuHuong, isNot(contains('f')),
          reason: 'Quá $kToiDaDuongXuHuong đường ở 411dp là một búi chỉ không '
              'đọc được; chip thứ sáu phải bị khoá chứ không âm thầm đè lên');

      cubit.batTatDanhMucXuHuong('a');
      cubit.batTatDanhMucXuHuong('f');
      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong,
          {'b', 'c', 'd', 'e', 'f'});
    });

    test('đổi tháng thì nhóm về Chi, danh mục xu hướng GIỮ', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'an': const []}));
      cubit.chonPhanLoai('thu');
      cubit.batTatDanhMucXuHuong('an');

      cubit.chonThang(2026, 8);
      await phat(_tk(2026, 8, lat: _latChiThu, chuoiDm: {'an': const []}));

      final s = cubit.state as AnalyticsLoaded;
      expect(s.phanLoaiDangXem, 'chi',
          reason: 'Đổi tháng là đổi câu hỏi — bắt đầu lại từ Chi');
      expect(s.danhMucXuHuong, {'an'},
          reason: 'Chuỗi xu hướng nhìn xa sáu tháng nên vẫn có nghĩa ở tháng '
              'khác — giữ lựa chọn');
    });

    test('chonPhanLoai / batTat không làm gì khi chưa có dữ liệu', () {
      cubit.chonPhanLoai('chi');
      cubit.batTatDanhMucXuHuong('an');
      expect(cubit.state, isA<AnalyticsInitial>());
    });
  });
}
