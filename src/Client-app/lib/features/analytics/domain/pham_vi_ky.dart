/// Phạm vi thời gian của trang Phân tích — **định nghĩa duy nhất** của khái
/// niệm "kỳ" trong app (2026-09-15).
///
/// Trước tệp này, trang Phân tích khoá cứng theo cặp `(nam, thang)` ở cả năm
/// tầng. Mọi phép đếm tiền vốn đã nhận khoảng bất kỳ (`tongThuChi(from:, to:)`),
/// nên thứ còn thiếu chỉ là một cách **gọi tên** một khoảng cho giao diện.
///
/// Biên luôn `[from, to)` — `to` **MỞ**, cùng quy ước với `tongThuChi`,
/// `getExpenses`, `tuanTruoc`. Lấy biên đóng là đếm khoản 00:00 ngày đầu kỳ sau
/// vào kỳ này, và lệch ấy **im lặng**: không exception, chỉ là một con số lớn
/// hơn thực tế.
library;

import '../../../core/notification/tuan_iso.dart';

enum DonViKy { tuan, thang, quy, nam, tuyChon }

/// Số kỳ bộ chọn liệt kê cho mỗi đơn vị — **một chỗ định nghĩa**. Đừng rải
/// những con số này vào widget; chúng là luật của tính năng, không phải tham số
/// trình bày.
int soKyTrongBoChon(DonViKy donVi) => switch (donVi) {
      DonViKy.tuan => 12,
      DonViKy.thang => 12,
      DonViKy.quy => 8,
      DonViKy.nam => 5,
      // Khoảng tuỳ ý do người dùng nhập, không liệt kê trước được.
      DonViKy.tuyChon => 0,
    };

/// Số kỳ trên biểu đồ xu hướng — **cùng một con số cho mọi đơn vị**, để không
/// đẻ thêm một bảng hằng số phải nhớ.
const int kSoKyXuHuong = 6;

/// Một kỳ: đơn vị, và biên `[from, to)` của nó.
class Ky {
  final DonViKy donVi;

  final DateTime from;

  /// Biên **MỞ** — ngày cuối cùng nằm TRONG kỳ là `to - 1 ngày`.
  final DateTime to;

  const Ky._(this.donVi, this.from, this.to);

  /// Tuần **chứa** [ngayTrongTuan], bắt đầu thứ Hai theo ISO.
  ///
  /// Mượn nguyên `bienTuan` của `tuan_iso.dart` — cùng phép mà thông báo Tổng
  /// kết tuần dùng, nên hai nơi không thể lệch nhau một ngày.
  factory Ky.tuan(DateTime ngayTrongTuan) {
    final b = bienTuan(ngayTrongTuan);
    return Ky._(DonViKy.tuan, b.from, b.to);
  }

  /// [thang] ngoài `[1, 12]` tự cuộn năm nhờ `DateTime`: tháng 0 là tháng 12 năm
  /// trước, tháng 13 là tháng 1 năm sau. Tự trừ rồi cộng 12 là chỗ đã sinh lỗi ở
  /// nhiều app khác.
  factory Ky.thang(int nam, int thang) =>
      Ky._(DonViKy.thang, DateTime(nam, thang, 1), DateTime(nam, thang + 1, 1));

  /// [quy] trong `[1, 4]`.
  factory Ky.quy(int nam, int quy) => Ky._(
        DonViKy.quy,
        DateTime(nam, (quy - 1) * 3 + 1, 1),
        DateTime(nam, (quy - 1) * 3 + 4, 1),
      );

  factory Ky.nam(int nam) =>
      Ky._(DonViKy.nam, DateTime(nam, 1, 1), DateTime(nam + 1, 1, 1));

  /// Khoảng người dùng tự chọn. Người gọi chịu trách nhiệm cộng một ngày vào
  /// [to] để ngày cuối họ chọn nằm TRONG kỳ — cùng luật với `khoangCuaPhamVi`
  /// của trang Xuất báo cáo.
  factory Ky.tuyChon({required DateTime from, required DateTime to}) =>
      Ky._(DonViKy.tuyChon, from, to);

  bool chua(DateTime d) => !d.isBefore(from) && d.isBefore(to);

  int get _quy => (from.month - 1) ~/ 3 + 1;

  /// Ngày cuối cùng nằm TRONG kỳ.
  DateTime get _ngayCuoi => to.subtract(const Duration(days: 1));

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Nhãn đầy đủ — dùng cho danh sách trong bộ chọn, nơi có chỗ.
  String get nhan => switch (donVi) {
        DonViKy.tuan => '$nhanNgan (${_dm(from)} – ${_dm(_ngayCuoi)})',
        DonViKy.tuyChon => '${_dm(from)} – ${_dm(_ngayCuoi)}',
        _ => nhanNgan,
      };

  /// Nhãn ngắn — dùng ở ô trên header, nơi rất chật: ở 411dp thật, hàng ấy từng
  /// tràn 53px và phải chỉnh tỉ lệ flex mới vừa.
  String get nhanNgan => switch (donVi) {
        // Số tuần lấy từ `tuanISO`, nên nhãn tự đúng ở ca tuần vắt qua giao
        // thừa: 31/12/2025 thuộc 2026-W01. Phép chia ngây thơ cho ra tuần 53.
        DonViKy.tuan => 'Tuần ${tuanISO(from).tuan}',
        DonViKy.thang => 'T${from.month} ${from.year}',
        // ⚠️ `Q3` chứ không `Quý 3`: dạng đầy đủ làm nhãn ô header dài hơn
        // "Tháng này (T9 2026)" đúng MỘT ký tự, và máy ảo cắt nó thành
        // "Quý này (Quý 3 20…" — mất cả con số năm. Nhãn tháng là mốc đã được
        // máy thật chứng minh là vừa, nên không nhãn nào được dài hơn nó; có
        // ca test canh đúng bất đẳng thức ấy. `Q3` cũng là cách viết mà trục
        // biểu đồ đã dùng (`Q3/26`), nên đây không phải quy ước thứ hai.
        DonViKy.quy => 'Q$_quy ${from.year}',
        DonViKy.nam => '${from.year}',
        DonViKy.tuyChon => '${_dm(from)} – ${_dm(_ngayCuoi)}',
      };

  /// Nhãn trục biểu đồ — ngắn nhất có thể, vì trục chỉ đủ chỗ cho vài ký tự và
  /// nhãn chồng nhau là lỗi đã vấp thật (G39, bẫy 4.18 `ANALYTICS_FEATURE.md`).
  ///
  /// Tuần dùng **ngày thứ Hai** chứ không phải `T38`: `T` đang là tiền tố của
  /// tháng ở khắp app, và hai nghĩa cùng một chữ trên cùng một trục là lỗi đọc
  /// nhầm chứ không phải lỗi mã.
  ///
  /// ⚠️ Quý **phải mang năm** (`Q3/26`): sáu quý trải qua một năm rưỡi, nên
  /// `Q3` một mình xuất hiện **hai lần** trên cùng một trục và hai cột khác
  /// nhau mang đúng một nhãn. Sáu tháng, sáu tuần hay sáu năm thì không lặp.
  /// Widget test bắt được ca này — cùng họ với G39.
  String get nhanTruc => switch (donVi) {
        DonViKy.tuan => _dm(from),
        DonViKy.thang => 'T${from.month}',
        DonViKy.quy => 'Q$_quy/${(from.year % 100).toString().padLeft(2, '0')}',
        DonViKy.nam => '${from.year}',
        DonViKy.tuyChon => _dm(from),
      };

  /// "Tuần này" / "Tháng này" / … cho ô header khi kỳ chứa hôm nay.
  ///
  /// `null` cho kỳ tuỳ chọn: một khoảng tuỳ ý không phải "kỳ này" của đơn vị
  /// nào, và gọi nó là "kỳ này" thì người đọc sẽ tưởng app tự chọn giúp.
  String? get tenKyNay => switch (donVi) {
        DonViKy.tuan => 'Tuần này',
        DonViKy.thang => 'Tháng này',
        DonViKy.quy => 'Quý này',
        DonViKy.nam => 'Năm nay',
        DonViKy.tuyChon => null,
      };

  @override
  bool operator ==(Object other) =>
      other is Ky && other.donVi == donVi && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(donVi, from, to);

  @override
  String toString() => 'Ky(${donVi.name}, $from → $to)';
}

/// Các kỳ bộ chọn cho phép với [donVi], **mới nhất trước**; phần tử đầu là kỳ
/// chứa [now]. Rỗng với [DonViKy.tuyChon].
List<Ky> cacKyGanNhat(DateTime now, DonViKy donVi) {
  final dau = switch (donVi) {
    DonViKy.tuan => Ky.tuan(now),
    DonViKy.thang => Ky.thang(now.year, now.month),
    DonViKy.quy => Ky.quy(now.year, (now.month - 1) ~/ 3 + 1),
    DonViKy.nam => Ky.nam(now.year),
    DonViKy.tuyChon => null,
  };
  if (dau == null) return const [];
  return [for (var i = 0; i < soKyTrongBoChon(donVi); i++) lui(dau, i)];
}

/// [ky] lùi [soKy] kỳ, giữ nguyên đơn vị.
///
/// Lùi theo **đơn vị lịch** chứ không trừ số ngày: tháng 3 lùi một tháng phải ra
/// tháng 2, không phải "31 ngày trước". Tự trừ ngày sai **im lặng** — nó chỉ
/// lệch ở những tháng có độ dài khác nhau, tức là hầu hết các tháng.
Ky lui(Ky ky, int soKy) => switch (ky.donVi) {
      DonViKy.tuan => Ky.tuan(ky.from.subtract(Duration(days: 7 * soKy))),
      DonViKy.thang => Ky.thang(ky.from.year, ky.from.month - soKy),
      // Lùi bằng THÁNG rồi quy về quý, để quý 1 lùi một quý ra quý 4 năm trước
      // mà không phải tự xử lý mốc năm.
      DonViKy.quy => () {
          final d = DateTime(ky.from.year, ky.from.month - 3 * soKy, 1);
          return Ky.quy(d.year, (d.month - 1) ~/ 3 + 1);
        }(),
      DonViKy.nam => Ky.nam(ky.from.year - soKy),
      DonViKy.tuyChon => () {
          final dai = ky.to.difference(ky.from);
          return Ky.tuyChon(
            from: ky.from.subtract(dai * soKy),
            to: ky.to.subtract(dai * soKy),
          );
        }(),
    };

/// Nhãn của ô chọn kỳ trên header: `"Tháng này (T9 2026)"` khi kỳ chứa [moc],
/// `"T8 2026"` khi không.
///
/// Giữ "Tháng này" cho một tháng đã qua là **nói dối về thứ đang hiện**; đó là
/// lý do phép kiểm phải là `ky.chua(moc)` chứ không phải "kỳ đầu danh sách".
/// Kỳ tuỳ chọn không bao giờ mang dạng "… này" — [Ky.tenKyNay] trả `null`.
String nhanOChon(Ky ky, DateTime moc) {
  final ten = ky.tenKyNay;
  if (ten == null || !ky.chua(moc)) return ky.nhanNgan;
  return '$ten (${ky.nhanNgan})';
}

/// Tên **kỳ liền trước** của [ky], cho câu "so với …" ở ba thẻ tổng.
///
/// Bỏ năm khi kỳ trước cùng năm với kỳ đang xem: thẻ tổng rất hẹp ở 411dp, và
/// "so với T8 2026" khi đang xem T9 2026 thì chữ "2026" chỉ là nhiễu. Nhưng khi
/// kỳ trước rơi sang năm khác thì **giữ năm** — đang xem T1 2026 mà đọc "so với
/// T12" thì người dùng không biết T12 nào, và bản cũ của trang đúng là nói thế.
///
/// Kỳ năm luôn giữ số năm, vì bỏ đi thì chẳng còn gì.
String nhanKyTruoc(Ky ky) {
  final t = lui(ky, 1);
  if (t.from.year == ky.from.year) {
    switch (t.donVi) {
      case DonViKy.thang:
        return 'T${t.from.month}';
      case DonViKy.quy:
        return 'Quý ${t._quy}';
      default:
        break;
    }
  }
  return t.nhanNgan;
}

/// Tiêu đề khối xu hướng, đổi theo đơn vị đang xem.
///
/// Đặt ở tầng domain để test được — tầng vẽ không test được (bẫy 4.9).
/// Kỳ tuỳ chọn rơi về "tháng" vì chuỗi của nó cũng lùi theo tháng: "6 khoảng 17
/// ngày" không phải thứ ai đọc được.
String tieuDeXuHuong(DonViKy donVi) => switch (donVi) {
      DonViKy.tuan => 'Xu hướng $kSoKyXuHuong tuần',
      DonViKy.quy => 'Xu hướng $kSoKyXuHuong quý',
      DonViKy.nam => 'Xu hướng $kSoKyXuHuong năm',
      DonViKy.thang || DonViKy.tuyChon => 'Xu hướng $kSoKyXuHuong tháng',
    };

/// Kỳ liền trước của `[from, to)`, để so sánh "so với kỳ trước".
///
/// **Chuyển từ `bao_cao_xuat.dart` sang đây ngày 2026-09-15** để trang Phân tích
/// và trang Xuất báo cáo dùng chung một định nghĩa; tệp cũ export lại nó nên mọi
/// chỗ gọi và test của nó không phải đổi.
///
/// Khoảng trùng khít một số **tháng dương lịch** thì lùi theo tháng, không phải
/// trừ số ngày: tháng 9 dài 30 ngày, trừ 30 ngày ra `02/08–01/09` — lệch một
/// ngày, và con số phần trăm sai mà không ai thấy. Khoảng khác thì lùi đúng bằng
/// độ dài của nó, kết thúc ngay lúc kỳ này bắt đầu.
({DateTime from, DateTime to}) khoangKyTruoc({
  required DateTime from,
  required DateTime to,
}) {
  final tronThang = from.day == 1 &&
      to.day == 1 &&
      from.hour == 0 &&
      to.hour == 0 &&
      from.minute == 0 &&
      to.minute == 0;
  if (tronThang) {
    final soThang = (to.year * 12 + to.month) - (from.year * 12 + from.month);
    if (soThang > 0) {
      // `month - soThang` bằng 0 hay âm tự cuộn về năm trước nhờ `DateTime`.
      return (from: DateTime(from.year, from.month - soThang, 1), to: from);
    }
  }
  return (from: from.subtract(to.difference(from)), to: from);
}

/// **Cùng kỳ năm trước** của [ky] — mốc so sánh thứ hai của trang Phân tích
/// (#2 khảo sát lần hai, 2026-09-16).
///
/// Lùi đúng **một năm**, giữ nguyên đơn vị. Khác [lui] ở chỗ nó không đếm số kỳ
/// người dùng đã xem: "cùng kỳ năm trước" là một khái niệm của **lịch**.
///
/// Ba chỗ dễ vấp, cả ba hỏng **im lặng**:
///
///  1. **Tuần lùi 52 kỳ, KHÔNG neo vào ngày dương lịch.** Đây là chỗ phản trực
///     giác nhất, và bản đầu của hàm này đã làm sai. 52 tuần là 364 ngày nên nó
///     *có* trôi một ngày mỗi năm — nhưng chính nhờ thế nó luôn rơi vào tuần
///     phủ gần trọn 7 ngày cùng lịch năm trước. Neo vào ngày dương lịch của
///     `from` (thứ Hai) thì thứ Hai ấy năm ngoái thường là Chủ nhật, tức thuộc
///     tuần **trước đó**, và kỳ so sánh chỉ còn chồng lấp đúng một ngày.
///     Đo bằng máy 2026-09-16 trên 3131 tuần của 60 năm (2000–2060): lùi 52 kỳ
///     cho số ngày chồng lấp ít nhất là **5**, neo thứ Hai chỉ **1**; và lùi 52
///     kỳ trùng khít với lối neo vào **thứ Năm** — ngày định danh tuần ISO — ở
///     cả 3131 tuần.
///     ⚠️ Cũng **không** dùng "cùng số tuần ISO": tuần 53 chỉ tồn tại ở một số
///     năm, nên lối ấy có lúc trỏ vào một kỳ không có thật.
///  2. **Khoảng tuỳ chọn giữ nguyên độ dài.** Dời riêng từng mốc thì kỳ bắt đầu
///     29/2 (Dart chuẩn hoá thành 1/3) hoá ra dài hơn hoặc ngắn hơn một ngày, và
///     phần trăm so hai kỳ lệch độ dài trông vẫn rất hợp lý.
///  3. **Tháng/quý/năm thì độ dài ĐƯỢC PHÉP khác nhau** — tháng 2/2028 có 29
///     ngày còn 2/2027 có 28. Một tháng là một tháng; ép chúng bằng nhau số
///     ngày là so sai đơn vị.
Ky cungKyNamTruoc(Ky ky) => switch (ky.donVi) {
      // Bốn đơn vị đầu đếm được "một năm" bằng số kỳ, nên mượn lại `lui` để
      // không đẻ phép lùi lịch thứ hai.
      DonViKy.tuan => lui(ky, 52),
      DonViKy.thang => lui(ky, 12),
      DonViKy.quy => lui(ky, 4),
      DonViKy.nam => lui(ky, 1),
      DonViKy.tuyChon => () {
          final dau = DateTime(ky.from.year - 1, ky.from.month, ky.from.day);
          return Ky.tuyChon(from: dau, to: dau.add(ky.to.difference(ky.from)));
        }(),
    };

/// Tên **cùng kỳ năm trước** cho câu "so với …" ở hai thẻ tổng.
///
/// Khác [nhanKyTruoc], nhãn này **luôn mang số năm**: cả câu nói về năm ngoái,
/// nên bỏ năm đi là bỏ mất chính thông tin người đọc cần.
///
/// ⚠️ Tuần lấy **năm ISO** chứ không lấy `from.year`. Tuần bắt đầu 30/12/2024 là
/// tuần **1 của 2025**; in "Tuần 1 2024" thì sai hẳn một năm và không lỗi nào
/// báo — ca ấy xảy ra thật với tuần cuối tháng 12.
String nhanCungKyNamTruoc(Ky ky) {
  final t = cungKyNamTruoc(ky);
  return switch (t.donVi) {
    // `nhanNgan` của ba đơn vị này đã có sẵn năm.
    DonViKy.thang || DonViKy.quy || DonViKy.nam => t.nhanNgan,
    DonViKy.tuan => '${t.nhanNgan} ${tuanISO(t.from).nam}',
    DonViKy.tuyChon => '${t.nhanNgan} ${t.from.year}',
  };
}

/// Khoảng khởi tạo **hợp lệ** cho `showDateRangePicker` khi đang xem [ky]
/// (G43, 2026-09-16).
///
/// Trả biên **ĐÓNG** (`den` là ngày cuối cùng nằm trong kỳ) vì bộ chọn ngày
/// nhận biên đóng, còn [Ky] giữ biên mở — lệch đúng một ngày.
///
/// ⚠️ **Vì sao phải có hàm này:** `showDateRangePicker` **ném assertion** khi
/// `initialDateRange` thò ra ngoài `[firstDate, lastDate]`, và ở đây nó là một
/// exception bất đồng bộ **không ai bắt** — nút không làm gì, không toast,
/// không màn đỏ, chỉ một dòng trong logcat. Ca vấp thật là trạng thái **mặc
/// định** của trang: "Tháng này" kết thúc ngày cuối tháng, tức **sau hôm nay**,
/// trong khi `lastDate` là hôm nay.
///
/// `null` khi kỳ **không giao** với dải cho phép — chỗ gọi mở bộ chọn mà không
/// đặt khoảng sẵn. Trả một khoảng đảo đầu-cuối chỉ là đổi sang một assertion
/// khác.
({DateTime from, DateTime den})? khoangKhoiTaoBoChonNgay({
  required Ky ky,
  required DateTime somNhat,
  required DateTime muonNhat,
}) {
  final dau = ky.from.isBefore(somNhat) ? somNhat : ky.from;
  final cuoi = ky.to.subtract(const Duration(days: 1));
  final den = cuoi.isAfter(muonNhat) ? muonNhat : cuoi;
  if (den.isBefore(dau)) return null;
  return (from: dau, den: den);
}
