/// Lọc và tổng kết lịch sử tích luỹ của một mục tiêu.
///
/// Tách khỏi widget vì phần khó ở đây không phải phần vẽ mà là **biên của các
/// khoảng thời gian** — thứ kiểm được bằng dữ liệu và sai thì sai im lặng.
library;

/// Một khoản trong lịch sử, đã rút gọn khỏi hàng Drift.
///
/// Chỉ giữ ba thứ mà phép lọc và phép tổng cần. Nhận cả hàng giao dịch vào đây
/// thì tầng thuần này phải biết về Drift, và test phải dựng cả một CSDL.
class KhoanTichLuy {
  final DateTime ngay;
  final double soTien;

  /// Đọc từ **tiền tố ghi chú**, không từ vị trí ví — xem
  /// `goal_history_direction.dart` và bẫy 4.2. Nơi dựng danh sách phải gọi
  /// `laKhoanRutKhoiMucTieu` rồi truyền kết quả vào đây, chứ không tự suy lại.
  final bool laKhoanRut;

  /// Khoản này do **app tự chuyển tiền**, hay do người dùng tự bấm?
  ///
  /// Đọc từ **hậu tố ghi chú** qua `laKhoanTuDong` — cùng lối với [laKhoanRut]
  /// và cùng lý do: đó là thứ duy nhất nằm trong chính hàng dữ liệu, đi qua
  /// được đồng bộ, và không đổi khi cấu hình mục tiêu đổi.
  ///
  /// **Bắt buộc chứ không mặc định**, cùng kỷ luật với [laKhoanRut]: nơi dựng
  /// danh sách phải nói ra nó biết gì, thay vì lặng lẽ nhận `false`.
  final bool laTuDong;

  const KhoanTichLuy({
    required this.ngay,
    required this.soTien,
    required this.laKhoanRut,
    required this.laTuDong,
  });
}

/// Lọc theo chiều tiền.
enum LocChieu {
  tatCa('Tất cả'),
  daGui('Đã gửi'),
  daRut('Đã rút');

  const LocChieu(this.nhan);
  final String nhan;
}

/// Lọc theo khoảng thời gian.
enum LocKhoang {
  tatCa('Mọi lúc'),
  ngay30('30 ngày'),
  thang3('3 tháng'),
  namNay('Năm nay');

  const LocKhoang(this.nhan);
  final String nhan;
}

/// Lọc theo nguồn của khoản: app tự trích hay người dùng tự bấm.
///
/// Là tầng nghĩa KHÁC với [LocChieu], nên là một enum riêng chứ không phải chip
/// thứ tư của dải chiều tiền: "tự động" là tập con của "đã gửi", nhét chung một
/// dải là trộn hai tầng. Khoản **rút** luôn thuộc [tay] — không có đường nào
/// trong app tự rút tiền khỏi mục tiêu.
enum LocNguon {
  tatCa('Tất cả'),
  tay('Tay'),
  tuDong('Tự động');

  const LocNguon(this.nhan);
  final String nhan;
}

DateTime _ngayGon(DateTime d) => DateTime(d.year, d.month, d.day);

/// Mốc sớm nhất còn được giữ lại, hoặc `null` khi không cắt gì.
///
/// ## Vì sao "Năm nay" cắt theo năm dương lịch, không phải 365 ngày
///
/// Ngày 08/09/2026 thì 365 ngày trước là 08/09/2025 — tức nhãn "Năm nay" sẽ
/// gồm cả bốn tháng cuối năm ngoái. Đó là một câu nói dối nhỏ mà người dùng
/// phát hiện ngay khi họ cộng lại để đối chiếu với sổ sách.
DateTime? _mocSomNhat(LocKhoang khoang, DateTime now) => switch (khoang) {
      LocKhoang.tatCa => null,
      LocKhoang.ngay30 => _ngayGon(now).subtract(const Duration(days: 30)),
      LocKhoang.thang3 => DateTime(now.year, now.month - 3, now.day),
      LocKhoang.namNay => DateTime(now.year, 1, 1),
    };

/// Lọc danh sách theo cả hai bộ lọc — **giao nhau**, không phải hợp nhau.
///
/// **Không sắp xếp lại.** Thứ tự do truy vấn quyết định (`date desc`); sắp lại
/// ở đây là tạo bản sao thứ hai của một quyết định đã nằm ở tầng dữ liệu.
///
/// Biên thời gian so theo **ngày**, không theo giờ: trừ `DateTime` thô thì
/// cùng một khoản lọt hay không lọt tuỳ giờ người dùng mở app.
List<KhoanTichLuy> locKhoan(
  List<KhoanTichLuy> tatCa, {
  LocChieu chieu = LocChieu.tatCa,
  LocKhoang khoang = LocKhoang.tatCa,
  LocNguon nguon = LocNguon.tatCa,
  required DateTime now,
}) {
  final moc = _mocSomNhat(khoang, now);

  return tatCa.where((k) {
    if (chieu == LocChieu.daGui && k.laKhoanRut) return false;
    if (chieu == LocChieu.daRut && !k.laKhoanRut) return false;
    // Khoản rút có `laTuDong = false` nên tự nhiên rơi vào "Tay" — đúng ý:
    // không có đường nào trong app tự rút tiền khỏi mục tiêu.
    if (nguon == LocNguon.tuDong && !k.laTuDong) return false;
    if (nguon == LocNguon.tay && k.laTuDong) return false;
    if (moc != null && _ngayGon(k.ngay).isBefore(_ngayGon(moc))) return false;
    return true;
  }).toList();
}

/// Ba con số của dòng tổng.
class TongKetLichSu {
  final int soKhoan;
  final double daGui;
  final double daRut;

  const TongKetLichSu({
    required this.soKhoan,
    required this.daGui,
    required this.daRut,
  });
}

/// Đếm và cộng riêng hai chiều.
///
/// ⚠️ Gọi nó trên danh sách **ĐÃ LỌC**, không phải danh sách gốc. Dòng tổng
/// nằm ngay trên dải chip nên nó phải nói về đúng thứ đang hiện; tổng của cả
/// danh sách trong khi màn hình chỉ còn ba dòng là hai con số cãi nhau trên
/// cùng một màn hình.
TongKetLichSu tongKet(List<KhoanTichLuy> ds) {
  var gui = 0.0;
  var rut = 0.0;
  for (final k in ds) {
    if (k.laKhoanRut) {
      rut += k.soTien;
    } else {
      gui += k.soTien;
    }
  }
  return TongKetLichSu(soKhoan: ds.length, daGui: gui, daRut: rut);
}
