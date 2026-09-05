/// Phần **quyết định** của việc tự động trích tiền định kỳ vào mục tiêu.
///
/// Toàn bộ tệp này là hàm thuần: không Drift, không Flutter, không đồng hồ hệ
/// thống. Việc *ghi* nằm ở `GoalAutoDepositRunner`, việc *báo* nằm ở
/// `notification_rules.dart`. Tách ra vì đây là chỗ duy nhất trong app **tự ý
/// chuyển tiền của người dùng khi họ không có mặt** — mọi luật ở đây phải test
/// được mà không cần dựng CSDL.
library;

/// Bước từ một mốc sang mốc kế tiếp của chu kỳ.
///
/// ## Cái bẫy của phép cộng tháng
///
/// `DateTime(2026, 2, 31)` **không ném lỗi** — Dart tự chuẩn hoá nó thành
/// 03/03. Nên cộng tháng kiểu thô cho một mục tiêu đặt vào ngày 31 sẽ đẩy mốc
/// trôi dần sang tháng sau, mỗi kỳ một ít, và không có gì báo. Ở đây ngày bị
/// **kẹp về ngày cuối tháng đích**, và số ngày ấy tính từ lịch thật nên năm
/// nhuận ra 29/02 chứ không phải 28.
///
/// Giờ và phút được giữ nguyên: mốc trích là một *thời điểm*, không phải một
/// ngày. Cắt giờ đi làm kỳ đầu tiên đến sớm hơn dự tính tới gần một ngày.
DateTime mocKeTiep(DateTime moc, String? chuKy) {
  switch (chuKy) {
    case 'Day':
      return moc.add(const Duration(days: 1));
    case 'Week':
      return moc.add(const Duration(days: 7));
    case 'Quarter':
      return _congThang(moc, 3);
    case 'Year':
      return _congThang(moc, 12);
    case 'Month':
    default:
      // Chu kỳ trống hoặc lạ (giá trị từ Admin-web, bản app cũ) quy về hàng
      // tháng — cùng lựa chọn với nhãn hiển thị ở trang chi tiết, để hai nơi
      // không nói hai điều khác nhau về cùng một mục tiêu.
      return _congThang(moc, 1);
  }
}

DateTime _congThang(DateTime moc, int soThang) {
  final tongThang = moc.month - 1 + soThang;
  final nam = moc.year + tongThang ~/ 12;
  final thang = tongThang % 12 + 1;

  // Ngày 0 của tháng kế tiếp = ngày cuối của tháng này. Lịch thật, nên tháng 2
  // năm nhuận ra 29.
  final ngayCuoiThangDich = DateTime(nam, thang + 1, 0).day;
  final ngay = moc.day <= ngayCuoiThangDich ? moc.day : ngayCuoiThangDich;

  return DateTime(nam, thang, ngay, moc.hour, moc.minute, moc.second);
}

/// Những kỳ đã tới hạn kể từ [lanChayGanNhat] cho tới [now], theo thứ tự thời
/// gian.
///
/// [lanChayGanNhat] `null` nghĩa là **chưa bật trích tự động** — trả rỗng.
/// Không lấy ngày tạo mục tiêu làm mốc thay thế: bật công tắc hôm nay cho một
/// mục tiêu tạo sáu tháng trước sẽ bị trích ngược lại sáu kỳ cùng một lúc.
///
/// [toiDa] là **trần số kỳ mỗi lượt chạy**. Máy để lâu không mở với chu kỳ ngày
/// là hàng nghìn kỳ; trích hết trong một lượt sẽ rút cạn ví nguồn ngay khi
/// người dùng vừa mở app. Phần dư **không mất** — nó ở lại cho lượt sau, vì nơi
/// gọi chỉ đẩy mốc chạy tới kỳ cuối cùng thật sự xử lý được.
List<DateTime> cacKyDenHan({
  required DateTime? lanChayGanNhat,
  required String? chuKy,
  required DateTime now,
  int toiDa = 12,
}) {
  if (lanChayGanNhat == null) return const [];

  final ra = <DateTime>[];
  var moc = mocKeTiep(lanChayGanNhat, chuKy);

  // `isAfter` chứ không `!isBefore`: mốc rơi ĐÚNG hiện tại phải tính là đã tới
  // hạn, nếu không kỳ ấy trượt sang lượt chạy sau mà không có lý do nào giải
  // thích được.
  while (!moc.isAfter(now) && ra.length < toiDa) {
    ra.add(moc);
    moc = mocKeTiep(moc, chuKy);
  }

  return ra;
}

/// Chuyện gì xảy ra với một kỳ trích.
enum LoaiTrich {
  /// Trích đủ số đã cài.
  trichDu,

  /// Chỉ trích phần còn thiếu, vì nó nhỏ hơn số đã cài.
  trichPhanConLai,

  /// Ví nguồn không đủ tiền. **Không** trích gì cả.
  viKhongDu,

  /// Không còn gì để trích: mục tiêu đã đủ, hoặc cấu hình không hợp lệ.
  mucTieuDaXong,

  /// Không chạy được vì cấu hình hỏng — ví nguồn đã bị xoá, hoặc nó trùng ví
  /// tích luỹ.
  ///
  /// **Chỉ `GoalAutoDepositRunner` sinh ra nhánh này**, không phải
  /// [quyetDinhTrich]: nó là kết luận về thế giới bên ngoài (ví còn tồn tại
  /// không), chứ không phải về những con số truyền vào.
  khongChayDuoc,
}

class QuyetDinhTrich {
  const QuyetDinhTrich(this.loai, this.soTien);

  final LoaiTrich loai;

  /// Số tiền thật sự chuyển. Bằng 0 với mọi nhánh không trích.
  final double soTien;
}

/// Trích bao nhiêu cho **một** kỳ.
///
/// ## Vì sao kẹp ở phần còn thiếu
///
/// Nạp vượt bằng tay thì app chỉ **cảnh báo** rồi cho qua (mục 3.8
/// `GOAL_FEATURE.md`) — người dùng đang nhìn màn hình và tự chịu trách nhiệm.
/// Trích tự động thì họ vắng mặt, nên không ai duyệt phần vượt. Kẹp lại là lựa
/// chọn chặt hơn, và chặt hơn mới đúng ở chỗ này.
///
/// ## Vì sao ví thiếu tiền thì bỏ hẳn kỳ, không trích một phần
///
/// Trích một phần làm một kỳ ra hai con số khác nhau trong sổ sách, mà vẫn
/// không giải quyết được việc thiếu tiền. Bỏ kỳ đó và **báo** cho người dùng;
/// nơi gọi giữ nguyên mốc chạy nên kỳ ấy tự thử lại khi ví có tiền.
QuyetDinhTrich quyetDinhTrich({
  required double soTienCai,
  required double conThieu,
  required double soDuViNguon,
}) {
  if (soTienCai <= 0 || conThieu <= 0) {
    return const QuyetDinhTrich(LoaiTrich.mucTieuDaXong, 0);
  }

  final soTien = soTienCai <= conThieu ? soTienCai : conThieu;

  // Số dư 0 sau khi trích là hợp lệ; chỉ số dư ÂM mới sai.
  if (soDuViNguon < soTien) {
    return const QuyetDinhTrich(LoaiTrich.viKhongDu, 0);
  }

  return QuyetDinhTrich(
    soTien < soTienCai ? LoaiTrich.trichPhanConLai : LoaiTrich.trichDu,
    soTien,
  );
}

/// Khoá định danh một kỳ trích của một mục tiêu.
///
/// Gộp theo **ngày**: hai lượt chạy trong cùng một ngày cho cùng một kỳ phải ra
/// cùng một khoá, nếu không mỗi lần mở app lại đẻ thêm một thông báo cho việc
/// đã làm rồi. Cùng nguyên tắc với `dedupeKey` của bộ luật thông báo, và đây
/// chính là thứ đi vào `dedupeKey` ấy.
String khoaKyTrich(String goalId, DateTime ky) =>
    '$goalId:${ky.year.toString().padLeft(4, '0')}-'
    '${ky.month.toString().padLeft(2, '0')}-'
    '${ky.day.toString().padLeft(2, '0')}';
