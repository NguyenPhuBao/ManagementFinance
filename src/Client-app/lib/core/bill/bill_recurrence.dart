/// Chu kỳ lặp của hoá đơn.
///
/// Bộ giá trị lấy đúng theo cột `timeRecurrence` (`Bills` trên client,
/// `Time_recurrence` trên backend). Đây là cách biểu diễn CHÍNH THỨC — cột
/// `recurrence` dạng chuỗi cũ ('once'/'weekly'/…) chỉ còn để tương thích
/// ngược và được suy ra từ cặp `isRecurrence` + `timeRecurrence`.
library;

const String kBillCycleWeek = 'Week';
const String kBillCycleMonth = 'Month';
const String kBillCycleQuarter = 'Quarter';
const String kBillCycleYear = 'Year';

/// Mốc đến hạn của kỳ kế tiếp, tính từ [current] theo [timeRecurrence].
///
/// Cộng tháng/quý/năm bằng `DateTime(y, m + n, d)` là **sai**: hàm dựng
/// `DateTime` cho phép ngày tràn, nên 31/01 + 1 tháng cho ra 03/03 — hoá đơn
/// nhảy qua hẳn tháng 2. Ở đây ngày được **kẹp** vào ngày cuối cùng của tháng
/// đích, đúng như cách người dùng hiểu "hàng tháng vào ngày 31".
///
/// Chu kỳ không nhận ra thì trả nguyên [current]: backend có thể thêm giá trị
/// mới cho `Time_recurrence`, và đoán bừa một chu kỳ sai còn tệ hơn là để mốc
/// đứng yên cho người dùng tự sửa.
DateTime nextBillDueDate(DateTime current, String timeRecurrence) {
  switch (timeRecurrence) {
    case kBillCycleWeek:
      return current.add(const Duration(days: 7));
    case kBillCycleMonth:
      return _addMonths(current, 1);
    case kBillCycleQuarter:
      return _addMonths(current, 3);
    case kBillCycleYear:
      return _addMonths(current, 12);
    default:
      return current;
  }
}

/// Số ngày của tháng [month]/[year]. Ngày 0 của tháng kế tiếp chính là ngày
/// cuối cùng của tháng đang xét.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Cộng [months] tháng, áp **quy tắc ngày cuối tháng**.
///
/// Nếu [from] rơi đúng vào ngày cuối cùng của tháng nó thì kết quả cũng là
/// ngày cuối cùng của tháng đích; ngược lại giữ nguyên số ngày, kẹp lại nếu
/// tháng đích ngắn hơn.
///
/// Vì sao cần: chuỗi hoá đơn nối đuôi nhau (ngày bắt đầu kỳ sau = ngày đến hạn
/// kỳ trước) nên không còn mốc gốc để neo như `advancePeriodFrom` bên ngân
/// sách. Nếu chỉ kẹp ngày, mốc "ngày 31 hàng tháng" đi qua tháng Hai một lần
/// là tụt về 28 và **không bao giờ quay lại**.
///
/// Đánh đổi đã biết: quy tắc này không phân biệt được "cuối tháng" với "một
/// ngày cụ thể tình cờ là cuối tháng". Hoá đơn đặt ngày 28/02 vì muốn *ngày
/// 28 hàng tháng* sẽ bị đẩy sang 31/03. Chấp nhận có chủ ý (quyết định
/// 2026-09-04): với hoá đơn thật, ý "cuối tháng" phổ biến hơn hẳn, và cách duy
/// nhất để phân biệt là thêm một cột mới ở cả hai đầu.
DateTime _addMonths(DateTime from, int months) {
  // `month` chạy 1..12 nên phải quy về gốc 0 trước khi chia lấy dư, nếu không
  // tháng 12 + 1 sẽ ra năm sai.
  final totalMonths = (from.year * 12 + (from.month - 1)) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;

  final daysInTargetMonth = _daysInMonth(year, month);
  final laCuoiThang = from.day == _daysInMonth(from.year, from.month);
  final day = laCuoiThang
      ? daysInTargetMonth
      : (from.day <= daysInTargetMonth ? from.day : daysInTargetMonth);

  return DateTime(
    year,
    month,
    day,
    from.hour,
    from.minute,
    from.second,
    from.millisecond,
    from.microsecond,
  );
}

/// Quy đổi chuỗi chu kỳ cũ sang bộ giá trị của `timeRecurrence`.
///
/// Trả `null` cho 'once' và mọi chuỗi không nhận ra: cột `timeRecurrence`
/// không có giá trị nào mang nghĩa "không lặp" — việc đó do cờ `isRecurrence`
/// biểu diễn.
String? timeRecurrenceFromLegacy(String legacy) {
  switch (legacy) {
    case 'weekly':
      return kBillCycleWeek;
    case 'monthly':
      return kBillCycleMonth;
    case 'quarterly':
      return kBillCycleQuarter;
    case 'yearly':
      return kBillCycleYear;
    default:
      return null;
  }
}

/// Quy đổi ngược: từ `timeRecurrence` về chuỗi chu kỳ cũ.
String legacyFromTimeRecurrence(String timeRecurrence) {
  switch (timeRecurrence) {
    case kBillCycleWeek:
      return 'weekly';
    case kBillCycleMonth:
      return 'monthly';
    case kBillCycleQuarter:
      return 'quarterly';
    case kBillCycleYear:
      return 'yearly';
    default:
      return 'once';
  }
}
