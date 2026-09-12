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
DateTime nextBillDueDate(
  DateTime current,
  String timeRecurrence, {
  int? anchorDay,
}) {
  switch (timeRecurrence) {
    case kBillCycleWeek:
      // Tuần không có khái niệm ngày trong tháng, nên [anchorDay] không áp
      // dụng: cộng đúng 7 ngày.
      return current.add(const Duration(days: 7));
    case kBillCycleMonth:
      return _addMonths(current, 1, anchorDay);
    case kBillCycleQuarter:
      return _addMonths(current, 3, anchorDay);
    case kBillCycleYear:
      return _addMonths(current, 12, anchorDay);
    default:
      return current;
  }
}

/// Số ngày của tháng [month]/[year]. Ngày 0 của tháng kế tiếp chính là ngày
/// cuối cùng của tháng đang xét.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Cộng [months] tháng, giữ [anchorDay] và **kẹp** khi tháng đích ngắn hơn.
///
/// [anchorDay] là ngày trong tháng mà người dùng thật sự chọn khi tạo hoá đơn —
/// nó đi theo suốt chuỗi. Bỏ trống thì lấy ngày của [from], tức chuỗi tự neo
/// vào chính mốc hiện tại.
///
/// ## Vì sao là ngày gốc chứ không phải quy tắc "cuối tháng"
///
/// Bản trước **đoán** ý định từ dữ liệu: nếu [from] rơi đúng ngày cuối tháng
/// thì kỳ sau cũng là ngày cuối tháng. Cú đoán ấy cần thiết vì chuỗi hoá đơn
/// nối đuôi nhau (ngày bắt đầu kỳ sau = ngày kết thúc kỳ trước — trước v21 là
/// ngày đến hạn) nên số ngày gốc
/// biến mất sau kỳ thứ hai — nhìn vào một mốc 28/02 đơn độc thì không biết nó
/// từ 31/01 tới hay do người dùng tự chọn.
///
/// Nhưng nó sai với **người đăng ký lần đầu vào 28/02**: họ muốn ngày 28 hàng
/// tháng và nhận về 31/03, 30/04… Lỗi này người dùng báo ngày 2026-09-08, và
/// nó còn phụ thuộc năm nhuận: 28/02/2026 bị đẩy lên 31/03, còn 28/02/2028 thì
/// không, vì năm nhuận 28/02 không phải cuối tháng.
///
/// Nay ngày gốc được **lưu** (cột `Bills.anchorDay`) nên không phải đoán nữa:
/// hai chuỗi cùng đi qua 28/02 vẫn tách được nhau. Đây đúng là mô hình
/// `advancePeriodFrom(anchor, steps)` mà ngân sách dùng từ đầu, nên ba vùng
/// ngày tháng của app nay nói cùng một thứ tiếng.
///
/// Còn lại một khác biệt **chưa** biểu diễn được: "ngày 31" với "ngày cuối
/// tháng" là hai ý định khác nhau mà ngày gốc gộp làm một. Thực tế chúng gần
/// trùng (gốc 31 kẹp lại chính là cuối tháng ở mọi tháng), nên chỉ lệch với
/// người muốn "cuối tháng" mà lại đăng ký đúng vào tháng Hai. Muốn chặt hơn thì
/// hỏi thẳng người dùng bằng một công tắc trên form, đừng đoán lại lần nữa.
DateTime _addMonths(DateTime from, int months, [int? anchorDay]) {
  // `month` chạy 1..12 nên phải quy về gốc 0 trước khi chia lấy dư, nếu không
  // tháng 12 + 1 sẽ ra năm sai.
  final totalMonths = (from.year * 12 + (from.month - 1)) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;

  final daysInTargetMonth = _daysInMonth(year, month);
  final mongMuon = anchorDay ?? from.day;
  final day = mongMuon <= daysInTargetMonth ? mongMuon : daysInTargetMonth;

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

/// Nhãn tiếng Việt của chu kỳ, dùng chung cho form và trang chi tiết.
String tenChuKyHoaDon(String timeRecurrence) => switch (timeRecurrence) {
      kBillCycleWeek => 'Hàng tuần',
      kBillCycleMonth => 'Hàng tháng',
      kBillCycleQuarter => 'Hàng quý',
      kBillCycleYear => 'Hàng năm',
      _ => timeRecurrence,
    };
