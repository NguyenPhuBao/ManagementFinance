/// Học giờ và tần suất thông báo từ nhật ký B5a — **chỉ đề xuất** (B5b).
///
/// Spec `docs/superpowers/specs/2026-09-28-b5b-hoc-gio-thong-bao-design.md`.
/// Hàm thuần: nhận nhật ký, thông báo, mốc ghi giao dịch và tuỳ chọn, trả danh
/// sách đề xuất. Đổi giờ hay tắt nhóm là quyết định của người dùng (tầng hậu
/// quả 2) — không gì ở đây ghi tuỳ chọn.
///
/// Ba chỗ spec gốc chưa lường, chốt lúc thi công (2026-09-29):
/// - **"Tới máy" của lịch đặt trước đếm theo khoá**: `dat_lich` mang `luc` =
///   giờ NỔ, `huy_lich` mang `luc` = lúc HUỶ (luôn sớm hơn), nên so "huỷ SAU
///   đặt" theo `luc` không bao giờ khớp. Khoá K tới máy ⇔ số `dat_lich` đã qua
///   của K lớn hơn số `huy_lich` của K; mốc = `dat_lich` đã qua sớm nhất.
///   Người dùng chọn.
/// - **Loại luôn báo không đếm vào nhóm bị lờ** — công tắc nhóm không tắt được
///   chúng, đề xuất "tắt nhóm" vì chúng là hứa một điều không làm được.
/// - **Chỉ đề xuất giờ cho lời nhắc đang bật**, và chỉ xét những lượt tới máy
///   đã hết cửa 48 giờ theo dõi.
library;

import '../database/app_database.dart';
import 'nhom_tu_khoa.dart';
import 'prefs/notification_prefs.dart';
import 'su_kien_thong_bao.dart';

enum LoaiDeXuat { gioHoaDon, gioTongKet, gioGhiChep, tatNhom }

class DeXuatThongBao {
  final LoaiDeXuat loai;

  /// Chỉ [LoaiDeXuat.tatNhom].
  final NotificationGroup? nhom;

  /// Giờ đề xuất. Với [LoaiDeXuat.gioTongKet] có thể `null` khi chỉ **thứ** lệch.
  final ({int gio, int phut})? gio;

  /// Chỉ [LoaiDeXuat.gioTongKet], khi thứ đề xuất khác thứ đang đặt.
  final int? thu;

  /// Số mẫu đã dùng: phản ứng, lần ghi, hay lượt tới máy.
  final int soMau;

  const DeXuatThongBao({
    required this.loai,
    this.nhom,
    this.gio,
    this.thu,
    required this.soMau,
  });

  /// Khoá của sự kiện `bo_qua_de_xuat`: `deXuat:gioHoaDon` · … ·
  /// `deXuat:tatNhom:budget`. Tổng kết tuần gộp thứ + giờ trong **một** khoá —
  /// một dòng, một nút Bỏ qua.
  String get khoa => loai == LoaiDeXuat.tatNhom
      ? 'deXuat:tatNhom:${nhom!.name}'
      : 'deXuat:${loai.name}';
}

const int kCuaDuLieu = 20;
const double kTyLeO = 0.35;
const int kLechToiThieuPhut = 60;
const int kSoLienTiep = 10;
const Duration kCuaSoPhanUng = Duration(hours: 48);
const Duration kImSauBoQua = Duration(days: 30);
const Duration kCuaSoHoc = Duration(days: 180);

const Set<String> _tichCuc = {
  SuKienThongBao.chamHdh,
  SuKienThongBao.nutTraNgay,
  SuKienThongBao.moTrongApp,
};

int _o(DateTime t) => (t.hour * 60 + t.minute) ~/ 30; // 0..47

/// Khoảng cách giữa hai mốc trong ngày, tính **vòng 24 giờ**: 23:30 và 00:30
/// cách nhau 60 phút, không phải 23 giờ.
int _khoangVong(int phutA, int phutB) {
  final d = (phutA - phutB).abs() % 1440;
  return d > 720 ? 1440 - d : d;
}

/// Ô 30 phút đông nhất, hoặc `null` nếu không đạt cửa. [dat] là mốc đang đặt
/// (phút trong ngày). Hai ô bằng nhau → ô gần [dat] hơn (ít xáo trộn hơn).
({int gio, int phut})? _oDongNhat(List<DateTime> moc, int dat) {
  if (moc.length < kCuaDuLieu) return null;
  final dem = <int, int>{};
  for (final t in moc) {
    dem.update(_o(t), (v) => v + 1, ifAbsent: () => 1);
  }
  final maxDem = dem.values.reduce((a, b) => a > b ? a : b);
  if (maxDem < kTyLeO * moc.length) return null;
  final ung = [for (final e in dem.entries) if (e.value == maxDem) e.key]
    ..sort((a, b) {
      final c = _khoangVong(a * 30, dat).compareTo(_khoangVong(b * 30, dat));
      return c != 0 ? c : a.compareTo(b);
    });
  final phut = ung.first * 30;
  if (_khoangVong(phut, dat) < kLechToiThieuPhut) return null;
  return (gio: phut ~/ 60, phut: phut % 60);
}

/// Thứ đông nhất (1–7), hoặc `null` nếu không đạt cửa hay trùng [dat].
int? _thuDongNhat(List<DateTime> moc, int dat) {
  if (moc.length < kCuaDuLieu) return null;
  final dem = <int, int>{};
  for (final t in moc) {
    dem.update(t.weekday, (v) => v + 1, ifAbsent: () => 1);
  }
  final maxDem = dem.values.reduce((a, b) => a > b ? a : b);
  if (maxDem < kTyLeO * moc.length) return null;
  int vong(int a) {
    final d = (a - dat).abs() % 7;
    return d > 3 ? 7 - d : d;
  }

  final ung = [for (final e in dem.entries) if (e.value == maxDem) e.key]
    ..sort((a, b) {
      final c = vong(a).compareTo(vong(b));
      return c != 0 ? c : a.compareTo(b);
    });
  return ung.first == dat ? null : ung.first;
}

List<DeXuatThongBao> deXuatThongBao({
  required List<AppNotificationEvent> nhatKy,
  required List<AppNotification> thongBao,
  required List<DateTime> mocGhiGiaoDich,
  required NotificationPrefs prefs,
  required bool coQuyen,
  required DateTime now,
}) {
  // Công tắc tổng tắt: không lời nhắc nào ra hệ điều hành — giờ nhắc vô nghĩa,
  // và không lượt nào có `osDeliveredAt` để xét nhóm bị lờ.
  if (!prefs.osBat) return const [];

  final tu = now.subtract(kCuaSoHoc);
  bool trongCuaSo(DateTime t) => !t.isBefore(tu) && !t.isAfter(now);

  final dangIm = {
    for (final e in nhatKy)
      if (e.suKien == SuKienThongBao.boQuaDeXuat &&
          !e.luc.isBefore(now.subtract(kImSauBoQua)) &&
          !e.luc.isAfter(now))
        e.dedupeKey,
  };

  final tichCuc = [
    for (final e in nhatKy)
      if (_tichCuc.contains(e.suKien) && trongCuaSo(e.luc)) e,
  ];
  List<DateTime> phanUngCua(NotificationGroup g) => [
        for (final e in tichCuc)
          if (nhomTuKhoa(e.dedupeKey) == g) e.luc,
      ];

  final ra = <DeXuatThongBao>[];

  // ── 2.1 Giờ nhắc hoá đơn ───────────────────────────────────────────────
  if (prefs.batNhom(NotificationGroup.bill)) {
    final moc = phanUngCua(NotificationGroup.bill);
    final g = _oDongNhat(moc, prefs.gioNhac * 60 + prefs.phutNhac);
    if (g != null) {
      ra.add(DeXuatThongBao(loai: LoaiDeXuat.gioHoaDon, gio: g, soMau: moc.length));
    }
  }

  // ── 2.2 Giờ (và thứ) tổng kết tuần ─────────────────────────────────────
  if (prefs.tongKetTuanBat && prefs.batNhom(NotificationGroup.summary)) {
    final moc = phanUngCua(NotificationGroup.summary);
    final g = _oDongNhat(moc, prefs.gioTongKet * 60 + prefs.phutTongKet);
    final thu = _thuDongNhat(moc, prefs.thuTongKet);
    if (g != null || thu != null) {
      ra.add(DeXuatThongBao(
          loai: LoaiDeXuat.gioTongKet, gio: g, thu: thu, soMau: moc.length));
    }
  }

  // ── 2.3 Giờ nhắc ghi chép ──────────────────────────────────────────────
  if (prefs.nhacGhiChepBat) {
    final moc = [for (final t in mocGhiGiaoDich) if (trongCuaSo(t)) t];
    final g = _oDongNhat(moc, prefs.gioNhacGhiChep * 60 + prefs.phutNhacGhiChep);
    if (g != null) {
      ra.add(DeXuatThongBao(loai: LoaiDeXuat.gioGhiChep, gio: g, soMau: moc.length));
    }
  }

  // ── 2.4 Nhóm bị lờ ─────────────────────────────────────────────────────
  // Quyền tắt thì "tới máy" có thể không có thật (giới hạn B5a) — không đề
  // xuất tắt nhóm.
  if (coQuyen) {
    // Mốc tới máy theo khoá; sớm nhất thắng.
    final toiMay = <String, DateTime>{};
    void ghiNhan(String khoa, DateTime moc) {
      final cu = toiMay[khoa];
      if (cu == null || moc.isBefore(cu)) toiMay[khoa] = moc;
    }

    for (final n in thongBao) {
      final d = n.osDeliveredAt;
      if (d != null && trongCuaSo(d)) ghiNhan(n.dedupeKey, d);
    }

    final datQua = <String, List<DateTime>>{};
    final soHuy = <String, int>{};
    for (final e in nhatKy) {
      if (e.suKien == SuKienThongBao.datLich && trongCuaSo(e.luc)) {
        (datQua[e.dedupeKey] ??= []).add(e.luc);
      } else if (e.suKien == SuKienThongBao.huyLich && !e.luc.isBefore(tu)) {
        soHuy.update(e.dedupeKey, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    datQua.forEach((khoa, ds) {
      if (ds.length > (soHuy[khoa] ?? 0)) {
        ghiNhan(khoa, ds.reduce((a, b) => a.isBefore(b) ? a : b));
      }
    });

    // Chỉ lượt đã hết cửa theo dõi 48 giờ — lượt mới hơn chưa biết có mở không.
    final hetCua = now.subtract(kCuaSoPhanUng);
    final theoNhom = <NotificationGroup, List<({String khoa, DateTime moc})>>{};
    toiMay.forEach((khoa, moc) {
      if (moc.isAfter(hetCua)) return;
      final loai = loaiTuKhoa(khoa);
      if (loai == null || luonBao(loai)) return;
      (theoNhom[nhomCua(loai)] ??= []).add((khoa: khoa, moc: moc));
    });

    for (final g in NotificationGroup.values) {
      if (!prefs.batNhom(g)) continue;
      final ds = theoNhom[g];
      if (ds == null || ds.length < kCuaDuLieu) continue;
      ds.sort((a, b) => b.moc.compareTo(a.moc));
      final coPhanUng = ds.take(kSoLienTiep).any((t) => tichCuc.any((e) =>
          e.dedupeKey == t.khoa &&
          !e.luc.isBefore(t.moc) &&
          !e.luc.isAfter(t.moc.add(kCuaSoPhanUng))));
      if (!coPhanUng) {
        ra.add(DeXuatThongBao(loai: LoaiDeXuat.tatNhom, nhom: g, soMau: ds.length));
      }
    }
  }

  return [for (final d in ra) if (!dangIm.contains(d.khoa)) d];
}
