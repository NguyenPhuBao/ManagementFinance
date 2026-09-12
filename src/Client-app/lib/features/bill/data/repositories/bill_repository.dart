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

/// Ném ra khi bỏ qua một kỳ mà CSDL đã ghi nhận là bỏ qua rồi.
///
/// Cần ngoại lệ riêng vì hệ quả của lần chạy thứ hai không vô hại: mỗi lần bỏ
/// qua sinh một kỳ kế tiếp, nên chạy hai lần là hai hoá đơn cùng hạn và người
/// dùng không hiểu cái thứ hai ở đâu ra.
class BillAlreadySkippedException implements Exception {
  final String billId;
  const BillAlreadySkippedException(this.billId);

  @override
  String toString() => 'Hoá đơn $billId đã được bỏ qua trước đó.';
}

/// Ném ra khi hoàn tác việc bỏ qua trên một kỳ không hề bị bỏ qua.
///
/// Đặc biệt chặn cả kỳ **đã trả**: hoàn tác một lần trả phải đi qua
/// [BillRepository.undoPayment], thứ có bước hoàn tiền. Đi nhầm đường này là
/// hoá đơn về `Pending` mà tiền vẫn nằm ngoài ví và khoản chi vẫn còn trong sổ.
class BillNotSkippedException implements Exception {
  final String billId;
  const BillNotSkippedException(this.billId);

  @override
  String toString() => 'Hoá đơn $billId không ở trạng thái bỏ qua.';
}

/// Ném ra khi thanh toán một kỳ đã bị bỏ qua.
///
/// Kỳ `Skipped` **đã sinh kỳ kế tiếp**. Cho [BillRepository.payBill] chạy tiếp
/// trên nó là sinh kỳ thứ hai trùng hạn. Người dùng phải hoàn tác việc bỏ qua
/// trước — giao diện cũng chỉ bày nút "Hoàn tác bỏ qua" cho kỳ này.
class BillSkippedCannotPayException implements Exception {
  final String billId;
  const BillSkippedCannotPayException(this.billId);

  @override
  String toString() =>
      'Hoá đơn $billId đang ở trạng thái bỏ qua; hãy hoàn tác trước khi trả.';
}

abstract class BillRepository {
  Stream<List<Bill>> watchBills(int idaccount);
  Future<List<Bill>> getBills(int idaccount);

  /// Khoản chi của từng hoá đơn đã trả, theo `billId`.
  ///
  /// Chỉ có với khoản trả ghi từ v16 trên chính máy này; hàng kéo về từ
  /// server vắng mặt và nơi gọi phải hiện "không biết" chứ không đoán.
  Future<Map<String, Transaction>> paymentsOf(int idaccount);
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
  ///
  /// [note] là ghi chú **của lần trả này** (số công tơ, mã giao dịch…), khác
  /// ghi chú cố định trên hoá đơn. Được nối vào SAU tiền tố `kGhiChuTraHoaDon`
  /// — tiền tố là thứ sổ giao dịch dùng để nhận diện khoản của hoá đơn.
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
    double? amount,
    DateTime? occurredAt,
    String? note,
  });

  /// Hoàn tác lần thanh toán của hoá đơn [billId].
  ///
  /// Hoàn trọn ba hệ quả mà [payBill] đã tạo ra: đưa hoá đơn về `Pending`,
  /// xoá mềm khoản chi và trả tiền lại đúng ví đã trừ, xoá mềm kỳ kế tiếp đã
  /// sinh ra.
  Future<void> undoPayment({required String billId});

  /// Bỏ qua kỳ [billId]: đánh dấu `Skipped`, **không** sinh khoản chi và
  /// **không** trừ ví, nhưng vẫn sinh kỳ kế tiếp như [payBill] để chuỗi hoá
  /// đơn lặp không đứt.
  ///
  /// Dành cho kỳ thật sự không phải trả: đi vắng cả tháng nên không có tiền
  /// điện, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ. Khác xoá ở chỗ kỳ ấy
  /// vẫn nằm trong lịch sử, và mắt xích `generatedFromBillId` không đứt.
  Future<void> skipBill({required String billId});

  /// Hoàn tác việc bỏ qua kỳ [billId]: về `Pending`, xoá mềm kỳ kế tiếp đã
  /// sinh. **Không** có bước hoàn tiền — chưa từng trừ tiền.
  Future<void> undoSkip({required String billId});
}
