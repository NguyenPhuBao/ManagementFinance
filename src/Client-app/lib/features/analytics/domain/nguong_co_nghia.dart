/// Ngưỡng "có nghĩa" neo theo thu nhập — **một định nghĩa** cho luật tái phân
/// bổ (C5, `ai_edge/domain/tai_phan_bo.dart`) và chi bất thường (B3, trang Phân
/// tích).
///
/// Dời từ `tai_phan_bo.dart` (2026-09-29, B3) để `analytics` không phải import
/// `ai_edge`; hành vi **không đổi** — `tai_phan_bo.dart` import lại và giữ nguyên
/// mọi tên riêng của nó (`nguongThamHutTuyetDoi`, `duDiaToiThieu`,
/// `buocLamTron` vẫn là luật của tái phân bổ).
library;

/// Sàn tuyệt đối 50.000 đ: sàn của B2 (vế tuyệt đối thâm hụt) **và** của
/// [nguongCoNghia] (C5, chi bất thường B3). Một hằng, không nhân đôi.
const double kNguongThamHutTuyetDoi = 50000;

/// Phép neo một ngưỡng tuyệt đối vào thu nhập — **một định nghĩa duy nhất** cho
/// mọi ngưỡng neo theo thu nhập của app.
///
/// `max(tiLe × thu nhập, san)`: hằng cũ thành **sàn**, nên tài khoản chưa có
/// thu nhập (hoặc thu nhập thấp) giữ nguyên hành vi, còn thu nhập cao thì mọi
/// ngưỡng giãn ra cùng nhau.
///
/// ⚠️ [thuNhapMoiThang] là thu nhập **trung bình MỘT THÁNG**, không phải tổng
/// cả cửa sổ: nguồn của nó (`thuNhapMoiThangTu`) quy về mức tháng bằng
/// `tổng / số ngày × 30`. Đọc nhầm là mọi tỉ lệ lệch hẳn một bậc, **im lặng**.
///
/// ⚠️ Cửa sổ ấy **cuộn theo ngày** (`cuaSoNhinLai`, tối đa 90 ngày, ngắn lại
/// theo tuổi dữ liệu). Trước 2026-09-21 nó là ba tháng lịch liền trước, và con
/// số ấy bằng **0** trên mọi dữ liệu thật — nên phép neo luôn rơi về sàn, tức nó
/// đúng về mã nhưng chưa từng có hiệu lực.
double neoTheoThuNhap(double thuNhapMoiThang, double tiLe, double san) {
  final theoThuNhap = thuNhapMoiThang * tiLe;
  return theoThuNhap > san ? theoThuNhap : san;
}

/// C5 (tái phân bổ) và B3 (chi bất thường): `max(1 % thu nhập, 50.000)`.
double nguongCoNghia(double thuNhapMoiThang) =>
    neoTheoThuNhap(thuNhapMoiThang, 0.01, kNguongThamHutTuyetDoi);

/// Làm tròn [x] về bội gần nhất của [buoc]. Dời từ `tai_phan_bo.dart` (B4,
/// 2026-09-29) để ước tính chi tuỳ ý của khối Dự báo dùng chung, không đổi
/// hành vi — `tai_phan_bo.dart` xuất lại tên này.
double lamTronBuoc(double x, double buoc) => (x / buoc).round() * buoc;
