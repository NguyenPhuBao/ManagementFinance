/// Dự báo dòng tiền 30 ngày tới — tầng thuần. Không Drift query, không
/// Flutter, không đồng hồ hệ thống.
///
/// Spec: `docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md`.
///
/// ## Trả lời câu gì
///
/// *"Còn tiêu được bao nhiêu sau khi trừ những thứ CHẮC CHẮN phải trả trong 30
/// ngày tới?"* — hoá đơn tới hạn (kể cả kỳ tương lai chiếu từ hoá đơn lặp) và
/// trích tự động vào mục tiêu. Tầng thứ hai, tách riêng: phần **còn lại** của
/// ngân sách kỳ hiện tại, nếu người dùng tiêu đúng kế hoạch.
///
/// ## Điều cố ý KHÔNG làm
///
/// Không thu nhập (app không lưu ở đâu; suy từ lịch sử là một con số đoán ngồi
/// cạnh những con số thật), không chi tuỳ ý, không kỳ ngân sách sau. Người dùng
/// chốt 2026-09-16. Hệ quả: mọi con số ở đây **được phép âm** và không kẹp —
/// kẹp về 0 là giấu đúng cảnh báo.
///
/// ## Luật chuyển ví (§4.5 spec)
///
/// Hoá đơn trừ ví trả. Trích tự động trừ ví nguồn và **cộng** ví đích, nên tác
/// động lên TỔNG tài sản thường bằng 0 — trừ khi ví đích không tính vào tổng
/// (ví Tiết kiệm bị loại, hoặc mục tiêu chưa gán ví). "Tính vào tổng" là
/// `viTinhVaoTong`, cùng luật Trang chủ. Theo TỪNG VÍ thì tiền rời ví là thật
/// dù tổng không đổi — đó là thứ [ViThieu] đo.
library;

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../bill/domain/bill_ky_ke_tiep.dart';
import '../../bill/domain/bill_pay_status.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_auto_deposit.dart';
import '../../wallet/domain/vi_tinh_vao_tong.dart';
import '../../wallet/domain/wallet_status.dart';
import 'thong_ke_thang.dart';

/// Tầm nhìn: hôm nay + 30 ngày, tức chuỗi có 31 điểm. Cố định, không bộ chọn
/// — tầng ngân sách đếm theo kỳ của chính ngân sách (thường tháng), tầm nhìn
/// lệch xa 30 là hai tầng nói hai khoảng khác nhau.
const int kSoNgayDuBao = 30;

/// Trần số kỳ chiếu cho MỖI hoá đơn / mục tiêu. Chu kỳ tuần trong 30 ngày là
/// ≤ 5 kỳ; 12 là dư. Vượt trần thì dừng im lặng, cùng lối `_tranDoMoc` của
/// `goal_auto_deposit.dart`.
const int _tranKyChieu = 12;

enum LoaiCamKet { hoaDon, trichTuDong }

/// Một khoản tiền CHẮC CHẮN sẽ rời một ví trong 30 ngày tới.
class CamKet {
  /// Đầu ngày. Cam kết quá hạn / đã tới hạn dồn về hôm nay.
  final DateTime ngay;
  final String ten;
  final LoaiCamKet loai;

  /// Ví BỊ TRỪ: hoá đơn là ví trả, trích là ví nguồn.
  final String walletId;

  /// Ví NHẬN — chỉ trích tự động (ví đích của mục tiêu). `null` với hoá đơn,
  /// và với mục tiêu chưa gán ví.
  final String? viNhanId;

  /// Tên ví bị trừ; `null` khi ví không còn hàng nào.
  final String? tenVi;

  /// Luôn dương.
  final double soTien;

  /// Hoá đơn: danh mục, để tầng ngân sách khử đếm đôi. Trích: `null`.
  final String? categoryId;

  /// Hạn đã qua mà chưa trả (chỉ hoá đơn).
  final bool quaHan;

  /// Kỳ TƯƠNG LAI suy ra, chưa là hàng thật. Mọi khoản trích đều là chiếu.
  final bool laKyChieu;

  /// Ảnh hưởng lên TỔNG tài sản, có dấu — xem luật chuyển ví ở đầu tệp.
  final double tacDongTong;

  const CamKet({
    required this.ngay,
    required this.ten,
    required this.loai,
    required this.walletId,
    this.viNhanId,
    required this.tenVi,
    required this.soTien,
    required this.categoryId,
    required this.quaHan,
    required this.laKyChieu,
    required this.tacDongTong,
  });
}

/// Một ví không đủ trả cam kết của chính nó.
class ViThieu {
  final String walletId;
  final String ten;

  /// Số dương: còn thiếu bao nhiêu ở điểm thấp nhất.
  final double thieu;

  /// Ngày đầu tiên số dư ví xuống dưới 0.
  final DateTime ngay;

  const ViThieu({
    required this.walletId,
    required this.ten,
    required this.thieu,
    required this.ngay,
  });
}

/// Một điểm của chuỗi 31 ngày.
class DiemDuBao {
  final DateTime ngay;

  /// Tầng 1 tích luỹ tới hết ngày này.
  final double chacChan;

  /// [chacChan] trừ ngân sách rải đều theo ngày: `− nganSachConLai × i / 30`.
  final double theoNganSach;

  const DiemDuBao({
    required this.ngay,
    required this.chacChan,
    required this.theoNganSach,
  });
}

class DuBaoDongTien {
  /// Hôm nay, đầu ngày.
  final DateTime tu;

  /// Σ `balance` của ví qua `viTinhVaoTong`, bỏ ví đã xoá mềm.
  final double soDuHienTai;

  /// Sắp theo ngày rồi theo tên.
  final List<CamKet> camKet;

  /// Σ (−tacDongTong) — dương khi tiền ra.
  final double tongCamKet;

  /// Tầng 2, ≥ 0.
  final double nganSachConLai;
  final List<ViThieu> viThieu;

  /// ĐÚNG 31 điểm.
  final List<DiemDuBao> chuoi;

  const DuBaoDongTien({
    required this.tu,
    required this.soDuHienTai,
    required this.camKet,
    required this.tongCamKet,
    required this.nganSachConLai,
    required this.viThieu,
    required this.chuoi,
  });

  double get conTieuDuoc => soDuHienTai - tongCamKet;
  double get conTieuDuocTheoNganSach => conTieuDuoc - nganSachConLai;
  bool get coNganSach => nganSachConLai > 0;
}

DateTime _dauNgay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Dự báo từ [now]. `null` khi không có ví sống nào — không có thang đo,
/// cùng chốt `dongTien == null` của thác nước.
///
/// [nganSach] phải là kết quả của `watchBudgets(now: now)` — KHÔNG phải của
/// mốc kỳ đang xem (`mocNganSach`), xem §5.1 spec: mốc ấy lùi về cuối kỳ khi
/// người dùng xem kỳ cũ, và `spent` sẽ là của kỳ khác. [vi] nhận cả hàng đã
/// xoá mềm để tra tên; số dư và cảnh báo tự lọc.
DuBaoDongTien? duBaoCua({
  required DateTime now,
  required List<Bill> hoaDon,
  required List<GoalEntity> mucTieu,
  required List<BudgetView> nganSach,
  required List<Wallet> vi,
}) {
  final viSong = [
    for (final v in vi)
      if (!v.isDeleted) v
  ];
  if (viSong.isEmpty) return null;

  final homNay = _dauNgay(now);
  // Ngày cuối CÒN TÍNH (biên đóng): hôm nay + 30. `DateTime(d + 30)` tự cuộn
  // tháng, không cộng Duration để khỏi lệ thuộc giờ.
  final cuoi = DateTime(homNay.year, homNay.month, homNay.day + kSoNgayDuBao);
  final viTheoId = {for (final v in vi) v.id: v};

  bool tinhVaoTong(String? id) {
    final v = id == null ? null : viTheoId[id];
    if (v == null || v.isDeleted) return false;
    return viTinhVaoTong(includeInTotal: v.includeInTotal, status: v.status);
  }

  final camKet = <CamKet>[
    ..._camKetHoaDon(hoaDon,
        homNay: homNay,
        cuoi: cuoi,
        viTheoId: viTheoId,
        tinhVaoTong: tinhVaoTong),
    ..._camKetMucTieu(mucTieu,
        now: now,
        homNay: homNay,
        cuoi: cuoi,
        viTheoId: viTheoId,
        tinhVaoTong: tinhVaoTong),
  ]..sort((a, b) {
      final c = a.ngay.compareTo(b.ngay);
      return c != 0 ? c : a.ten.compareTo(b.ten);
    });

  // Đọc `balance` — cache của một công thức (G37) nhưng mọi màn khác đều đọc
  // cache ấy; tính lại ở đây là hai con số trên cùng màn hình (bẫy 8).
  final soDu = viSong
      .where((v) => tinhVaoTong(v.id))
      .fold<double>(0, (s, v) => s + v.balance);
  final tongCamKet = camKet.fold<double>(0, (s, c) => s - c.tacDongTong);
  final nganSachConLai = _nganSachConLai(nganSach,
      now: now, homNay: homNay, cuoi: cuoi, camKet: camKet);

  return DuBaoDongTien(
    tu: homNay,
    soDuHienTai: soDu,
    camKet: camKet,
    tongCamKet: tongCamKet,
    nganSachConLai: nganSachConLai,
    viThieu: _viThieu(camKet, viTheoId),
    chuoi: chuoiDuBao(
        homNay: homNay,
        soDu: soDu,
        camKet: camKet,
        nganSachConLai: nganSachConLai),
  );
}

// ── Hoá đơn ───────────────────────────────────────────────────────────────

List<CamKet> _camKetHoaDon(
  List<Bill> hoaDon, {
  required DateTime homNay,
  required DateTime cuoi,
  required Map<String, Wallet> viTheoId,
  required bool Function(String?) tinhVaoTong,
}) {
  // Hàng đã sinh kỳ sau thì kỳ sau tự có mặt trong danh sách — chỉ chiếu từ
  // HÀNG CUỐI CHUỖI. ⚠️ Không bắt được hàng người dùng tự tạo tay cho kỳ sau
  // (bẫy 11 spec, cố ý không vá bằng so tên).
  final daSinhKySau = <String>{
    for (final b in hoaDon)
      if (b.generatedFromBillId != null) b.generatedFromBillId!,
  };

  final ra = <CamKet>[];
  for (final b in hoaDon) {
    // `conPhaiTra` là định nghĩa duy nhất: đã trả, đã bỏ qua đều không phải nợ.
    if (b.isDeleted || !conPhaiTra(b) || b.amount <= 0) continue;
    final viId = b.walletId;
    if (viId == null) continue; // bộ tự trả cũng từ chối hàng này
    if (_dauNgay(b.dueDate).isAfter(cuoi)) continue;

    CamKet camKetTu(DateTime hanTra, {required bool laKyChieu}) {
      final ngayHan = _dauNgay(hanTra);
      final quaHan = ngayHan.isBefore(homNay);
      return CamKet(
        ngay: quaHan ? homNay : ngayHan,
        ten: b.name,
        loai: LoaiCamKet.hoaDon,
        walletId: viId,
        tenVi: viTheoId[viId]?.name,
        soTien: b.amount,
        categoryId: b.categoryId,
        quaHan: quaHan,
        laKyChieu: laKyChieu,
        tacDongTong: tinhVaoTong(viId) ? -b.amount : 0,
      );
    }

    ra.add(camKetTu(b.dueDate, laKyChieu: false));
    if (!b.isRecurrence || daSinhKySau.contains(b.id)) continue;

    // Chiếu kỳ tương lai bằng ĐÚNG luật của payBill (`kyKeTiepCua`). Mỗi vòng
    // dựng lại một Bill từ kỳ vừa chiếu để anchorDay đi theo chuỗi — cộng dồn
    // từ kỳ trước là "ngày 31" tụt về 28 vĩnh viễn (bẫy 3).
    var hienTai = b;
    for (var n = 0; n < _tranKyChieu; n++) {
      final ky = kyKeTiepCua(hienTai);
      // Chu kỳ lạ: `nextBillDueDate` trả nguyên mốc → hạn không tiến → dừng,
      // không lặp vô hạn.
      if (!ky.hanTra.isAfter(hienTai.dueDate)) break;
      if (_dauNgay(ky.hanTra).isAfter(cuoi)) break;
      ra.add(camKetTu(ky.hanTra, laKyChieu: true));
      hienTai = hienTai.copyWith(
        startDate: Value(ky.batDau),
        periodEnd: Value(ky.ketThuc),
        dueDate: ky.hanTra,
        anchorDay: Value(ky.anchorDay),
      );
    }
  }
  return ra;
}

// ── Mục tiêu ──────────────────────────────────────────────────────────────

/// Trần vòng dò từ mốc neo tới sàn — mốc neo qua đồng bộ có thể là rác từ
/// năm 1990, và bước từng ngày từ đó là hàng chục nghìn vòng lặp ngay trong
/// một lần dựng trang. Cùng con số và cùng lối với `goal_auto_deposit.dart`.
const int _tranDoMoc = 1000;

/// Các kỳ trích tự động rơi vào 30 ngày tới.
///
/// Ba chốt bỏ qua mượn nguyên `GoalAutoDepositRunner._chayMotMucTieu`: bật đủ
/// ba mảnh cấu hình, chưa xong, và ví nguồn tồn tại + hoạt động + khác ví
/// đích. Phép dò mốc mượn `mocThuN` — neo mốc gốc, **không cộng dồn** — nên
/// nhịp "ngày 31" không tụt dần như bản cộng dồn từng kỳ.
List<CamKet> _camKetMucTieu(
  List<GoalEntity> mucTieu, {
  required DateTime now,
  required DateTime homNay,
  required DateTime cuoi,
  required Map<String, Wallet> viTheoId,
  required bool Function(String?) tinhVaoTong,
}) {
  final ra = <CamKet>[];
  // Biên MỞ sau ngày cuối: mốc trích mang GIỜ, nên so thời điểm với `cuoi`
  // (00:00) sẽ cắt mất mốc 08/10 20:00 — một kỳ biến mất, im lặng.
  final sauCuoi = DateTime(cuoi.year, cuoi.month, cuoi.day + 1);

  for (final g in mucTieu) {
    if (g.isDeleted ||
        !g.autoDepositEnabled ||
        g.daHoanThanh ||
        g.remainingAmount <= 0) {
      continue;
    }
    final nguonId = g.autoDepositWalletId!;
    final nguon = viTheoId[nguonId];
    // Ví nguồn trùng ví tích luỹ thì tiền không đi đâu cả; ví lưu trữ thì
    // người dùng đã cất đi. Cả hai đều là ca `khongChayDuoc` của bộ trích.
    if (nguon == null ||
        nguon.isDeleted ||
        nguonId == g.walletId ||
        !WalletStatus.laHoatDong(nguon.status)) {
      continue;
    }

    // Cùng vòng dò với `cacKyDenHan`/`kyKeTiep`: nhịp bám MỐC NEO, sàn là lần
    // chạy gần nhất. Không mốc neo thì nhịp rơi vào chính mốc chạy — hành vi
    // của bản trước, giữ cho mục tiêu bật trước khi có ô chọn ấy.
    final san = g.autoDepositLastRun!;
    final chuKy = g.cycleTakeMoney;
    final goc = g.timeCycleTakeMoney ?? san;
    var n = g.timeCycleTakeMoney == null ? 1 : 0;
    var moc = mocThuN(goc, chuKy, n);
    var soVong = 0;
    var rac = false;
    while (!moc.isAfter(san)) {
      if (++soVong > _tranDoMoc) {
        rac = true;
        break;
      }
      moc = mocThuN(goc, chuKy, ++n);
    }
    if (rac) continue;

    var conThieu = g.remainingAmount;
    var daThem = 0;
    while (moc.isBefore(sauCuoi) && daThem < _tranKyChieu) {
      // Kẹp ở phần còn thiếu, giảm dần qua từng kỳ chiếu — cùng luật
      // `quyetDinhTrich`. Ví nguồn truyền vô cực: dự báo không đoán ví có đủ
      // hay không, đó là việc của `_viThieu`.
      final qd = quyetDinhTrich(
        soTienCai: g.autoDepositAmount!,
        conThieu: conThieu,
        soDuViNguon: double.infinity,
      );
      if (qd.soTien <= 0) break;
      // Kỳ đã tới hạn mà chưa trích → lượt quét kế tiếp sẽ trừ → dồn về hôm
      // nay, cùng cách xử lý hoá đơn quá hạn.
      final ngay = !moc.isAfter(now) ? homNay : _dauNgay(moc);
      ra.add(CamKet(
        ngay: ngay,
        ten: g.name,
        loai: LoaiCamKet.trichTuDong,
        walletId: nguonId,
        viNhanId: g.walletId,
        tenVi: nguon.name,
        soTien: qd.soTien,
        categoryId: null,
        quaHan: false,
        laKyChieu: true,
        // Trừ nguồn nếu nguồn tính vào tổng, CỘNG đích nếu đích tính vào
        // tổng. Đích `null` (chưa gán ví) → coi như không tính → trừ thật.
        tacDongTong: (tinhVaoTong(nguonId) ? -qd.soTien : 0) +
            (tinhVaoTong(g.walletId) ? qd.soTien : 0),
      ));
      conThieu -= qd.soTien;
      daThem++;
      moc = mocThuN(goc, chuKy, ++n);
    }
  }
  return ra;
}

// ── Ngân sách ─────────────────────────────────────────────────────────────

/// Tầng 2: phần còn lại của ngân sách KỲ HIỆN TẠI, quy về tiêu đều.
///
/// - Chỉ ngân sách chưa hết hạn và kỳ hiện tại **chứa** [now].
/// - Có ngân sách TỔNG đang chạy → chỉ nó. Cộng cả tổng lẫn danh mục là đếm
///   đôi chính tiền của mình: ngân sách tổng đã bao trùm mọi danh mục.
/// - Mỗi ngân sách đóng góp `suggestedPerDay × min(daysLeft, 30)` của
///   `budgetPaceOf` — tức `remaining × min(1, 30/daysLeft)`. Ngân sách quý
///   còn 60 ngày chỉ tính nửa phần còn lại, vì tầm nhìn chỉ 30 ngày.
/// - **Trừ hoá đơn tầng 1 cùng danh mục** (ngân sách tổng trừ mọi hoá đơn)
///   nằm trong kỳ ấy, kẹp ≥ 0. Không trừ là ĐẾM ĐÔI (bẫy 4): tiền điện 800k
///   vừa nằm ở tầng 1 vừa nằm trong "còn lại" của ngân sách Điện nước.
/// - Trích tự động là `transfer`, **không** chạm ngân sách.
double _nganSachConLai(
  List<BudgetView> nganSach, {
  required DateTime now,
  required DateTime homNay,
  required DateTime cuoi,
  required List<CamKet> camKet,
}) {
  final sauCuoi = DateTime(cuoi.year, cuoi.month, cuoi.day + 1);

  final dangChay = <BudgetEntity>[];
  for (final v in nganSach) {
    final b = v.budget;
    if (b.isDeleted || b.isExpired(now)) continue;
    final ky = b.currentPeriod(now);
    if (now.isBefore(ky.from) || !now.isBefore(ky.to)) continue;
    dangChay.add(b);
  }
  final tong = [
    for (final b in dangChay)
      if (b.categoryId == null) b
  ];
  final chon = tong.isNotEmpty ? tong : dangChay;

  var ra = 0.0;
  for (final b in chon) {
    final pace = budgetPaceOf(b, now);
    if (pace.daysLeft <= 0) continue;
    final soNgay =
        pace.daysLeft < kSoNgayDuBao ? pace.daysLeft : kSoNgayDuBao;
    final duKien = pace.suggestedPerDay * soNgay;

    final ky = b.currentPeriod(now);
    final bien = ky.to.isBefore(sauCuoi) ? ky.to : sauCuoi;
    var truHoaDon = 0.0;
    for (final c in camKet) {
      if (c.loai != LoaiCamKet.hoaDon || !c.ngay.isBefore(bien)) continue;
      if (b.categoryId != null && c.categoryId != b.categoryId) continue;
      truHoaDon += c.soTien;
    }
    final dongGop = duKien - truHoaDon;
    if (dongGop > 0) ra += dongGop;
  }
  return ra;
}

// ── Ví thiếu ──────────────────────────────────────────────────────────────

/// Ngày đầu tiên một ví HOẠT ĐỘNG xuống dưới 0 khi trừ dần cam kết của nó.
///
/// Trừ `soTien` đủ (không phải `tacDongTong`): theo ví thì tiền rời ví là
/// thật dù tổng không đổi. Khoản trích cộng vào ví nhận. Cùng ngày thì trừ
/// TRƯỚC cộng sau — bảo thủ, thà báo thừa một ngày còn hơn giấu.
List<ViThieu> _viThieu(List<CamKet> camKet, Map<String, Wallet> viTheoId) {
  final bienDong = <String, List<(DateTime, double)>>{};
  void ghi(String viId, DateTime ngay, double delta) =>
      bienDong.putIfAbsent(viId, () => []).add((ngay, delta));
  for (final c in camKet) {
    ghi(c.walletId, c.ngay, -c.soTien);
    final nhan = c.viNhanId;
    if (nhan != null) ghi(nhan, c.ngay, c.soTien);
  }

  final ra = <ViThieu>[];
  for (final e in bienDong.entries) {
    final v = viTheoId[e.key];
    // Ví lưu trữ: người dùng đã cất đi, báo thiếu là ồn vô ích (bẫy 9).
    if (v == null || v.isDeleted || !WalletStatus.laHoatDong(v.status)) {
      continue;
    }
    final ds = e.value
      ..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2); // âm (trừ) đứng trước
      });
    var conLai = v.balance;
    var thieuNhat = 0.0;
    DateTime? ngayDau;
    for (final (ngay, delta) in ds) {
      conLai += delta;
      // Ngưỡng nửa đồng cho đuôi lẻ của double — cùng luật đối soát số dư.
      if (conLai < -0.5) {
        ngayDau ??= ngay;
        if (-conLai > thieuNhat) thieuNhat = -conLai;
      }
    }
    if (ngayDau != null) {
      ra.add(ViThieu(
          walletId: v.id, ten: v.name, thieu: thieuNhat, ngay: ngayDau));
    }
  }
  ra.sort((a, b) => a.ngay.compareTo(b.ngay));
  return ra;
}

// ── Dải trục tung ─────────────────────────────────────────────────────────

/// Sàn và bước của trục tung biểu đồ dự báo; trần là `san + 3 × buoc`.
///
/// ## Vì sao trục CO theo dữ liệu, không chạy từ 0
///
/// Khác thác nước và hai biểu đồ vay/nợ — ở đó mắt **so độ cao giữa các cột**
/// nên trục buộc phải từ 0, và người dùng đã chốt đúng điều ấy ngày
/// 2026-09-15. Đường số dư thì không so độ cao; nó cho thấy **hình dạng thay
/// đổi**, tức các bậc rơi vào ngày nào và sâu bao nhiêu.
///
/// Đo trên máy ảo 2026-09-16: số dư 13.590.000, cả 30 ngày chỉ trừ 388.000
/// (2,8%) — trục từ 0 cho ra một đường nằm phẳng sát đỉnh, không thấy bậc
/// nào. Người dùng chốt co trục cùng ngày. Nhãn trục vẫn in số thật nên
/// không ai đọc nhầm thành "về 0"; đây cũng là quy ước PocketSmith và Monarch
/// dùng cho đường số dư.
///
/// ## ⚠️ Vì sao phải nới dải
///
/// `rutGon` chỉ giữ **một chữ số lẻ**, nên một dải hẹp so với độ lớn con số
/// làm cả bốn nhãn in ra cùng một chuỗi: cam kết 50.000 trên nền 13.590.000
/// cho bước 21.667 và bốn nhãn đều là `13.6M`. Đó đúng là họ **G39** (hai
/// nhãn đè nhau ở khối Xu hướng), chỉ khác nguyên nhân. Ở đây dải được nới
/// dần cho tới khi bốn nhãn **đôi một khác nhau** — kiểm bằng chính `rutGon`,
/// nên luật hiển thị và luật dựng dải không thể lệch nhau.
({double san, double buoc}) daiTrucDuBao(List<double> giaTri) {
  if (giaTri.isEmpty) return (san: 0, buoc: 1);

  var dinh = giaTri.first;
  var day = giaTri.first;
  for (final y in giaTri) {
    if (y > dinh) dinh = y;
    if (y < day) day = y;
  }

  // Mọi điểm bằng nhau (không cam kết nào): dựng một dải quanh giá trị ấy
  // thay vì chia cho 0.
  var dai = dinh - day;
  if (dai <= 0) dai = dinh.abs() * 0.02;
  if (dai <= 0) dai = 1;

  // Bước phải **≥ dải/2**: sàn bị kéo xuống bội gần nhất của bước nên khoảng
  // phải phủ được `dải + bước`, tức `3 × bước ≥ dải + bước`.
  var buoc = _buocTron(dai / 2);
  var san = (day / buoc).floorToDouble() * buoc;

  // Nới cho tới khi bốn nhãn khác nhau — `rutGon` chỉ giữ một chữ số lẻ. Trần
  // 30 vòng: một vòng `while` không trần trong hàm được widget gọi là cách
  // treo app mà không để lại dòng log nào.
  for (var i = 0; i < 30; i++) {
    final nhan = <String>{
      for (var k = 0; k < 4; k++) rutGon(san + buoc * k),
    };
    if (nhan.length == 4) break;
    buoc = _buocTron(buoc * 1.5);
    san = (day / buoc).floorToDouble() * buoc;
  }

  return (san: san, buoc: buoc);
}

/// Số "tròn" nhỏ nhất **không nhỏ hơn** [x], lấy trong họ 1 · 2 · 2,5 · 5
/// nhân luỹ thừa của 10.
///
/// ⚠️ Vì sao bước phải tròn, chứ không phải `dải / 3` cho gọn: fl_chart vẽ
/// nhãn ở **cả hai biên** cộng các mốc theo `interval`, và với bước lẻ thì
/// biên trên lệch mốc cuối vài phần tỉ — hai nhãn cùng nội dung in đè khít
/// lên nhau. Đo được trên máy ảo 2026-09-16: bước 168.333 cho ra "13.6M" hai
/// lần ở đỉnh trục. Cùng họ bẫy **4.18 / G39**; bước tròn làm mọi mốc rơi
/// đúng vị trí và phép cộng không sinh sai số.
double _buocTron(double x) {
  if (x <= 0) return 1;
  var bac = 1.0;
  while (bac * 10 <= x) {
    bac *= 10;
  }
  while (bac > x) {
    bac /= 10;
  }
  for (final he in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    final ung = bac * he;
    if (ung >= x) return ung;
  }
  return bac * 10;
}

// ── Chuỗi 31 điểm ─────────────────────────────────────────────────────────

/// Bậc thang tầng 1 và đường "theo ngân sách". Công khai để widget test dựng
/// dữ liệu đúng cấu trúc thay vì tự bịa 31 điểm.
List<DiemDuBao> chuoiDuBao({
  required DateTime homNay,
  required double soDu,
  required List<CamKet> camKet,
  required double nganSachConLai,
}) =>
    [
      for (var i = 0; i <= kSoNgayDuBao; i++)
        () {
          final ngay = DateTime(homNay.year, homNay.month, homNay.day + i);
          var chac = soDu;
          for (final c in camKet) {
            // `!isAfter`: cam kết HÔM NAY phải nằm ở điểm 0 (bẫy 7).
            if (!c.ngay.isAfter(ngay)) chac += c.tacDongTong;
          }
          return DiemDuBao(
            ngay: ngay,
            chacChan: chac,
            theoNganSach: chac - nganSachConLai * i / kSoNgayDuBao,
          );
        }(),
    ];
