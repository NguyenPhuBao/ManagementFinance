/// B1 — gợi ý danh mục học từ ghi chú (spec `2026-09-28-goi-y-danh-muc-hoc-tu-ghi-chu-design.md`). Hàm thuần:
/// không Drift, không Flutter, không đồng hồ.
///
/// Naive Bayes đa thức NHỊ PHÂN HOÁ: đếm theo số ghi chú chứa âm tiết (một ghi chú "cafe cafe" không phải hai lần
/// bằng chứng), làm trơn Laplace. Xác suất tính trên MỌI danh mục đã học; `hopLe` chỉ lọc ứng viên — tính trên phần
/// còn lại là đẩy danh mục duy nhất còn sống lên 100 % cho một ghi chú chẳng liên quan.
///
/// Đặt ở `category/domain/`, không ở `ai_edge/`: nó đọc sổ giao dịch, thứ test quét 14 cấm trong `ai_edge/`. Bỏ
/// dấu (`removeVietnameseTones`) ở đây là đúng chỗ của nó — đây là GỢI Ý, không phải quy tắc trùng tên (quy tắc 7).
library;

import 'dart:math' as math;

import '../../../core/category/category_name.dart';
import '../../analytics/domain/khoan_vao_thong_ke.dart';
import '../../bill/domain/bill_note.dart';
import '../../goal/domain/goal_history_direction.dart';
import '../../transaction/domain/transaction_owner.dart';

/// Dưới mười mẫu có nhãn thì sổ còn quá mỏng để nói "bạn thường ghi …" — cùng lý lẽ `kToiThieuMauViHayDung`.
const int kToiThieuMauTong = 10;

/// Danh mục đứng đầu phải có ít nhất ba mẫu: hai lần trùng hợp chưa phải thói quen.
const int kToiThieuMauDanhMuc = 3;

/// Hậu nghiệm phải từ 0,6: dưới đó hai danh mục giành nhau và gợi ý là tung đồng xu — thẻ từ khoá (hoặc không thẻ)
/// tốt hơn một câu tự tin sai.
const double kNguongXacSuat = 0.6;

class MauGhiChu {
  final String categoryId;

  /// Âm tiết bỏ dấu, GIỮ THỨ TỰ, chưa khử trùng — câu lý do cần thứ tự; phép đếm tự khử trùng.
  final List<String> amTiet;
  final DateTime ngay;
  const MauGhiChu({required this.categoryId, required this.amTiet, required this.ngay});
}

final RegExp _ngoaiChu = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final RegExp _toanSo = RegExp(r'^\p{N}+$', unicode: true);

/// Âm tiết của một ghi chú: chuẩn hoá → bỏ dấu → tách ở mọi ký tự không phải chữ/số → bỏ âm tiết TOÀN chữ số
/// (*"9"*, *"2026"* bỏ; *"500k"* giữ vì có chữ).
List<String> amTietCua(String ghiChu) => removeVietnameseTones(normalizeCategoryName(ghiChu))
    .split(_ngoaiChu)
    .where((t) => t.isNotEmpty && !_toanSo.hasMatch(t))
    .toList();

/// Ghi chú do MÁY gắn chứ không phải người dùng gõ — học chúng là dạy mô hình rằng *"thanh toán hóa đơn"* là một
/// danh mục. Gom mọi nhận dạng ĐÃ CÓ, không viết lại chuỗi nào.
bool laGhiChuMay({required String loai, required String? categoryId, required String? ghiChu}) {
  if (!khoanVaoThongKe(loai: loai, categoryId: categoryId, ghiChu: ghiChu)) return true;
  final g = ghiChu ?? '';
  return g.startsWith(kGhiChuTraHoaDon) ||
      g.startsWith(kGhiChuNapMucTieu) ||
      g.startsWith(kGhiChuRutMucTieu) ||
      g.startsWith(kGhiChuNapMucTieuCu);
}

/// Mẫu có nhãn: giao dịch có danh mục, ghi chú người dùng gõ, còn ít nhất một âm tiết.
List<MauGhiChu> mauHocTu(
        Iterable<({String loai, String? categoryId, String? ghiChu, DateTime ngay})> giaoDich) =>
    [
      for (final t in giaoDich)
        if (t.categoryId != null &&
            !laGhiChuMay(loai: t.loai, categoryId: t.categoryId, ghiChu: t.ghiChu))
          if (amTietCua(t.ghiChu ?? '') case final a when a.isNotEmpty)
            MauGhiChu(categoryId: t.categoryId!, amTiet: a, ngay: t.ngay),
    ];

class DoanDanhMuc {
  final String categoryId;
  final double xacSuat;

  /// Cụm âm tiết (bỏ dấu, cách nhau một dấu cách) làm lý do — cũng là khoá của luật thôi gợi ý.
  final String cumBoDau;

  /// Số mẫu của danh mục đoán chứa cụm.
  final int soLanCung;

  /// Số mẫu (mọi danh mục) chứa cụm.
  final int soLanTong;
  const DoanDanhMuc({
    required this.categoryId,
    required this.xacSuat,
    required this.cumBoDau,
    required this.soLanCung,
    required this.soLanTong,
  });
}

class BoPhanLoaiGhiChu {
  BoPhanLoaiGhiChu._(this._mau, this._n, this._nt, this._s, this._v);

  factory BoPhanLoaiGhiChu.hoc(List<MauGhiChu> mau) {
    final n = <String, int>{};
    final nt = <String, Map<String, int>>{};
    final s = <String, int>{};
    final v = <String>{};
    for (final x in mau) {
      n[x.categoryId] = (n[x.categoryId] ?? 0) + 1;
      final dem = nt.putIfAbsent(x.categoryId, () => {});
      for (final t in x.amTiet.toSet()) {
        dem[t] = (dem[t] ?? 0) + 1;
        s[x.categoryId] = (s[x.categoryId] ?? 0) + 1;
        v.add(t);
      }
    }
    return BoPhanLoaiGhiChu._(mau, n, nt, s, v);
  }

  final List<MauGhiChu> _mau;

  /// N(c) — số mẫu của danh mục.
  final Map<String, int> _n;

  /// N(t, c) — số mẫu của c chứa âm tiết t.
  final Map<String, Map<String, int>> _nt;

  /// S(c) = Σ_t N(t, c).
  final Map<String, int> _s;

  /// Từ vựng.
  final Set<String> _v;

  int get soMau => _mau.length;

  /// `null` = chưa đủ để nói (spec 3.1): sổ mỏng, không âm tiết nào đã gặp, danh mục đầu ít mẫu, hậu nghiệm thấp,
  /// hoà ở đỉnh, danh mục đoán không có bằng chứng nào trong ghi chú, hoặc cặp (cụm, danh mục) đang bị thôi gợi ý.
  DoanDanhMuc? doan(String ghiChu, {required Set<String> hopLe, Set<(String, String)> tatCap = const {}}) {
    if (_mau.length < kToiThieuMauTong) return null;
    final q = amTietCua(ghiChu).toSet().where(_v.contains).toList();
    if (q.isEmpty) return null;
    final diem = <String, double>{
      for (final c in _n.keys)
        c: math.log(_n[c]! / _mau.length) +
            q.fold(0.0, (a, t) => a + math.log(((_nt[c]![t] ?? 0) + 1) / (_s[c]! + _v.length))),
    };
    final lon = diem.values.reduce(math.max);
    final tong = diem.values.fold(0.0, (a, d) => a + math.exp(d - lon));
    final ungVien = [for (final c in diem.keys) if (hopLe.contains(c)) c]
      ..sort((a, b) => diem[b]!.compareTo(diem[a]!));
    if (ungVien.isEmpty) return null;
    final c = ungVien.first;
    // Hoà ở đỉnh: hiện là chốt DƯ — hai danh mục hoà thì mỗi bên ≤ 0,5 < kNguongXacSuat. Giữ để ngưỡng có hạ
    // xuống ≤ 0,5 thì cũng không đoán bừa một trong hai (bản sai bỏ dòng này hôm nay không ca nào đỏ được).
    if (ungVien.length > 1 && diem[ungVien[1]] == diem[c]) return null;
    final p = math.exp(diem[c]! - lon) / tong;
    if (p < kNguongXacSuat || _n[c]! < kToiThieuMauDanhMuc) return null;
    // Chốt BẰNG CHỨNG: danh mục đoán phải từng gặp ít nhất một âm tiết của ghi chú.
    if (!q.any((t) => (_nt[c]![t] ?? 0) > 0)) return null;
    final cum = _cumLyDo(amTietCua(ghiChu), c);
    if (tatCap.contains((cum.cum, c))) return null;
    return DoanDanhMuc(categoryId: c, xacSuat: p, cumBoDau: cum.cum, soLanCung: cum.cung, soLanTong: cum.tong);
  }

  /// Âm tiết chính = N(t,c)/N(t) lớn nhất trong ghi chú (hoà: dài hơn, rồi xuất hiện trước), mở rộng sang hai bên
  /// CHỪNG NÀO số ghi chú của c chứa cụm còn bằng số của âm tiết chính — *"cà phê"* chứ không *"phê"*.
  ({String cum, int cung, int tong}) _cumLyDo(List<String> q, String c) {
    int demCum(List<String> cum, {String? chi}) => _mau
        .where((x) => (chi == null || x.categoryId == chi) && _chuaLienTiep(x.amTiet, cum))
        .length;
    var bd = -1;
    var tot = -1.0;
    for (var i = 0; i < q.length; i++) {
      final nt = _nt[c]![q[i]] ?? 0;
      if (nt == 0) continue;
      final tongT = _nt.values.fold<int>(0, (a, m) => a + (m[q[i]] ?? 0));
      final r = nt / tongT;
      if (r > tot || (r == tot && q[i].length > q[bd].length)) {
        tot = r;
        bd = i;
      }
    }
    var kt = bd + 1;
    final goc = demCum(q.sublist(bd, kt), chi: c);
    while (bd > 0 && demCum(q.sublist(bd - 1, kt), chi: c) == goc) {
      bd--;
    }
    while (kt < q.length && demCum(q.sublist(bd, kt + 1), chi: c) == goc) {
      kt++;
    }
    final cum = q.sublist(bd, kt);
    return (cum: cum.join(' '), cung: goc, tong: demCum(cum));
  }
}

/// [a] chứa [cum] như một đoạn LIỀN NHAU — dùng chung cho cụm lý do và luật mở lại gợi ý.
bool _chuaLienTiep(List<String> a, List<String> cum) {
  for (var i = 0; i + cum.length <= a.length; i++) {
    var khop = true;
    for (var j = 0; j < cum.length; j++) {
      if (a[i + j] != cum[j]) {
        khop = false;
        break;
      }
    }
    if (khop) return true;
  }
  return false;
}

/// ⚠️ In DẠNG NGƯỜI DÙNG ĐÃ GÕ: tìm đoạn âm tiết có dấu trong [ghiChuGoc] khớp cụm bỏ dấu — in *"ca phe"* khi họ gõ
/// *"cà phê"* trông như máy lỗi.
String cauLyDoHoc(DoanDanhMuc d, {required String ghiChuGoc, required String tenDanhMuc}) {
  final goc = ghiChuGoc.split(_ngoaiChu).where((t) => t.isNotEmpty).toList();
  final bo = [for (final t in goc) removeVietnameseTones(normalizeCategoryName(t))];
  final cum = d.cumBoDau.split(' ');
  var hien = d.cumBoDau;
  for (var i = 0; i + cum.length <= bo.length; i++) {
    if (List.generate(cum.length, (j) => bo[i + j] == cum[j]).every((x) => x)) {
      hien = goc.sublist(i, i + cum.length).join(' ');
      break;
    }
  }
  return 'Bạn thường ghi “$hien” cho $tenDanhMuc (${d.soLanCung}/${d.soLanTong} lần).';
}

/// Câu lý do của nguồn TỪ KHOÁ — giữ nguyên câu thẻ gợi ý in từ trước B1.
String cauLyDoTuKhoa(String tuKhoa) => 'Khớp với “$tuKhoa” trong ghi chú.';
