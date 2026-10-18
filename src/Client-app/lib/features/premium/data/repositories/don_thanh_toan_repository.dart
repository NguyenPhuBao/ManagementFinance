import '../../domain/trang_thai_don.dart';
import '../models/don_thanh_toan.dart';
import '../models/dong_lich_su.dart';

/// Đơn thanh toán Premium — một lối cho mọi màn (spec G94 2026-10-18 mục 4.2; KIEN_TRUC mục 5: trang → repository).
/// Mọi lỗi ném ra là `LoiThanhToan` (`domain/cau_loi_thanh_toan.dart`) — giao diện không nhìn thấy Dio.
abstract class DonThanhToanRepository {
  /// `POST /payment/create-order`. Đơn thiếu `orderCode` / `checkoutUrl` → `LoiThanhToan(khac)`.
  Future<DonThanhToan> taoDon();

  /// `GET /payment/order-status/:orderCode` → trạng thái (chuỗi lạ là `pending`).
  Future<TrangThaiDon> trangThaiDon(int orderCode);

  /// `GET /payment/history`, trang 1 (20 dòng).
  Future<List<DongLichSu>> lichSu();

  /// `POST /payment/confirm-upgrade`.
  Future<void> xacNhan({required int orderCode, required bool accept});
}
