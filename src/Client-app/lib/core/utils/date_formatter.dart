import 'package:intl/intl.dart';

/// Định dạng ngày của FlowMoney — **nơi duy nhất** dựng `DateFormat` (test quét `lib/` thứ 32, 2026-10-19).
///
/// Mỗi mẫu đang hiện trên màn một hàm; chữ ra giữ nguyên từng ký tự so với các bản dựng tay trước đó (báo cáo soát
/// kiến trúc 2026-10-18 mục 6, quyết định phiên 2 điểm 6). Cần mẫu mới thì thêm HÀM ở đây, đừng dựng `DateFormat` tại
/// chỗ.
///
/// ⚠️ Mẫu CHỈ CÓ SỐ dựng **không locale**: chữ số ra giống hệt ở mọi locale, và không cần `initializeDateFormatting` —
/// thiếu nó thì `DateFormat(…, 'vi_VN')` ném và cả cây widget dừng dựng (bẫy widget test). Chỉ mẫu có CHỮ (tên thứ)
/// mang `vi_VN`; `main.dart` và `core/nen/chay_nen.dart` đã gọi `initializeDateFormatting('vi_VN')`.
class DateFormatter {
  DateFormatter._();

  static final _ngay = DateFormat('dd/MM/yyyy');
  static final _ngayThang = DateFormat('dd/MM');
  static final _ngayGio = DateFormat('dd/MM/yyyy HH:mm');
  static final _gioNgay = DateFormat('HH:mm dd/MM/yyyy');
  static final _thangNam = DateFormat('MM/yyyy');
  static final _thangNamNgan = DateFormat('MM/yy');
  static final _khoaNgay = DateFormat('yyyy-MM-dd');
  static final _thuNgay = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN');

  /// `03/08/2026`
  static String formatDate(DateTime d) => _ngay.format(d);

  /// `03/08`
  static String formatDayMonth(DateTime d) => _ngayThang.format(d);

  /// `03/08/2026 09:05` — ngày rồi giờ.
  static String formatDateTime(DateTime d) => _ngayGio.format(d);

  /// `09:05 03/08/2026` — giờ rồi ngày (thẻ đầu Chi tiết đơn Premium, theo màn Stitch).
  static String formatTimeDate(DateTime d) => _gioNgay.format(d);

  /// `08/2026`
  static String formatMonthYear(DateTime d) => _thangNam.format(d);

  /// `08/26` — nhãn trục biểu đồ khi khoảng dài.
  static String formatMonthYearShort(DateTime d) => _thangNamNgan.format(d);

  /// `2026-08-03` — KHOÁ nhóm theo ngày, không phải chữ hiển thị: so chuỗi ra đúng thứ tự thời gian, và
  /// `DateTime.parse` đọc ngược được.
  static String dayKey(DateTime d) => _khoaNgay.format(d);

  /// Tên thứ tiếng Việt + `, 03/08/2026` — tiêu đề nhóm ngày ở Sổ giao dịch. Cần dữ liệu locale `vi_VN`.
  static String formatWeekdayDate(DateTime d) => _thuNgay.format(d);
}
