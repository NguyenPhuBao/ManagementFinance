/// `ChiTietDonCubit` (spec G94 2026-10-18 mục 5.5): nạp đơn theo mã, xác nhận chuyển thừa. Đồng ý → làm mới gói rồi
/// nạp lại; từ chối → nạp lại; mất mạng → báo, mở nút; bị từ chối (4xx — đơn đã đổi ở nơi khác) → báo + nạp lại.
library;

import 'dart:async';

import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/data/models/dong_lich_su.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/domain/cau_loi_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_don.dart';
import 'package:flowmoney/features/premium/presentation/bloc/chi_tiet_don_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements DonThanhToanRepository {
  /// Kịch bản `timDon` theo lượt; hết kịch bản thì lặp phần tử cuối; rỗng = không thấy.
  final List<DongLichSu?> donLanLuot = [];
  Object? loiTim;
  final List<Object> loiXacNhan = [];
  Completer<void>? chanXacNhan;
  int soLanTim = 0;
  int soLanXacNhan = 0;
  bool? chapNhan;

  @override
  Future<DongLichSu?> timDon(int orderCode) async {
    soLanTim++;
    final l = loiTim;
    if (l != null) throw l;
    if (donLanLuot.isEmpty) return null;
    return donLanLuot.length > 1 ? donLanLuot.removeAt(0) : donLanLuot.first;
  }

  @override
  Future<void> xacNhan({required int orderCode, required bool accept}) async {
    soLanXacNhan++;
    chapNhan = accept;
    final c = chanXacNhan;
    if (c != null) await c.future;
    if (loiXacNhan.isNotEmpty) throw loiXacNhan.removeAt(0);
  }

  @override
  Future<DonThanhToan> taoDon() => throw UnimplementedError();
  @override
  Future<TrangThaiDon> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<DongLichSu>> lichSu() => throw UnimplementedError();
}

class _ApiGoiGia implements PaymentApi {
  int soLanHoiGoi = 0;

  @override
  Future<Map<String, Object?>> thongTinGoi() async {
    soLanHoiGoi++;
    return const {'accountType': 'Premium', 'premiumExpiresAt': '2026-11-17T01:00:00.000Z'};
  }

  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) =>
      throw UnimplementedError();
}

DongLichSu _don(TrangThaiDon t, {int? daChuyen = 60000}) =>
    DongLichSu(orderCode: 9, soTien: 49000, trangThai: t, soDaChuyen: daChuyen);

void main() {
  late _RepoGia repo;
  late _ApiGoiGia apiGoi;
  late GoiRepository goi;
  late ChiTietDonCubit cubit;

  setUp(() async {
    repo = _RepoGia();
    apiGoi = _ApiGoiGia();
    goi = GoiRepository(api: apiGoi, kho: InMemoryGoiStore(), clock: () => DateTime(2026, 10, 18, 10));
    await goi.datTaiKhoan(10);
    cubit = ChiTietDonCubit(orderCode: 9, repo: repo, goi: goi);
  });
  tearDown(() async {
    await cubit.close();
    await goi.dispose();
  });

  test('nap: thấy → ChiTietDonCo; không thấy → ChiTietDonKhongThay; lỗi → ChiTietDonLoi(câu)', () async {
    repo.donLanLuot.add(_don(TrangThaiDon.waitingConfirmation));
    await cubit.nap();
    expect((cubit.state as ChiTietDonCo).don.trangThai, TrangThaiDon.waitingConfirmation);

    final c2 = ChiTietDonCubit(orderCode: 9, repo: _RepoGia(), goi: goi);
    await c2.nap();
    expect(c2.state, isA<ChiTietDonKhongThay>());
    await c2.close();

    final r3 = _RepoGia()..loiTim = const LoiThanhToan(LoaiLoiThanhToan.matMang);
    final c3 = ChiTietDonCubit(orderCode: 9, repo: r3, goi: goi);
    await c3.nap();
    expect((c3.state as ChiTietDonLoi).cau, 'Không có kết nối. Thử lại khi có mạng.');
    await c3.close();
  });

  test('dongY: dangGui → xacNhan(accept: true) → làm mới gói → nạp lại; vuaKichHoat khi đơn đã PAID', () async {
    repo.donLanLuot.addAll([_don(TrangThaiDon.waitingConfirmation), _don(TrangThaiDon.paid)]);
    await cubit.nap();
    final trangThai = <ChiTietDonState>[];
    final sub = cubit.stream.listen(trangThai.add);
    await cubit.dongY();
    await sub.cancel();
    expect((trangThai.first as ChiTietDonCo).dangGui, isTrue, reason: 'hai nút khoá trong lúc gửi');
    expect(repo.chapNhan, isTrue);
    expect(apiGoi.soLanHoiGoi, greaterThanOrEqualTo(1), reason: 'Đồng ý → GoiRepository.lamMoi()');
    final cuoi = cubit.state as ChiTietDonCo;
    expect(cuoi.don.trangThai, TrangThaiDon.paid);
    expect(cuoi.vuaKichHoat, isTrue, reason: 'thân "Đã kích hoạt Premium" + Xong');
    expect(cuoi.dangGui, isFalse);
  });

  test('tuChoi: xacNhan(accept: false) → nạp lại (REFUND_PENDING); KHÔNG làm mới gói', () async {
    repo.donLanLuot.addAll([_don(TrangThaiDon.waitingConfirmation), _don(TrangThaiDon.refundPending)]);
    await cubit.nap();
    final truoc = apiGoi.soLanHoiGoi;
    await cubit.tuChoi();
    expect(repo.chapNhan, isFalse);
    expect(apiGoi.soLanHoiGoi, truoc);
    final cuoi = cubit.state as ChiTietDonCo;
    expect(cuoi.don.trangThai, TrangThaiDon.refundPending);
    expect(cuoi.vuaKichHoat, isFalse);
  });

  test('xác nhận mất mạng → canBao "Không có kết nối…", dangGui về false, KHÔNG nạp lại', () async {
    repo.donLanLuot.add(_don(TrangThaiDon.waitingConfirmation));
    repo.loiXacNhan.add(const LoiThanhToan(LoaiLoiThanhToan.matMang));
    await cubit.nap();
    final bao = cubit.canBao.first;
    await cubit.dongY();
    expect(await bao, 'Không có kết nối. Thử lại khi có mạng.');
    expect((cubit.state as ChiTietDonCo).dangGui, isFalse, reason: 'nút mở lại để thử');
    expect(repo.soLanTim, 1);
  });

  test('xác nhận bị từ chối (4xx) → canBao "Không xác nhận được đơn này…" + nạp lại → thân theo server', () async {
    repo.donLanLuot.addAll([_don(TrangThaiDon.waitingConfirmation), _don(TrangThaiDon.paid)]);
    repo.loiXacNhan.add(const LoiThanhToan(LoaiLoiThanhToan.biTuChoi));
    await cubit.nap();
    final bao = cubit.canBao.first;
    await cubit.dongY();
    expect(await bao, 'Không xác nhận được đơn này. Thử lại sau.');
    expect(repo.soLanTim, 2, reason: 'đơn đã đổi ở nơi khác — màn đi theo server');
    final cuoi = cubit.state as ChiTietDonCo;
    expect(cuoi.don.trangThai, TrangThaiDon.paid);
    expect(cuoi.vuaKichHoat, isFalse, reason: 'không phải màn này kích hoạt');
  });

  test('đang gửi thì bấm lần hai bỏ qua; đóng cubit giữa chừng không ném', () async {
    repo.donLanLuot.add(_don(TrangThaiDon.waitingConfirmation));
    await cubit.nap();
    repo.chanXacNhan = Completer<void>();
    final lan1 = cubit.dongY();
    await Future<void>.delayed(Duration.zero);
    await cubit.tuChoi();
    expect(repo.soLanXacNhan, 1);
    await cubit.close();
    repo.chanXacNhan!.complete();
    await lan1;
  });
}
