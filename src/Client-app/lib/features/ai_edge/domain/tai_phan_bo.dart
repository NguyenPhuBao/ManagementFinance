/// Tầng 2 — thâm hụt, nguồn bù, kế hoạch tái phân bổ. Hàm thuần: không đọc
/// đồng hồ, không chạm CSDL. Luật ở spec mục 3.1 (bản đã điều chỉnh của nhóm
/// B–C–G trong đặc tả Edge-SLM).
///
/// ## Điều phải nói thẳng
///
/// - **Essentiality = 0,5 cho mọi danh mục** (chưa có thống kê), nên phép xếp
///   hạng C6 `dư địa × (1 − essentiality)` **quy về xếp theo dư địa**. Cờ
///   "Cố định" (C2) là lớp bảo vệ duy nhất của người dùng, và nó thắng tuyệt đối.
/// - **D5 bỏ**: tái phân bổ giữ tổng hạn mức không đổi (cắt X thì cộng X), nên
///   trần `Σ hạn mức ≤ thu nhập × (1 − tỉ lệ tiết kiệm)` không thể bị vi phạm
///   bởi bước này.
/// - Mỗi lượt **một** kế hoạch, cho ngân sách thâm hụt **lớn nhất**: người dùng
///   duyệt từng dòng, nhiều kế hoạch cùng lúc là nhiều sheet chồng nhau.
library;

import '../../../core/utils/currency_formatter.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_history.dart';
import '../../analytics/domain/du_bao_dong_tien.dart' show buocTron;
import '../../budget/domain/budget_pace.dart';

/// B2: thâm hụt phải ≥ 10 % hạn mức **và** ≥ 50.000 đ.
const double kNguongThamHutTiLe = 0.10;
const double kNguongThamHutTuyetDoi = 50000;

/// C4: nguồn bù phải còn ít nhất chừng này sau dự phóng.
const double kDuDiaToiThieu = 100000;

/// C3: cắt tối đa 25 % dư địa; 15 % nếu đã bị cắt hai kỳ liền trước.
const double kTranCat = 0.25;
const double kTranCatDaBiCat = 0.15;

/// G1: mọi số tiền đề xuất làm tròn tới bội của 10.000.
const int kBuocLamTron = 10000;

/// B4: dưới chừng này ngày thì không nhân tỉ lệ tuyến tính.
const int kNgayKhoaDuPhong = 5;

double lamTronBuoc(double x, double buoc) => (x / buoc).round() * buoc;

/// Phép neo một ngưỡng tuyệt đối vào thu nhập — **một định nghĩa duy nhất** cho
/// cả bốn ngưỡng dưới đây.
///
/// `max(tiLe × thu nhập, san)`: hằng cũ thành **sàn**, nên tài khoản chưa có
/// thu nhập (hoặc thu nhập thấp) giữ nguyên hành vi hôm nay, còn thu nhập cao
/// thì mọi ngưỡng giãn ra cùng nhau.
///
/// ⚠️ [thuNhapMoiThang] là thu nhập **trung bình MỘT THÁNG**, không phải tổng
/// cả cửa sổ: nguồn của nó quy về mức tháng bằng `tổng / số ngày × 30`. Đọc
/// nhầm là mọi tỉ lệ dưới đây lệch hẳn một bậc, **im lặng**.
///
/// ⚠️ Cửa sổ ấy **cuộn theo ngày** (`cuaSoNhinLai`, tối đa 90 ngày, ngắn lại
/// theo tuổi dữ liệu). Trước 2026-09-21 nó là ba tháng lịch liền trước, và con
/// số ấy bằng **0** trên mọi dữ liệu thật — nên phép neo dưới đây luôn rơi về
/// sàn, tức nó đúng về mã nhưng chưa từng có hiệu lực.
double _neo(double thuNhapMoiThang, double tiLe, double san) {
  final theoThuNhap = thuNhapMoiThang * tiLe;
  return theoThuNhap > san ? theoThuNhap : san;
}

/// C5: `max(1 % thu nhập, 50.000)`.
double nguongCoNghia(double thuNhapMoiThang) =>
    _neo(thuNhapMoiThang, 0.01, kNguongThamHutTuyetDoi);

/// B2 vế tuyệt đối, neo theo thu nhập: `max(1 % thu nhập, 50.000)`.
///
/// Cùng công thức với [nguongCoNghia] nhưng là **luật khác** (B2 lọc ngân sách
/// thâm hụt, C5 lọc dòng cắt quá nhỏ) — giữ hai tên để đổi một cái không kéo
/// theo cái kia.
double nguongThamHutTuyetDoi(double thuNhapMoiThang) =>
    _neo(thuNhapMoiThang, 0.01, kNguongThamHutTuyetDoi);

/// C4 neo theo thu nhập: `max(2 % thu nhập, 100.000)`.
///
/// ⚠️ Luật này **đã bị C5 nuốt trọn** và không còn tự loại được nguồn nào: dư
/// địa dưới 2 % thu nhập cho phần cắt 25 % dưới 0,5 % thu nhập, tức dưới ngưỡng
/// có nghĩa 1 % mà C5 đã chặn trước. Giữ lại vì nó là một luật của đặc tả và vì
/// nới `kTranCat` hay hạ C5 sẽ làm nó sống lại — nhưng **đừng viết ca test hành
/// vi cho nó**, ca ấy sẽ xanh vì lý do khác (ghi rõ ở tệp test).
double duDiaToiThieu(double thuNhapMoiThang) =>
    _neo(thuNhapMoiThang, 0.02, kDuDiaToiThieu);

/// G1 neo theo thu nhập: `max(0,2 % thu nhập, 10.000)`, rồi **kéo lên họ
/// 1·2·2,5·5**.
///
/// ⚠️ Vế thứ hai là bắt buộc, khác hai ngưỡng trên: hai cái kia chỉ đem đi
/// **so sánh** nên số lẻ vô hại, còn bước làm tròn quyết định **con số người
/// dùng đọc**. Bỏ nó thì thu nhập 12 triệu cho bước 24.000 và màn hình đầy
/// 24.000 / 48.000 / 72.000 — tròn về mặt số học, xấu về mặt người đọc.
double buocLamTron(double thuNhapMoiThang) =>
    buocTron(_neo(thuNhapMoiThang, 0.002, kBuocLamTron.toDouble()));

/// Dự phóng chi cuối kỳ (B4 + B5). `null` khi kỳ rỗng hoặc dưới
/// [kNgayKhoaDuPhong] ngày mà không có [mucThang] — khi ấy người gọi chỉ được
/// dùng số đã chi, tức chỉ báo khi **đã** vượt.
double? duPhongCua(
  BudgetView v, {
  required DateTime now,
  required double? mucThang,
}) {
  final b = v.budget;
  final nhip = budgetPaceOf(b, now);
  if (nhip.daysTotal <= 0) return null;
  final daQua = nhip.daysTotal - nhip.daysLeft;
  if (daQua >= kNgayKhoaDuPhong) return b.spent * nhip.daysTotal / daQua;
  if (mucThang == null) return null;
  return b.spent + mucThang * nhip.daysLeft / nhip.daysTotal;
}

class DongTaiPhanBo {
  final BudgetView nguon;
  final double duDia;
  final double soTien;
  const DongTaiPhanBo(
      {required this.nguon, required this.duDia, required this.soTien});
}

enum TrangThaiKeHoach { duNguonBu, thieuNguonBu }

class KeHoachTaiPhanBo {
  final BudgetView thieu;
  final double duPhong;
  final double thamHut;
  final List<DongTaiPhanBo> dong;
  final TrangThaiKeHoach trangThai;
  final double soThieu;

  const KeHoachTaiPhanBo({
    required this.thieu,
    required this.duPhong,
    required this.thamHut,
    required this.dong,
    required this.trangThai,
    required this.soThieu,
  });

  double get tongCat => dong.fold(0, (s, d) => s + d.soTien);

  /// Câu tóm tắt cho thẻ trên trang Ngân sách và đuôi câu nhận xét. ⚠️ Mọi con
  /// số ở đây phải có trong `GoiSoNganSach.soLieu` (bộ kiểm số) — gói ấy thêm
  /// `Thâm hụt`, `Nguồn bù`, `Còn thiếu` khi có kế hoạch.
  String get cauTomTat {
    final ten = thieu.displayName;
    final hut = CurrencyFormatter.format(thamHut);
    if (trangThai == TrangThaiKeHoach.duNguonBu) {
      return '$ten dự kiến vượt $hut. Bớt từ ${dong.length} ngân sách khác?';
    }
    final thieuChu = CurrencyFormatter.format(soThieu);
    if (dong.isEmpty) {
      return '$ten dự kiến vượt $hut, nhưng không ngân sách nào còn dư địa '
          'để bù (thiếu $thieuChu).';
    }
    return '$ten dự kiến vượt $hut, các ngân sách khác chỉ bù được '
        '${CurrencyFormatter.format(tongCat)} (thiếu $thieuChu).';
  }
}

/// Một dòng phản hồi cũ — rút gọn của hàng `AiRebalancingFeedbacks`.
class PhanHoiCu {
  final String donorBudgetId;

  /// `accepted` | `rejected` | `modified`.
  final String action;
  final DateTime periodFrom;
  const PhanHoiCu({
    required this.donorBudgetId,
    required this.action,
    required this.periodFrom,
  });
}

/// C3: [nguon] đã bị cắt (chấp nhận hoặc sửa) ở **cả hai** kỳ liền trước kỳ
/// hiện tại. Kỳ cắt bằng `recentPeriods` — cùng phép cắt với chính ngân sách.
bool daBiCatHaiKyLienTruoc(
  BudgetEntity nguon,
  List<PhanHoiCu> phanHoi,
  DateTime now,
) {
  final ky = recentPeriods(nguon, count: 3, now: now);
  if (ky.length < 3) return false;
  final truoc = ky.sublist(0, 2);
  return truoc.every((k) => phanHoi.any((p) =>
      p.donorBudgetId == nguon.id &&
      (p.action == 'accepted' || p.action == 'modified') &&
      !p.periodFrom.isBefore(k.from) &&
      p.periodFrom.isBefore(k.to)));
}

/// Kế hoạch cho ngân sách thâm hụt lớn nhất trong [dangChay], hoặc `null` khi
/// không ngân sách nào thâm hụt. [coDinh] là tập **categoryId** có cờ Cố định.
KeHoachTaiPhanBo? taiPhanBoCua({
  required List<BudgetView> dangChay,
  required DateTime now,
  required Set<String> coDinh,
  required double thuNhapMoiThang,
  required Map<String, double?> mucThangTheoNganSach,
  required List<PhanHoiCu> phanHoi,
}) {
  final ungVien = [
    for (final v in dangChay)
      if (v.budget.categoryId != null && !v.budget.isExpired(now)) v,
  ];
  if (ungVien.isEmpty) return null;

  // Bốn ngưỡng neo theo thu nhập, tính MỘT lần cho cả lượt dựng kế hoạch.
  final nguongHut = nguongThamHutTuyetDoi(thuNhapMoiThang);
  final sanDuDia = duDiaToiThieu(thuNhapMoiThang);
  final buoc = buocLamTron(thuNhapMoiThang);

  double duPhong(BudgetView v) =>
      duPhongCua(v, now: now, mucThang: mucThangTheoNganSach[v.budget.id]) ??
      v.budget.spent;

  // ── Thâm hụt lớn nhất ────────────────────────────────────────────────────
  BudgetView? thieu;
  var thamHut = 0.0;
  var duPhongThieu = 0.0;
  for (final v in ungVien) {
    final dp = duPhong(v);
    final hut = dp - v.budget.amount;
    if (hut < kNguongThamHutTiLe * v.budget.amount) continue;
    if (hut < nguongHut) continue;
    if (hut > thamHut) {
      thieu = v;
      thamHut = hut;
      duPhongThieu = dp;
    }
  }
  if (thieu == null) return null;

  // ── Nguồn bù ─────────────────────────────────────────────────────────────
  final nguon = <DongTaiPhanBo>[];
  for (final v in ungVien) {
    if (identical(v, thieu) || v.budget.id == thieu.budget.id) continue;
    if (coDinh.contains(v.budget.categoryId)) continue;
    final duDia = v.budget.amount - duPhong(v);
    if (duDia < sanDuDia) continue;
    final tran = daBiCatHaiKyLienTruoc(v.budget, phanHoi, now)
        ? kTranCatDaBiCat
        : kTranCat;
    nguon.add(DongTaiPhanBo(
      nguon: v,
      duDia: duDia,
      soTien: lamTronBuoc(tran * duDia, buoc),
    ));
  }
  // Essentiality = 0,5 cho mọi danh mục → xếp theo dư địa. Hoà thì theo id để
  // hai lần dựng không đảo chỗ.
  nguon.sort((a, b) {
    final c = b.duDia.compareTo(a.duDia);
    return c != 0 ? c : a.nguon.budget.id.compareTo(b.nguon.budget.id);
  });

  final nguong = nguongCoNghia(thuNhapMoiThang);
  final dong = <DongTaiPhanBo>[];
  var conThieu = thamHut;
  for (final n in nguon) {
    if (conThieu <= 0) break;
    // Cắt vừa đủ phần còn thiếu, làm tròn LÊN 10k để không hụt vài đồng lẻ.
    final can = (conThieu / buoc).ceil() * buoc;
    final cat = n.soTien < can ? n.soTien : can;
    if (cat < nguong) continue;
    dong.add(DongTaiPhanBo(nguon: n.nguon, duDia: n.duDia, soTien: cat));
    conThieu -= cat;
  }

  final tongCat = dong.fold<double>(0, (s, d) => s + d.soTien);
  final du = tongCat >= thamHut;
  return KeHoachTaiPhanBo(
    thieu: thieu,
    duPhong: duPhongThieu,
    thamHut: thamHut,
    dong: dong,
    trangThai: du ? TrangThaiKeHoach.duNguonBu : TrangThaiKeHoach.thieuNguonBu,
    soThieu: du ? 0 : thamHut - tongCat,
  );
}
