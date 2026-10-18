import '../../domain/cau_loi_thanh_toan.dart';
import '../../domain/trang_thai_don.dart';
import '../datasources/payment_api.dart';
import '../models/don_thanh_toan.dart';
import '../models/dong_lich_su.dart';
import 'don_thanh_toan_repository.dart';

class DonThanhToanRepositoryImpl implements DonThanhToanRepository {
  DonThanhToanRepositoryImpl({required PaymentApi api, DateTime Function()? clock})
      : _api = api,
        _now = clock ?? DateTime.now;

  final PaymentApi _api;

  /// Mốc cho hạn dự phòng của `donTuJson` khi server thiếu `expiredAt`.
  final DateTime Function() _now;

  /// Mọi lỗi → `LoiThanhToan` đã phân loại; `LoiThanhToan` ném từ bên trong giữ nguyên loại.
  Future<T> _boc<T>(Future<T> Function() viec) async {
    try {
      return await viec();
    } catch (e) {
      throw LoiThanhToan(loaiLoiThanhToanTu(e));
    }
  }

  @override
  Future<DonThanhToan> taoDon() => _boc(() async {
        final don = donTuJson(await _api.taoDon(), now: _now());
        if (don == null) throw const LoiThanhToan(LoaiLoiThanhToan.khac);
        return don;
      });

  @override
  Future<TrangThaiDon> trangThaiDon(int orderCode) =>
      _boc(() async => trangThaiDonTuChuoi((await _api.trangThaiDon(orderCode))['status']));

  @override
  Future<List<DongLichSu>> lichSu() => _boc(() async => dongLichSuTu(await _api.lichSu()));

  @override
  Future<void> xacNhan({required int orderCode, required bool accept}) => _boc(() async {
        await _api.xacNhanNangCap(orderCode: orderCode, accept: accept);
      });
}
