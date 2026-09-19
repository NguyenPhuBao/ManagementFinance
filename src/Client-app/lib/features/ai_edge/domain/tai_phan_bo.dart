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

double lamTron10k(double x) =>
    (x / kBuocLamTron).round() * kBuocLamTron.toDouble();

/// C5: `max(1 % thu nhập, 50.000)`.
double nguongCoNghia(double thuNhap3Thang) {
  final motPhanTram = thuNhap3Thang * 0.01;
  return motPhanTram > 50000 ? motPhanTram : 50000;
}

/// Dự phóng chi cuối kỳ (B4 + B5). `null` khi kỳ rỗng hoặc dưới
/// [kNgayKhoaDuPhong] ngày mà không có [tb3Thang] — khi ấy người gọi chỉ được
/// dùng số đã chi, tức chỉ báo khi **đã** vượt.
double? duPhongCua(
  BudgetView v, {
  required DateTime now,
  required double? tb3Thang,
}) {
  final b = v.budget;
  final nhip = budgetPaceOf(b, now);
  if (nhip.daysTotal <= 0) return null;
  final daQua = nhip.daysTotal - nhip.daysLeft;
  if (daQua >= kNgayKhoaDuPhong) return b.spent * nhip.daysTotal / daQua;
  if (tb3Thang == null) return null;
  return b.spent + tb3Thang * nhip.daysLeft / nhip.daysTotal;
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
  required double thuNhap3Thang,
  required Map<String, double?> tb3ThangTheoNganSach,
  required List<PhanHoiCu> phanHoi,
}) {
  final ungVien = [
    for (final v in dangChay)
      if (v.budget.categoryId != null && !v.budget.isExpired(now)) v,
  ];
  if (ungVien.isEmpty) return null;

  double duPhong(BudgetView v) =>
      duPhongCua(v, now: now, tb3Thang: tb3ThangTheoNganSach[v.budget.id]) ??
      v.budget.spent;

  // ── Thâm hụt lớn nhất ────────────────────────────────────────────────────
  BudgetView? thieu;
  var thamHut = 0.0;
  var duPhongThieu = 0.0;
  for (final v in ungVien) {
    final dp = duPhong(v);
    final hut = dp - v.budget.amount;
    if (hut < kNguongThamHutTiLe * v.budget.amount) continue;
    if (hut < kNguongThamHutTuyetDoi) continue;
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
    if (duDia < kDuDiaToiThieu) continue;
    final tran = daBiCatHaiKyLienTruoc(v.budget, phanHoi, now)
        ? kTranCatDaBiCat
        : kTranCat;
    nguon.add(DongTaiPhanBo(
      nguon: v,
      duDia: duDia,
      soTien: lamTron10k(tran * duDia),
    ));
  }
  // Essentiality = 0,5 cho mọi danh mục → xếp theo dư địa. Hoà thì theo id để
  // hai lần dựng không đảo chỗ.
  nguon.sort((a, b) {
    final c = b.duDia.compareTo(a.duDia);
    return c != 0 ? c : a.nguon.budget.id.compareTo(b.nguon.budget.id);
  });

  final nguong = nguongCoNghia(thuNhap3Thang);
  final dong = <DongTaiPhanBo>[];
  var conThieu = thamHut;
  for (final n in nguon) {
    if (conThieu <= 0) break;
    // Cắt vừa đủ phần còn thiếu, làm tròn LÊN 10k để không hụt vài đồng lẻ.
    final can = (conThieu / kBuocLamTron).ceil() * kBuocLamTron.toDouble();
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
