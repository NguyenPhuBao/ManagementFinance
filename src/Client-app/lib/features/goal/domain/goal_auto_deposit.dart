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

/// Trần số vòng lặp khi dò từ mốc neo tới kỳ đầu tiên còn hiệu lực.
///
/// Mốc neo đi qua đường đồng bộ nên có thể mang giá trị rác từ Admin-web hoặc
/// một bản app khác. Bước từng ngày từ năm 1990 là hàng chục nghìn vòng lặp
/// **ngay trong vòng quét thông báo** — app treo. Vượt trần thì bỏ qua và im
/// lặng, cùng nguyên tắc với `isBehindSchedule`.
const int _tranDoMoc = 1000;

/// Những kỳ đã tới hạn cho tới [now], theo thứ tự thời gian.
///
/// ## Hai mốc, hai vai trò khác hẳn nhau
///
/// - [mocNeo] quyết định **nhịp**: "ngày 15 hàng tháng lúc 08:00". Đây là lựa
///   chọn của người dùng, lưu ở cột `timeCycleTakeMoney`. `null` thì nhịp rơi
///   vào chính [lanChayGanNhat] — hành vi của bản trước, giữ lại cho mục tiêu
///   bật trước khi có ô chọn này.
/// - [lanChayGanNhat] là **sàn**: đã trích tới đâu. `null` nghĩa là **chưa bật
///   trích tự động** — trả rỗng. Không lấy ngày tạo mục tiêu làm mốc thay thế:
///   bật công tắc hôm nay cho một mục tiêu tạo sáu tháng trước sẽ bị trích
///   ngược lại sáu kỳ cùng một lúc.
///
/// Cần **cả hai**. Chỉ có nhịp thì chọn "ngày 1" vào ngày 15 sẽ trích bù ngay
/// cho ngày 1 vừa trôi qua — quãng thời gian người dùng chưa hề đồng ý. Chỉ có
/// sàn thì lựa chọn của họ không có tác dụng nào, im lặng.
///
/// ⚠️ Nhịp bước **từng kỳ một** từ mốc neo, nên một mốc rơi vào ngày 31 sẽ bị
/// kẹp về 28/02 rồi bước tiếp **từ đó** — tức nhịp trôi dần chứ không quay lại
/// ngày 31. Đây là hệ quả có chủ ý của việc dùng chung `mocKeTiep` với phần dự
/// báo; ghi ra đây để không ai phát hiện nó bằng bất ngờ.
///
/// [toiDa] là **trần số kỳ mỗi lượt chạy**. Máy để lâu không mở với chu kỳ ngày
/// là hàng nghìn kỳ; trích hết trong một lượt sẽ rút cạn ví nguồn ngay khi
/// người dùng vừa mở app. Phần dư **không mất** — nó ở lại cho lượt sau, vì nơi
/// gọi chỉ đẩy mốc chạy tới kỳ cuối cùng thật sự xử lý được.
List<DateTime> cacKyDenHan({
  required DateTime? mocNeo,
  required DateTime? lanChayGanNhat,
  required String? chuKy,
  required DateTime now,
  int toiDa = 12,
}) {
  if (lanChayGanNhat == null) return const [];

  // Không có mốc neo thì nhịp bám vào chính mốc chạy, y như bản trước.
  var moc = mocNeo ?? mocKeTiep(lanChayGanNhat, chuKy);

  // Dò tới kỳ đầu tiên nằm SAU sàn. Mốc neo có thể ở trước sàn (chọn "ngày 1"
  // trong khi hôm nay là ngày 5) hoặc sau sàn (chọn "ngày 15") — cả hai đều
  // hợp lệ, vòng dò này xử lý chung.
  var soVong = 0;
  while (!moc.isAfter(lanChayGanNhat)) {
    if (++soVong > _tranDoMoc) return const [];
    moc = mocKeTiep(moc, chuKy);
  }

  final ra = <DateTime>[];
  // `isAfter` chứ không `!isBefore`: mốc rơi ĐÚNG hiện tại phải tính là đã tới
  // hạn, nếu không kỳ ấy trượt sang lượt chạy sau mà không có lý do nào giải
  // thích được.
  while (!moc.isAfter(now) && ra.length < toiDa) {
    ra.add(moc);
    moc = mocKeTiep(moc, chuKy);
  }

  return ra;
}

/// Dựng mốc neo từ những gì người dùng chọn trên màn hình.
///
/// [ngay] mang nghĩa khác nhau theo chu kỳ: 1–7 (thứ Hai → chủ nhật) với
/// `'Week'`, 1–31 với `'Month'`, và bị bỏ qua với `'Day'`.
///
/// Mốc dựng ra **được phép nằm ở quá khứ** — chọn "ngày 1" vào ngày 5 thì nó là
/// mùng 1 vừa qua. Đó không phải lỗi: mốc neo chỉ định *nhịp*, còn việc không
/// trích bù cho kỳ đã trôi qua trước lúc bật là do sàn `autoDepositLastRun` lo.
///
/// ⚠️ Ngày bị kẹp về ngày cuối tháng: `DateTime(2026, 9, 31)` tự thành 01/10
/// chứ không ném, nên chọn ngày 31 ở tháng 30 ngày sẽ lệch sang tháng sau ngay
/// từ lúc dựng, trước cả khi bước kỳ nào.
DateTime mocNeoTu({
  required String? chuKy,
  required int? ngay,
  required int gio,
  required int phut,
  required DateTime now,
}) {
  switch (chuKy) {
    case 'Day':
      return DateTime(now.year, now.month, now.day, gio, phut);
    case 'Week':
      final thu = (ngay == null || ngay < 1 || ngay > 7) ? now.weekday : ngay;
      final trongTuan = now.subtract(Duration(days: now.weekday - thu));
      return DateTime(
          trongTuan.year, trongTuan.month, trongTuan.day, gio, phut);
    default:
      final ngayCuoi = DateTime(now.year, now.month + 1, 0).day;
      final chon = ngay == null || ngay < 1 ? now.day : ngay;
      return DateTime(
          now.year, now.month, chon <= ngayCuoi ? chon : ngayCuoi, gio, phut);
  }
}

const List<String> _tenThu = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// Tên thứ trong tuần, 1 = thứ Hai. Dùng chung cho nhãn và cho bảng chọn.
String tenThuTrongTuan(int thu) =>
    _tenThu[thu.clamp(1, 7) - 1];

/// Câu chữ mô tả mốc neo, hiển thị trên biểu mẫu.
///
/// `null` trả về câu nói **đúng sự thật** rằng chưa chọn gì: mục tiêu bật trích
/// từ bản trước không có mốc neo và đang chạy theo lúc bật công tắc. Hiện một
/// ngày mặc định nào đó là nói dối về nhịp mà nó thật sự đang chạy.
String nhanMocNeo(String? chuKy, DateTime? moc) {
  if (moc == null) return 'Chưa chọn — trích theo lúc bật';

  final gio = '${moc.hour.toString().padLeft(2, '0')}:'
      '${moc.minute.toString().padLeft(2, '0')}';

  switch (chuKy) {
    case 'Day':
      return 'Mỗi ngày, $gio';
    case 'Week':
      return '${tenThuTrongTuan(moc.weekday)} hàng tuần, $gio';
    default:
      return 'Ngày ${moc.day} hàng tháng, $gio';
  }
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
/// Định danh **đúng cái mốc kỳ**, tới từng phút. Mốc ấy là giá trị *tính ra* từ
/// mốc neo chứ không phải "bây giờ", nên nó ổn định qua mọi lượt quét — chính
/// là thứ khiến khoá này khử trùng được. Đây là thứ đi thẳng vào `dedupeKey`
/// của bộ luật thông báo.
///
/// ⚠️ Bản đầu gộp tới mức **ngày**, và trên máy ảo nó đã làm một khoản trích
/// thật đi qua mà **không có thông báo nào**: mốc kỳ mới đụng khoá của một kỳ
/// khác cùng ngày, sinh ra trước đó khi mục tiêu còn dùng chu kỳ khác. Tiền rời
/// ví trong im lặng là kiểu hỏng tệ nhất ở vùng này.
String khoaKyTrich(String goalId, DateTime ky) =>
    '$goalId:${ky.year.toString().padLeft(4, '0')}-'
    '${ky.month.toString().padLeft(2, '0')}-'
    '${ky.day.toString().padLeft(2, '0')}'
    'T${ky.hour.toString().padLeft(2, '0')}'
    ':${ky.minute.toString().padLeft(2, '0')}';
