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
        DonViKy.quy => 'Quý $_quy ${from.year}',
        DonViKy.nam => '${from.year}',
        DonViKy.tuyChon => '${_dm(from)} – ${_dm(_ngayCuoi)}',
      };

  /// Nhãn trục biểu đồ — ngắn nhất có thể, vì trục chỉ đủ chỗ cho vài ký tự và
  /// nhãn chồng nhau là lỗi đã vấp thật (G39, bẫy 4.18 `ANALYTICS_FEATURE.md`).
  ///
  /// Tuần dùng **ngày thứ Hai** chứ không phải `T38`: `T` đang là tiền tố của
  /// tháng ở khắp app, và hai nghĩa cùng một chữ trên cùng một trục là lỗi đọc
  /// nhầm chứ không phải lỗi mã.
  String get nhanTruc => switch (donVi) {
        DonViKy.tuan => _dm(from),
        DonViKy.thang => 'T${from.month}',
        DonViKy.quy => 'Q$_quy',
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

/// Tiêu đề khối xu hướng, đổi theo đơn vị đang xem.
///
/// Đặt ở tầng domain để test được — tầng vẽ không test được (bẫy 4.9).
/// Kỳ tuỳ chọn rơi về "tháng" vì chuỗi của nó cũng lùi theo tháng: "6 khoảng 17
/// ngày" không phải thứ ai đọc được.
String tieuDeXuHuong(DonViKy donVi) => switch (donVi) {
      DonViKy.tuan => 'XU HƯỚNG $kSoKyXuHuong TUẦN',
      DonViKy.quy => 'XU HƯỚNG $kSoKyXuHuong QUÝ',
      DonViKy.nam => 'XU HƯỚNG $kSoKyXuHuong NĂM',
      DonViKy.thang || DonViKy.tuyChon => 'XU HƯỚNG $kSoKyXuHuong THÁNG',
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
