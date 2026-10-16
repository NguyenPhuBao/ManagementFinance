import 'bill_recurrence.dart';

/// Giá trị người dùng nhập trên form hoá đơn.
///
/// Tách khỏi widget để phần dựng companion (`data/models/bill_draft_companion.dart`) — nơi từng đánh rơi
/// `walletId`/`categoryId` và ghi chu kỳ vào sai cột — kiểm thử được mà không
/// cần dựng cả cây widget.
class BillDraft {
  final String name;
  final double amount;

  /// Ngày bắt đầu kỳ hoá đơn. Người dùng chọn trên form, ngay phía trên ngày
  /// đến hạn. Trước đây cột này bị đặt cứng bằng thời điểm bấm Lưu.
  final DateTime startDate;

  final DateTime dueDate;

  /// Ngày kết thúc kỳ tính tiền. `null` (test/đường cũ) = trùng [dueDate].
  /// Giá trị GHI XUỐNG thì không bao giờ vắng — xem [periodEndHieuLuc].
  final DateTime? periodEnd;

  /// Ví thanh toán. `bill.Idwallet` là NOT NULL phía backend.
  final String walletId;

  /// Danh mục chi. `bill.Idcategory` là NOT NULL phía backend.
  final String categoryId;

  final bool isRecurring;

  /// Một trong `kBillCycle*`. Chỉ có nghĩa khi [isRecurring].
  final String timeRecurrence;

  /// Số ngày nhắc trước hạn: '1' | '3' | '5' | '7', hoặc `null` = tắt nhắc.
  ///
  /// Backend ràng buộc `Time_notification IN ('1','3','5','7')` **hoặc NULL**,
  /// nên tắt nhắc phải ghi null chứ không phải chuỗi rỗng.
  final String? timeNotification;

  final String note;

  /// App tự trả hoá đơn này vào ngày đến hạn, trừ từ [walletId].
  ///
  /// Mặc định **tắt**: tự chuyển tiền là quyết định người dùng phải bật, không
  /// phải thứ app mặc định làm hộ. Cột v17; ✅ **đi qua đồng bộ từ 2026-09-13**
  /// (khoá `auto_pay`) nên công tắc theo *hoá đơn* chứ không theo *máy* — xem
  /// `Bills.autoPayEnabled`.
  final bool autoPayEnabled;

  /// Ngày trong tháng người dùng thật sự chọn — xem `Bills.anchorDay`.
  ///
  /// `null` thì suy từ ngày của [startDate]. Hai thứ chỉ khác nhau ở hoá đơn
  /// thuộc chuỗi, mà chuỗi thì không đi qua form này.
  final int? anchorDay;

  const BillDraft({
    required this.name,
    required this.amount,
    required this.startDate,
    required this.dueDate,
    this.periodEnd,
    required this.walletId,
    required this.categoryId,
    required this.isRecurring,
    required this.timeRecurrence,
    required this.note,
    this.timeNotification,
    this.autoPayEnabled = false,
    this.anchorDay,
  });

  /// Ngày gốc sẽ ghi xuống. Suy từ [startDate] khi form chưa đặt.
  int get anchorDayHieuLuc => anchorDay ?? startDate.day;

  /// Luôn có giá trị: NULL trong bảng phải chỉ còn nghĩa "hàng cũ, chưa biết"
  /// (xem `Bills.periodEnd`). Ân hạn 0 thì bằng [dueDate].
  DateTime get periodEndHieuLuc => periodEnd ?? dueDate;

  /// Chuỗi chu kỳ cũ, suy ra từ [isRecurring] + [timeRecurrence].
  ///
  /// Hai cách biểu diễn phải được ghi CÙNG LÚC và khớp nhau: nhánh đẩy đọc cờ
  /// `isRecurrence`, còn một số đường cũ vẫn đọc chuỗi này.
  String get legacyRecurrence =>
      isRecurring ? legacyFromTimeRecurrence(timeRecurrence) : 'once';

  /// Lời nhắn lỗi nếu hai mốc ngày không hợp lệ, `null` nếu hợp lệ.
  ///
  /// Kỳ hoá đơn chạy từ [startDate] tới [dueDate], nên [startDate] phải nằm
  /// TRƯỚC — trùng ngày cũng không được: kỳ dài 0 ngày, và vì kỳ kế tiếp bắt
  /// đầu đúng tại ngày đến hạn của kỳ này, chuỗi sẽ giậm chân tại chỗ.
  String? get dateError => startDate.isBefore(dueDate)
      ? null
      : 'Ngày bắt đầu phải trước ngày đến hạn thanh toán';
}
