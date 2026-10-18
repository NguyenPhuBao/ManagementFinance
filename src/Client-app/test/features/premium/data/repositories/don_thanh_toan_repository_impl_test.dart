/// `DonThanhToanRepositoryImpl` (spec G94 2026-10-18 mục 4.2): bọc bốn thao tác có sẵn của `PaymentApi`, đọc JSON
/// bằng model, và ném MỌI lỗi thành `LoiThanhToan` đã phân loại — giao diện không nhìn thấy Dio.
library;

import 'package:dio/dio.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository_impl.dart';
import 'package:flowmoney/features/premium/domain/cau_loi_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_don.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiGia implements PaymentApi {
  Map<String, Object?> don = {
    'orderCode': 200370869,
    'checkoutUrl': 'https://pay.payos.vn/web/abc',
    'amount': 49000,
    'expiredAt': '2026-10-18T10:10:00.000Z',
  };
  String trangThai = 'PAID';
  List<Map<String, Object?>> lichSuTho = [
    {'order_code': 1, 'amount': 49000, 'status': 'PAID', 'paid_at': '2026-10-01T01:00:00.000Z'},
  ];
  Object? loi;
  int? xacNhanMa;
  bool? xacNhanChapNhan;

  Future<T> _hoac<T>(T v) async {
    final l = loi;
    if (l != null) throw l;
    return v;
  }

  @override
  Future<Map<String, Object?>> taoDon() => _hoac(don);
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => _hoac({'status': trangThai});
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => _hoac(lichSuTho);
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) {
    xacNhanMa = orderCode;
    xacNhanChapNhan = accept;
    return _hoac(const {'success': true});
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
}

void main() {
  final now = DateTime.utc(2026, 10, 18, 10);
  late _ApiGia api;
  late DonThanhToanRepositoryImpl repo;
  final req = RequestOptions(path: '/payment/x');

  setUp(() {
    api = _ApiGia();
    repo = DonThanhToanRepositoryImpl(api: api, clock: () => now);
  });

  test('taoDon đọc bằng donTuJson; thiếu checkoutUrl → LoiThanhToan(khac)', () async {
    final don = await repo.taoDon();
    expect(don.orderCode, 200370869);
    expect(don.soTien, 49000);
    api.don = {'orderCode': 1};
    await expectLater(
        repo.taoDon(), throwsA(isA<LoiThanhToan>().having((e) => e.loai, 'loai', LoaiLoiThanhToan.khac)));
  });

  test('trangThaiDon dịch chuỗi; lichSu đọc bằng dongLichSuTu', () async {
    expect(await repo.trangThaiDon(1), TrangThaiDon.paid);
    api.trangThai = 'WAITING_CONFIRMATION';
    expect(await repo.trangThaiDon(1), TrangThaiDon.waitingConfirmation);
    final ds = await repo.lichSu();
    expect(ds.single.orderCode, 1);
    expect(ds.single.trangThai, TrangThaiDon.paid);
  });

  test('xacNhan chuyển đúng mã đơn và lựa chọn', () async {
    await repo.xacNhan(orderCode: 7, accept: false);
    expect(api.xacNhanMa, 7);
    expect(api.xacNhanChapNhan, isFalse);
  });

  test('mọi lỗi → LoiThanhToan đã phân loại (mất mạng · 401 · 5xx · 4xx · lỗi lạ)', () async {
    Future<void> kiem(Object loi, LoaiLoiThanhToan mongDoi) async {
      api.loi = loi;
      await expectLater(repo.lichSu(), throwsA(isA<LoiThanhToan>().having((e) => e.loai, 'loai', mongDoi)),
          reason: '$loi');
    }

    DioException ma(int code) => DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: code));
    await kiem(DioException(requestOptions: req, type: DioExceptionType.connectionError), LoaiLoiThanhToan.matMang);
    await kiem(ma(401), LoaiLoiThanhToan.phienHetHan);
    await kiem(ma(502), LoaiLoiThanhToan.mayChu);
    await kiem(ma(400), LoaiLoiThanhToan.biTuChoi);
    await kiem(StateError('x'), LoaiLoiThanhToan.khac);
  });
}
