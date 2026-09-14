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

    test('mặc định là mức gốc và hai đường', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu));

      final s = cubit.state as AnalyticsLoaded;
      expect(s.phanLoaiDangXem, isNull);
      expect(s.danhMucXuHuong, isNull);
    });

    test('BẪY 1: stream phát lại KHÔNG làm mất lựa chọn', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'an': const []}));

      cubit.chonPhanLoai('chi');
      cubit.chonDanhMucXuHuong('an');

      // Đồng bộ nền kéo về một thay đổi bất kỳ → repository phát lại.
      await phat(
          _tk(2026, 9, chi: 99, lat: _latChiThu, chuoiDm: {'an': const []}));

      final s = cubit.state as AnalyticsLoaded;
      expect(s.thongKe.tong.chi, 99, reason: 'Số liệu mới phải tới nơi');
      expect(s.phanLoaiDangXem, 'chi',
          reason: 'Quên chép lựa chọn sang state mới thì cứ mỗi chu kỳ đồng bộ '
              'là donut nhảy về mức gốc TRONG KHI người dùng đang xem — không '
              'exception, không log');
      expect(s.danhMucXuHuong, 'an');
    });

    test('BẪY 2: lát biến mất thì rơi về mức gốc', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: const [
        LatPhanLoai(phanLoai: 'vay_no', soTien: 100, tiLe: 1),
      ]));
      cubit.chonPhanLoai('vay_no');

      // Tháng mới không có khoản vay/nợ nào.
      await phat(_tk(2026, 9, lat: _latChiThu));

      expect((cubit.state as AnalyticsLoaded).phanLoaiDangXem, isNull,
          reason: 'Giữ lựa chọn trỏ vào lát không tồn tại là vẽ một vòng tròn '
              'trống mà không nút nào thoát ra được');
    });

    test('BẪY 3: danh mục biến mất thì rơi về hai đường', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'an': const []}));
      cubit.chonDanhMucXuHuong('an');

      await phat(_tk(2026, 9, lat: _latChiThu, chuoiDm: {'di': const []}));

      expect((cubit.state as AnalyticsLoaded).danhMucXuHuong, isNull,
          reason: 'Danh mục bị xoá hay đổi tháng thì khoá không còn — đọc '
              'chuoiDanhMuc[id]! khi ấy là nổ');
    });

    test('đổi tháng thì lựa chọn lát về mức gốc', () async {
      cubit.xem(10);
      await phat(_tk(2026, 9, lat: _latChiThu));
      cubit.chonPhanLoai('chi');

      cubit.chonThang(2026, 8);
      await phat(_tk(2026, 8, lat: _latChiThu));

      expect((cubit.state as AnalyticsLoaded).phanLoaiDangXem, isNull,
          reason: 'Đổi tháng là đổi câu hỏi — bắt đầu lại từ mức gốc');
    });

    test('chonPhanLoai không làm gì khi chưa có dữ liệu', () {
      cubit.chonPhanLoai('chi');
      expect(cubit.state, isA<AnalyticsInitial>());
    });
  });
}
