/// Thứ tự cụm khối trang Phân tích theo thói quen xem — dự án C việc ba.
/// Spec `docs/superpowers/specs/2026-10-05-du-an-c-thu-tu-khoi-phan-tich-design.md`.
///
/// Dart thuần: không Flutter, không Drift. Học = **đếm**, không mô hình:
/// mỗi ngày một cụm "xem lâu nhất", đề xuất khi một cụm thắng đủ nhiều ngày.
///
/// ⚠️ Mã lưu (`ma`) là chuỗi cố định — **không** lưu `index`: thêm cụm về sau
/// không được làm lệch hàng cũ.
library;

import 'dart:math' as math;

enum CumKhoi {
  dongTien('dong_tien', 'Dòng tiền'),
  tong('tong', 'Tổng thu chi'),
  duBao('du_bao', 'Dự báo 30 ngày'),
  xuHuong('xu_huong', 'Xu hướng'),
  chiTheoNgay('chi_theo_ngay', 'Chi theo ngày'),
  coCau('co_cau', 'Cơ cấu danh mục'),
  theoVi('theo_vi', 'Phân bổ theo ví'),
  topChi('top_chi', 'Top khoản chi'),
  vayNo('vay_no', 'Vay nợ');

  const CumKhoi(this.ma, this.ten);

  /// Mã lưu CSDL.
  final String ma;

  /// Tên hiện trên thẻ đề xuất.
  final String ten;
}

/// Thứ tự mặc định = thứ tự trang trước việc này (spec 2.1).
const List<CumKhoi> kThuTuCumMacDinh = CumKhoi.values;

/// Mã lạ (bản sau thêm cụm, rồi hạ bản) → `null`; người gọi **bỏ qua** hàng ấy.
CumKhoi? cumTuMa(String ma) {
  for (final c in CumKhoi.values) {
    if (c.ma == ma) return c;
  }
  return null;
}

const int kGiayToiThieuNgay = 10;
const int kNgayToiThieuDeXuat = 5;

/// 60 % viết dạng phần mười để so bằng số nguyên — 3/5 đúng ngưỡng.
const int kTiLeThangPhanMuoi = 6;
const int kCuaSoNgayDeXuat = 30;
const int kGiayImToiDa = 60;
const int kNgayGiuGiayXem = 90;
const int kNhipGhi = 15;

const String kThuTuDuaLen = 'dua_len';
const String kThuTuBoQua = 'bo_qua';
const String kThuTuVeMacDinh = 've_mac_dinh';

DateTime ngayCua(DateTime t) => DateTime(t.year, t.month, t.day);

String maNgay(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

DateTime? ngayTuMa(String s) {
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Đỉnh / đáy của một cụm, cùng hệ toạ độ với khung nhìn.
class KhungCum {
  const KhungCum(this.cum, this.dinh, this.day);
  final CumKhoi cum;
  final double dinh;
  final double day;
}

/// Cụm có phần giao với khung nhìn `[dinh, day]` **cao nhất**; hoà → cụm đứng
/// trên; không cụm nào giao (kể cả cụm cao 0 — khối tự ẩn) → `null`.
CumKhoi? cumDangXem(List<KhungCum> khung, double dinh, double day) {
  KhungCum? tot;
  var totGiao = 0.0;
  for (final k in khung) {
    final giao = math.min(k.day, day) - math.max(k.dinh, dinh);
    if (giao <= 0) continue;
    if (tot == null || giao > totGiao || (giao == totGiao && k.dinh < tot.dinh)) {
      tot = k;
      totGiao = giao;
    }
  }
  return tot?.cum;
}

class PhanHoiThuTu {
  const PhanHoiThuTu({required this.ketQua, this.cum, required this.luc});

  /// [kThuTuDuaLen] · [kThuTuBoQua] · [kThuTuVeMacDinh].
  final String ketQua;

  /// `null` với [kThuTuVeMacDinh].
  final CumKhoi? cum;
  final DateTime luc;
}

/// Thứ tự hiện tại — **suy** từ nhật ký phản hồi, không lưu riêng (spec 3.5).
List<CumKhoi> thuTuTu(List<PhanHoiThuTu> phanHoi) {
  final ds = [...phanHoi]..sort((a, b) => a.luc.compareTo(b.luc));
  var thuTu = [...kThuTuCumMacDinh];
  for (final p in ds) {
    if (p.ketQua == kThuTuVeMacDinh) {
      thuTu = [...kThuTuCumMacDinh];
    } else if (p.ketQua == kThuTuDuaLen && p.cum != null) {
      thuTu
        ..remove(p.cum)
        ..insert(0, p.cum!);
    }
  }
  return List.unmodifiable(thuTu);
}

class GiayXem {
  const GiayXem({required this.ngay, required this.cum, required this.giay});
  final DateTime ngay;
  final CumKhoi cum;
  final int giay;
}

/// Cụm nên đề xuất đưa lên đầu, hoặc `null` = *chưa đủ để nói* (spec 3.2–3.4).
CumKhoi? deXuatDuaLen({
  required List<GiayXem> giayXem,
  required List<PhanHoiThuTu> phanHoi,
  required List<CumKhoi> thuTu,
  required DateTime now,
}) {
  final homNay = ngayCua(now);
  final tu = DateTime(now.year, now.month, now.day - kCuaSoNgayDeXuat);

  final theoNgay = <DateTime, Map<CumKhoi, int>>{};
  for (final g in giayXem) {
    final n = ngayCua(g.ngay);
    if (n.isBefore(tu) || !n.isBefore(homNay) || g.giay <= 0) continue;
    final m = theoNgay.putIfAbsent(n, () => {});
    m[g.cum] = (m[g.cum] ?? 0) + g.giay;
  }

  final viTri = {for (var i = 0; i < thuTu.length; i++) thuTu[i]: i};
  int vt(CumKhoi c) => viTri[c] ?? thuTu.length + c.index;

  CumKhoi thangCua(Map<CumKhoi, int> m) {
    late CumKhoi tot;
    var totGiay = -1;
    for (final e in m.entries) {
      if (e.value > totGiay || (e.value == totGiay && vt(e.key) < vt(tot))) {
        tot = e.key;
        totGiay = e.value;
      }
    }
    return tot;
  }

  final ngayDuocTinh = <DateTime, Map<CumKhoi, int>>{
    for (final e in theoNgay.entries)
      if (e.value.values.fold<int>(0, (a, b) => a + b) >= kGiayToiThieuNgay) e.key: e.value,
  };

  // Mốc từ chối: Bỏ qua của riêng cụm, Về mặc định của mọi cụm (spec 3.4).
  DateTime? mocChung;
  final mocRieng = <CumKhoi, DateTime>{};
  for (final p in phanHoi) {
    final n = ngayCua(p.luc);
    if (p.ketQua == kThuTuVeMacDinh) {
      if (mocChung == null || n.isAfter(mocChung)) mocChung = n;
    } else if (p.ketQua == kThuTuBoQua && p.cum != null) {
      final cu = mocRieng[p.cum!];
      if (cu == null || n.isAfter(cu)) mocRieng[p.cum!] = n;
    }
  }

  CumKhoi? chon;
  var chonThang = 0, chonSoNgay = 1;
  for (final x in thuTu) {
    final i = vt(x);
    if (i == 0) continue;
    var moc = mocRieng[x];
    if (mocChung != null && (moc == null || mocChung.isAfter(moc))) moc = mocChung;
    final ngay = [
      for (final e in ngayDuocTinh.entries)
        if (moc == null || e.key.isAfter(moc)) e.value,
    ];
    if (ngay.length < kNgayToiThieuDeXuat) continue;
    final thang = ngay.where((m) => thangCua(m) == x).length;
    if (thang * 10 < ngay.length * kTiLeThangPhanMuoi) continue;
    final truoc = thuTu.take(i).toSet();
    final coCumTruocDuocXem =
        ngay.any((m) => m.entries.any((g) => truoc.contains(g.key) && g.value > 0));
    if (!coCumTruocDuocXem) continue;
    // So thang/soNgay bằng nhân chéo; hoà → giữ cụm đứng trước (đã gặp trước).
    if (chon == null || thang * chonSoNgay > chonThang * ngay.length) {
      chon = x;
      chonThang = thang;
      chonSoNgay = ngay.length;
    }
  }
  return chon;
}
