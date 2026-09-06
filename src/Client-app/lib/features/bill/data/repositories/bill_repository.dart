import '../../../../core/database/app_database.dart';

/// Ném ra khi [BillRepository.payBill] được gọi trên một hoá đơn mà CSDL đã
/// ghi nhận là đã thanh toán.
///
/// Cần một ngoại lệ riêng vì UI truyền vào đối tượng `Bill` nó đang giữ — một
/// ảnh chụp có thể đã cũ. Bấm nút hai lần thì lần thứ hai vẫn mang `isPaid =
/// false`, nên trạng thái thật phải đọc lại từ CSDL chứ không tin tham số.
class BillAlreadyPaidException implements Exception {
  final String billId;
  const BillAlreadyPaidException(this.billId);

  @override
  String toString() => 'Hoá đơn $billId đã được thanh toán trước đó.';
}

/// Ném ra khi số tiền trả không dương.
///
/// Kiểm ở tầng repository chứ không chỉ ở ô nhập: ô nhập nằm **ngoài** khối
/// nguyên tử, cùng bài học với `depositToGoal` (mục 3.16 `GOAL_FEATURE.md`).
class BillInvalidAmountException implements Exception {
  final double amount;
  const BillInvalidAmountException(this.amount);

  @override
  String toString() => 'Số tiền thanh toán phải lớn hơn 0 (nhận $amount).';
}

/// Ném ra khi hoàn tác một hoá đơn CSDL đang ghi nhận là chưa thanh toán.
class BillNotPaidException implements Exception {
  final String billId;
  const BillNotPaidException(this.billId);

  @override
  String toString() => 'Hoá đơn $billId chưa được thanh toán.';
}

/// Ném ra khi không lần được từ hoá đơn về khoản chi mà lần trả đã sinh ra.
///
/// Sợi dây ấy là cột **cục bộ** `transactions.billId`, có từ schema v16
/// (2026-09-06). Khoản trả ghi bằng bản app cũ, và mọi hàng kéo về từ server,
/// đều để trống nó. Từ chối có thông báo rõ thay vì đoán theo tiền tố ghi chú
/// cộng số tiền cộng ngày: đoán trượt ở đây nghĩa là hoàn tiền vào ví bằng một
/// khoản chi **khác** của người dùng.
class BillUndoUnavailableException implements Exception {
  final String billId;
  const BillUndoUnavailableException(this.billId);

  @override
  String toString() =>
      'Không hoàn tác được hoá đơn $billId: khoản chi tương ứng được ghi bằng '
      'bản ứng dụng cũ nên không lần lại được.';
}

abstract class BillRepository {
  Stream<List<Bill>> watchBills(int idaccount);
  Future<List<Bill>> getBills(int idaccount);
  Future<void> addBill(BillsCompanion bill);
  Future<void> editBill(BillsCompanion bill);
  Future<void> deleteBill(String id);

  /// Thanh toán [bill] bằng ví [walletId].
  ///
  /// [amount] là số tiền **thật của kỳ này**; bỏ trống thì dùng số đã lưu trên
  /// hoá đơn. Hoá đơn kiểu điện nước mỗi kỳ một số khác nhau, và đổi qua form
  /// Sửa là đổi cho MỌI kỳ sau chứ không riêng kỳ này.
  ///
  /// [occurredAt] là ngày của **giao dịch** sinh ra; bỏ trống là lúc trả.
  /// Chỉ bộ tự động thanh toán truyền nó — khoản trả **bù** phải mang ngày đến
  /// hạn của kỳ, nếu không ba kỳ bù dồn thành một cột ở ngày mở app trong
  /// thống kê theo ngày (cùng lý do với mục 3.14 `GOAL_FEATURE.md`). Không
  /// được ở tương lai. `updatedAt` của giao dịch vẫn là "bây giờ".
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
    double? amount,
    DateTime? occurredAt,
  });

  /// Hoàn tác lần thanh toán của hoá đơn [billId].
  ///
  /// Hoàn trọn ba hệ quả mà [payBill] đã tạo ra: đưa hoá đơn về `Pending`,
  /// xoá mềm khoản chi và trả tiền lại đúng ví đã trừ, xoá mềm kỳ kế tiếp đã
  /// sinh ra.
  Future<void> undoPayment({required String billId});
}
