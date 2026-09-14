import '../domain/phan_loai_dong_tien.dart';
import '../domain/thong_ke_thang.dart';

/// Một dòng trong bảng "Chi tiết danh mục", đã tra tên/biểu tượng/màu và ngân
/// sách đang chạy (nếu có) của danh mục ấy.
class DongDanhMuc {
  /// `null` = khoản chưa phân loại.
  final String? categoryId;
  final String ten;

  /// Tên biểu tượng như lưu trong cột `icon` — giao diện đổi sang `IconData`
  /// qua `categoryIconFor`. Giữ chuỗi ở tầng này để repository không kéo
  /// `material.dart` vào.
  final String? icon;

  /// Mã màu `#RRGGBB` như cột `colour`; đổi sang `Color` bằng
  /// `categoryColorFrom` ở giao diện.
  final String? mauHex;

  final double soTien;

  /// Tỉ lệ trên tổng của **nhóm chứa nó**, trong `[0, 1]`: tổng chi của tháng
  /// khi dòng đến từ [ThongKeThang.danhMuc], tổng của lát khi nó đến từ
  /// [ThongKeThang.danhMucTheoLat]. Tên trường giữ nguyên vì đổi nó chạm mọi
  /// nơi đọc, nhưng **mẫu số thì đổi theo nguồn** — nhãn hiển thị lấy từ
  /// `nhanTongCua()`.
  final double tiLeTongChi;

  /// Hạn mức và số đã chi của ngân sách **đang chạy** cho danh mục này tại
  /// tháng đang xem. Cả hai `null` khi danh mục không có ngân sách — giao diện
  /// đổi nhãn sang "% tổng chi" chứ **không bịa** một hạn mức.
  final double? nganSachHanMuc;
  final double? nganSachDaChi;

  const DongDanhMuc({
    required this.categoryId,
    required this.ten,
    required this.icon,
    required this.mauHex,
    required this.soTien,
    required this.tiLeTongChi,
    this.nganSachHanMuc,
    this.nganSachDaChi,
  });

  bool get coNganSach => nganSachHanMuc != null && nganSachHanMuc! > 0;

  /// `spent / amount`, chưa cắt trần — giao diện tự kẹp về 1.0 cho thanh.
  double? get tiLeNganSach =>
      coNganSach ? (nganSachDaChi ?? 0) / nganSachHanMuc! : null;
}

/// Toàn bộ số liệu trang Phân tích cần cho **một** tháng.
class ThongKeThang {
  final int nam;
  final int thang;
  final TongThuChi tong;

  /// Tháng liền trước, để hiện "so với T<n-1>".
  final TongThuChi tongTruoc;

  /// Chi theo danh mục, giảm dần — nguồn cho donut qua `topVaKhac`.
  final List<ChiTheoDanhMuc> chiTheoDanhMuc;

  /// Cùng thứ tự với [chiTheoDanhMuc], đã tra thông tin hiển thị.
  final List<DongDanhMuc> danhMuc;

  /// Sáu tháng liên tiếp kết thúc ở tháng đang xem, **cũ nhất trước** — nguồn
  /// cho biểu đồ xu hướng. Nhìn xa hơn [tongTruoc] nên nó phải được dựng từ
  /// **toàn bộ** giao dịch của tài khoản, không phải từ danh sách đã lọc theo
  /// tháng đang xem.
  final List<DiemThoiGian> chuoi;

  /// Tổng của từng phân loại, giảm dần theo số tiền. Phân loại rỗng đã bị bỏ,
  /// nên danh sách có thể ngắn hơn ba.
  ///
  /// Vòng tròn ba lát từng vẽ thẳng từ đây (A8 #2) đã bỏ ngày 2026-09-14;
  /// trường này vẫn là nguồn **duy nhất** cho biết nhóm nào có phát sinh, tức
  /// khối "Cơ cấu theo danh mục" hiện chip nào.
  final List<LatPhanLoai> latPhanLoai;

  /// Danh mục **bên trong** từng nhóm, khoá là `classify`. Nguồn cho cả vòng
  /// tròn lẫn danh sách cuối trang — hai khối đọc cùng một chỗ nên không thể
  /// nói hai con số khác nhau.
  final Map<String, List<DongDanhMuc>> danhMucTheoLat;

  /// Chuỗi 6 tháng cho từng danh mục có phát sinh — nguồn cho bộ chọn và đường
  /// đơn của khối xu hướng. Khoá `null` là khoản chưa phân loại.
  final Map<String?, List<DiemThoiGian>> chuoiDanhMuc;

  const ThongKeThang({
    required this.nam,
    required this.thang,
    required this.tong,
    required this.tongTruoc,
    required this.chiTheoDanhMuc,
    required this.danhMuc,
    required this.chuoi,
    this.latPhanLoai = const [],
    this.danhMucTheoLat = const {},
    this.chuoiDanhMuc = const {},
  });

  double? get thuSoVoiTruoc => phanTramSoVoi(tong.thu, tongTruoc.thu);
  double? get chiSoVoiTruoc => phanTramSoVoi(tong.chi, tongTruoc.chi);

  /// Tháng không có thu lẫn chi. Giao diện nói rỗng thay vì vẽ toàn số 0.
  bool get rong => tong.thu == 0 && tong.chi == 0;

  DongDanhMuc? dongCua(String? categoryId) {
    for (final d in danhMuc) {
      if (d.categoryId == categoryId) return d;
    }
    // Danh mục thu và vay/nợ không nằm trong `danhMuc` (chỉ có chi), nên phải
    // tra tiếp trong các lát — nếu không, chú giải đường đơn của khối xu hướng
    // mất tên và màu khi người dùng chọn một danh mục thu.
    for (final ds in danhMucTheoLat.values) {
      for (final d in ds) {
        if (d.categoryId == categoryId) return d;
      }
    }
    return null;
  }

  /// Danh mục của một lát, rỗng khi lát ấy không có gì.
  List<DongDanhMuc> danhMucCua(String phanLoai) =>
      danhMucTheoLat[phanLoai] ?? const [];
}

abstract class AnalyticsRepository {
  /// Phát lại mỗi khi giao dịch, danh mục **hoặc** ngân sách đổi.
  ///
  /// [now] tiêm được để test không phụ thuộc đồng hồ máy; nó quyết định mốc
  /// tra ngân sách của tháng đang xem.
  Stream<ThongKeThang> watchThang(
    int idaccount, {
    required int nam,
    required int thang,
    DateTime? now,
  });
}
