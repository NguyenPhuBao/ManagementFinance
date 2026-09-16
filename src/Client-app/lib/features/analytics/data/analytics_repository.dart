import '../domain/bao_cao_xuat.dart';
import '../domain/du_bao_dong_tien.dart';
import '../domain/pham_vi_ky.dart';
import '../domain/vai_vay_no.dart';
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
  /// khi dòng đến từ [ThongKeKy.danhMuc], tổng của lát khi nó đến từ
  /// [ThongKeKy.danhMucTheoLat]. Tên trường giữ nguyên vì đổi nó chạm mọi
  /// nơi đọc, nhưng **mẫu số thì đổi theo nguồn** — nhãn hiển thị lấy từ
  /// `nhanTongCua()`.
  final double tiLeTongChi;

  /// Hạn mức và số đã chi của ngân sách **đang chạy** cho danh mục này.
  ///
  /// Cả hai `null` khi danh mục không có ngân sách — giao diện đổi nhãn sang
  /// "% tổng chi" chứ **không bịa** một hạn mức. Từ 2026-09-15 chúng cũng `null`
  /// khi **kỳ đang xem không phải một tháng**: `spent` đếm theo kỳ của chính
  /// ngân sách, nên vẽ nó cạnh số liệu một tuần là so hai kỳ khác nhau.
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

/// Toàn bộ số liệu trang Phân tích cần cho **một** kỳ.
class ThongKeKy {
  /// Kỳ đang xem — tuần, tháng, quý, năm, hay một khoảng tuỳ chọn.
  final Ky ky;

  final TongThuChi tong;

  /// Kỳ liền trước cùng độ dài, để hiện "so với kỳ trước".
  final TongThuChi tongTruoc;

  /// Chi theo danh mục, giảm dần — nguồn cho donut qua `topVaKhac`.
  final List<ChiTheoDanhMuc> chiTheoDanhMuc;

  /// Cùng thứ tự với [chiTheoDanhMuc], đã tra thông tin hiển thị.
  final List<DongDanhMuc> danhMuc;

  /// Sáu kỳ liên tiếp kết thúc ở kỳ đang xem, **cũ nhất trước** — nguồn cho
  /// biểu đồ xu hướng. Nhìn xa hơn [tongTruoc] nên nó phải được dựng từ **toàn
  /// bộ** giao dịch của tài khoản, không phải từ danh sách đã lọc theo kỳ đang
  /// xem.
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

  /// Chuỗi 6 kỳ cho từng danh mục có phát sinh — nguồn cho bộ chọn và đường
  /// đơn của khối xu hướng. Khoá `null` là khoản chưa phân loại.
  final Map<String?, List<DiemThoiGian>> chuoiDanhMuc;

  // ── Bốn khối mượn từ trang Xuất báo cáo (P2, 2026-09-15) ────────────────
  //
  // Bốn phép tính là **hàm thuần dùng chung** ở `bao_cao_xuat.dart`, không phải
  // bản chép tay thứ hai: hai trang nói cùng một con số cho cùng một kỳ là điều
  // kiện, không phải điều mong.

  /// Chi mỗi ngày, ngày chi nhiều nhất, khoản chi lớn nhất.
  final SoLieuNhanh soLieu;

  /// Thu/chi theo từng ví, giảm dần theo chi. Rỗng khi kỳ không có giao dịch.
  final List<DongVi> theoVi;

  /// Tối đa 5 khoản chi lớn nhất của kỳ, giảm dần.
  final List<DongGiaoDich> topChi;

  /// Số dư ví ở hai đầu kỳ.
  ///
  /// ⚠️ **Suy ngược** từ tổng số dư hiện tại — app không lưu lịch sử số dư.
  /// Giao diện **phải** mang theo câu nói rõ điều đó; bê mỗi con số là để người
  /// đọc tưởng đây là số đo. Lệch khi có ví tạo giữa kỳ (mục 3.16).
  ///
  /// `null` khi chưa đọc được số dư ví.
  final DongTien? dongTien;

  /// Sáu kỳ gom theo **vai vay/nợ** — nguồn cho hai biểu đồ "Cho vay & Thu nợ"
  /// và "Đi vay & Trả nợ" (A8 #4, #5).
  ///
  /// Cùng lý do với [chuoi]: dựng từ **toàn bộ** giao dịch chứ không phải từ
  /// danh sách đã lọc theo kỳ, vì chuỗi nhìn xa sáu kỳ.
  final List<DiemVayNo> chuoiVayNo;

  /// Dự báo 30 ngày tới (2026-09-16) — **luôn tính từ `now`**, không theo
  /// [ky]. Người dùng đang xem tháng 6 vẫn thấy dự báo của 30 ngày kể từ hôm
  /// nay; khối trên giao diện nói rõ điều đó.
  ///
  /// `null` khi tài khoản không có ví sống nào — không có thang đo, cùng chốt
  /// `dongTien == null` của thác nước.
  ///
  /// ⚠️ Nguồn ngân sách của nó là `watchBudgets(now: at)` **riêng**, không
  /// dùng chung nguồn `mocNganSach` của kỳ đang xem — xem chú thích ở
  /// `AnalyticsRepositoryImpl.watchKy`.
  final DuBaoDongTien? duBao;

  const ThongKeKy({
    required this.ky,
    required this.tong,
    required this.tongTruoc,
    required this.chiTheoDanhMuc,
    required this.danhMuc,
    required this.chuoi,
    this.latPhanLoai = const [],
    this.danhMucTheoLat = const {},
    this.chuoiDanhMuc = const {},
    this.soLieu = const SoLieuNhanh(
      chiMoiNgay: 0,
      ngayChiNhieuNhat: null,
      chiNgayNhieuNhat: 0,
      khoanChiLonNhat: null,
    ),
    this.theoVi = const [],
    this.topChi = const [],
    this.dongTien,
    this.chuoiVayNo = const [],
    this.duBao,
  });

  double? get thuSoVoiTruoc => phanTramSoVoi(tong.thu, tongTruoc.thu);
  double? get chiSoVoiTruoc => phanTramSoVoi(tong.chi, tongTruoc.chi);

  /// Kỳ không có thu lẫn chi. Giao diện nói rỗng thay vì vẽ toàn số 0.
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
  /// tra ngân sách của kỳ đang xem.
  Stream<ThongKeKy> watchKy(
    int idaccount, {
    required Ky ky,
    DateTime? now,
  });
}
