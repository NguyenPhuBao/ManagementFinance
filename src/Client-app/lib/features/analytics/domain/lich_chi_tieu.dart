/// Lịch chi tiêu — heatmap theo ngày của trang Phân tích (#6 khảo sát lần hai,
/// 2026-09-16).
///
/// PocketSmith và Money Lover đều vẽ thứ này dưới dạng **lịch tháng**, không
/// phải dải kiểu GitHub — nên khối chỉ hiện khi đơn vị đang xem là **Tháng**,
/// cùng lối với thanh ngân sách (bẫy #1 mục 3.20).
///
/// Cả bốn hàm ở đây đều thuần, vì tầng vẽ không test tự động được (bẫy 4.9).
library;

import 'bao_cao_xuat.dart';
import 'pham_vi_ky.dart';

/// Một ngày trên lịch: tổng chi, số khoản, và khoản lớn nhất của **chính ngày
/// ấy** (thẻ tóm tắt nói "Lớn nhất: …").
class NgayChiTieu {
  final double tongChi;
  final int soKhoan;

  /// `null` chỉ xảy ra khi [soKhoan] bằng 0 — mà khi ấy ngày không có khoá
  /// trong map, nên trên thực tế nó luôn khác `null`.
  final DongGiaoDich? lonNhat;

  const NgayChiTieu({
    required this.tongChi,
    required this.soKhoan,
    required this.lonNhat,
  });
}

/// Gom [trongKy] theo **ngày** (đã cắt giờ). Chỉ khoản `'chi'`.
///
/// ⚠️ Bỏ `'thu'` và `'transfer'` là bắt buộc: đếm cả chúng thì một ngày **chuyển
/// ví** làm ô đậm lên như một ngày tiêu nhiều.
///
/// Ngày không có khoản chi nào **không có khoá** — ô trống và ô "0 đồng" là hai
/// thứ khác nhau ở tầng dưới cùng, và [bacNhiet] phân biệt chúng.
///
/// Đây cũng là **định nghĩa duy nhất** của phép gom theo ngày: `soLieuNhanhCua`
/// gọi lại nó thay vì giữ một vòng lặp thứ hai, để "ngày chi nhiều nhất" của
/// khối Số liệu nhanh và ô đậm nhất của lịch không thể nói hai ngày khác nhau.
Map<DateTime, NgayChiTieu> lichChiTieuCua(List<DongGiaoDich> trongKy) {
  final tong = <DateTime, double>{};
  final dem = <DateTime, int>{};
  final lon = <DateTime, DongGiaoDich>{};
  for (final d in trongKy) {
    if (d.loai != 'chi') continue;
    final ngay = DateTime(d.ngay.year, d.ngay.month, d.ngay.day);
    tong[ngay] = (tong[ngay] ?? 0) + d.soTien;
    dem[ngay] = (dem[ngay] ?? 0) + 1;
    final cu = lon[ngay];
    if (cu == null || d.soTien > cu.soTien) lon[ngay] = d;
  }
  return {
    for (final e in tong.entries)
      e.key: NgayChiTieu(
        tongChi: e.value,
        soKhoan: dem[e.key] ?? 0,
        lonNhat: lon[e.key],
      ),
  };
}

/// Bậc đậm nhạt `0…4` của một ngày, **neo vào [trungBinh]** — mức chi trung
/// bình mỗi ngày của kỳ (`SoLieuNhanh.chiMoiNgay`).
///
/// ⚠️ **Đừng neo vào ngày chi nhiều nhất.** Một ngày mua sắm lớn sẽ làm phẳng cả
/// tháng: 29 ngày còn lại rơi hết về bậc nhạt nhất và lưới trông như tháng
/// không tiêu gì. Trung bình thì chịu được một điểm ngoại lai — có ca test dựng
/// đúng hình ấy.
///
/// **Bậc 0 dành riêng cho ngày KHÔNG chi.** Một đồng vẫn là có tiêu; gộp nó vào
/// bậc 0 là để "tháng không tiêu gì" trông y hệt "tháng tiêu ít".
///
/// [trungBinh] bằng 0 (kỳ không có khoản chi nào) thì phép chia ra `Infinity`
/// — vẫn so sánh được, và mọi ngày *có* chi rơi về bậc cao nhất. Đó là kết quả
/// đúng: trong một kỳ không chi gì, một ngày có chi **là** ngày đậm nhất.
int bacNhiet(double chi, {required double trungBinh}) {
  if (chi <= 0) return 0;
  final ti = chi / trungBinh;
  if (ti <= 0.5) return 1;
  if (ti <= 1.0) return 2;
  if (ti <= 2.0) return 3;
  return 4;
}

/// Các ô của lưới lịch cho [ky], theo thứ tự đọc. `null` là **ô trống** chèn
/// trước ngày đầu tiên để nó rơi đúng cột.
///
/// ⚠️ Lưới bắt đầu **thứ Hai** theo quy ước Việt Nam, nên số ô trống là
/// `weekday - 1` (`DateTime.monday == 1`). Chủ nhật đứng **cuối** hàng và cho
/// **sáu** ô trống — nhiều nhất có thể. Lệch một ô là **cả tháng lệch một
/// cột**, mà lưới nhìn vẫn rất hợp lý.
///
/// Không chèn ô trống ở cuối: `GridView` tự để hàng cuối thiếu ô.
///
/// Dùng `add(Duration(days: 1))` chứ không tự cộng số ngày của tháng, nên tháng
/// ngắn, tháng 12 và 29/02 năm nhuận đều đúng mà không có nhánh riêng.
List<DateTime?> oLich(Ky ky) {
  final o = <DateTime?>[];
  final dau = DateTime(ky.from.year, ky.from.month, ky.from.day);
  for (var i = 1; i < dau.weekday; i++) {
    o.add(null);
  }
  var d = dau;
  while (d.isBefore(ky.to)) {
    o.add(d);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return o;
}

/// Nhãn ngày cho thẻ tóm tắt: `"Thứ Sáu 11/09"`.
///
/// Tự viết thay vì `DateFormat('EEEE', 'vi')` vì hàm này thuần — widget test
/// nào quên `initializeDateFormatting` sẽ ném `LocaleDataException` và **cả cây
/// dừng dựng**, một cách hỏng rất khó đọc (đã vấp ở khối Top 5).
///
/// ⚠️ Chủ nhật **không** phải "Thứ Tám": `DateTime.sunday == 7` nên một công
/// thức `'Thứ ${weekday + 1}'` sẽ in đúng sáu ngày rồi sai ngày thứ bảy.
String nhanNgayLich(DateTime d) {
  const thu = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];
  final ngay = d.day.toString().padLeft(2, '0');
  final thang = d.month.toString().padLeft(2, '0');
  return '${thu[d.weekday - 1]} $ngay/$thang';
}
