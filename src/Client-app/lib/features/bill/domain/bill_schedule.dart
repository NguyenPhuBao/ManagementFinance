import 'package:intl/intl.dart';
import '../../../core/bill/bill_recurrence.dart';
import '../../../core/database/app_database.dart';

/// Lịch của một hoá đơn.
///
/// **Hoá đơn luôn có một chu kỳ** — khác màn ngân sách, nơi còn lựa chọn "Ngày
/// cụ thể" để tự nhập ngày kết thúc. Quyết định 2026-09-04: hoá đơn không cần
/// đường thoát đó, nên [dueDate] **luôn** suy ra từ [startDate] + chu kỳ và ô
/// "Ngày đến hạn" trên form là chỉ đọc.
///
/// Còn lại đúng một công tắc, [repeat]: thanh toán xong có sinh kỳ mới không.
/// Nó độc lập với chu kỳ, nên trạng thái *"hạn trả tính theo chu kỳ tháng
/// nhưng chỉ chạy một kỳ"* vẫn diễn đạt được.
class BillSchedule {
  final DateTime startDate;

  /// Một trong `kBillCycle*`. Không bao giờ null.
  final String timeRecurrence;

  final bool repeat;

  /// Hạn trả đang lưu trong bản ghi khi nó **không khớp** chu kỳ.
  ///
  /// Chỉ để cảnh báo, không phải giá trị sẽ ghi xuống. Xem [canhBaoHanCu].
  final DateTime? hanCuKhongKhop;

  const BillSchedule({
    required this.startDate,
    required this.timeRecurrence,
    required this.repeat,
    this.hanCuKhongKhop,
  });

  /// Ngày đến hạn — luôn do chu kỳ quyết định.
  DateTime get dueDate => nextBillDueDate(startDate, timeRecurrence);

  bool get isRecurring => repeat;

  /// Giá trị ghi vào cột `timeRecurrence` (NOT NULL bên client).
  String get storedTimeRecurrence => timeRecurrence;

  /// Bất biến: ngày bắt đầu phải nằm trước ngày đến hạn.
  ///
  /// Với mọi chu kỳ hợp lệ thì điều này luôn đúng, nhưng giữ lại làm lưới an
  /// toàn cho trường hợp `timeRecurrence` mang một giá trị lạ từ backend —
  /// `nextBillDueDate` khi đó trả nguyên mốc cũ.
  String? get dateError => startDate.isBefore(dueDate)
      ? null
      : 'Chu kỳ "$timeRecurrence" không tính được ngày đến hạn hợp lệ';

  /// Lời cảnh báo khi bản ghi đang mang một hạn trả không khớp chu kỳ.
  ///
  /// Hoá đơn do bản client cũ, hoặc do Admin-web, có thể có cửa sổ trả bất kỳ
  /// (bắt đầu 04/09, hạn 11/09, chu kỳ tháng). Nay hạn luôn suy từ chu kỳ, nên
  /// mở form ra rồi lưu lại là **đổi hạn trả của người dùng**. Đổi mà không
  /// nói gì đúng là lớp lỗi âm thầm mà dự án này đã dính nhiều lần, nên phải
  /// báo ra.
  String? get canhBaoHanCu {
    final cu = hanCuKhongKhop;
    if (cu == null) return null;
    final f = DateFormat('dd/MM/yyyy');
    return 'Hoá đơn này đang có hạn trả ${f.format(cu)}, không khớp chu kỳ đã '
        'chọn. Lưu lại sẽ đổi thành ${f.format(dueDate)}.';
  }

  BillSchedule copyWith({
    DateTime? startDate,
    String? timeRecurrence,
    bool? repeat,
  }) {
    final moi = BillSchedule(
      startDate: startDate ?? this.startDate,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      repeat: repeat ?? this.repeat,
      hanCuKhongKhop: hanCuKhongKhop,
    );
    // Người dùng vừa chỉnh cho khớp lại thì cảnh báo tự tắt.
    return moi.hanCuKhongKhop == moi.dueDate
        ? BillSchedule(
            startDate: moi.startDate,
            timeRecurrence: moi.timeRecurrence,
            repeat: moi.repeat,
          )
        : moi;
  }

  static BillSchedule fromBill(Bill bill) {
    final batDau = bill.startDate ?? bill.dueDate;
    final hanTheoChuKy = nextBillDueDate(batDau, bill.timeRecurrence);
    return BillSchedule(
      startDate: batDau,
      timeRecurrence: bill.timeRecurrence,
      repeat: bill.isRecurrence,
      hanCuKhongKhop: hanTheoChuKy == bill.dueDate ? null : bill.dueDate,
    );
  }
}
