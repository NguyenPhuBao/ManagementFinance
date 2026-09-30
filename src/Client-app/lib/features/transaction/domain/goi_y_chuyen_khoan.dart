/// Gợi ý Chuyển khoản từ một hàng biến động số dư (spec `2026-09-30-goi-y-chuyen-khoan-bien-dong-design.md`). Hàm thuần.
///
/// Hai luật: **cặp** (hàng khác chiều, cùng tiền, ≤ 5 phút, nguồn khác — cả hai phía đều đăng tin) và **nội dung**
/// (tin nhắc đúng một nguồn khác — MoMo không bắn tin nào ở cả hai chiều khi chuyển với MB, đo Realme 2026-09-30).
library;

import '../../../core/category/category_name.dart';
import 'dien_san_bien_dong.dart';
import 'doc_tin_bien_dong.dart';

class GoiYChuyenKhoan {
  const GoiYChuyenKhoan({required this.nguonTu, this.duoiTu, required this.nguonDen, this.duoiDen, this.khoaCap});

  /// Nguồn tiền ĐI và đuôi TK của nó (`null` = tin không mang số TK phía ấy).
  final String nguonTu;
  final String? duoiTu;

  /// Nguồn tiền ĐẾN.
  final String nguonDen;
  final String? duoiDen;

  /// `dedupeKey` của hàng đi cặp (luật cặp) — Lưu phải xoá cả nó. `null` = luật nội dung.
  final String? khoaCap;
}

const Duration kCuaSoCapChuyenKhoan = Duration(minutes: 5);

/// Từ nhận ra mỗi nguồn trong nội dung tin — chữ thường, không dấu. ⚠️ Không `mb` trần: quá ngắn, trùng mã GD.
/// *Tin nhắn (SMS)* không có từ nhận ra.
const Map<String, List<String>> kTuNhanNguon = {
  kNguonMomo: ['momo'],
  kNguonZalopay: ['zalopay', 'zalo pay'],
  kNguonMb: ['mb bank', 'mbbank'],
  kNguonVcb: ['vietcombank', 'vcb'],
  kNguonTcb: ['techcombank', 'tcb'],
  kNguonBidv: ['bidv'],
};

final RegExp _chuCai = RegExp('[a-z]');

/// `tu` đứng trọn từ trong `chu` — biên là chỗ chuyển giữa chữ cái và không-chữ-cái, nên `MOMO149…` có `momo` còn
/// `momoney` thì không.
bool _coTu(String chu, String tu) {
  for (var i = chu.indexOf(tu); i >= 0; i = chu.indexOf(tu, i + 1)) {
    final truoc = i == 0 ? '' : chu[i - 1];
    final j = i + tu.length;
    final sau = j >= chu.length ? '' : chu[j];
    if (!_chuCai.hasMatch(truoc) && !_chuCai.hasMatch(sau)) return true;
  }
  return false;
}

/// Nguồn KHÁC [nguonCuaTin] mà [noiDung] nhắc tới — đúng một, không thì `null`.
String? nguonNhacTrongTin(String noiDung, {required String nguonCuaTin}) {
  final chu = removeVietnameseTones(noiDung).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final nhac = {
    for (final e in kTuNhanNguon.entries)
      if (e.key != nguonCuaTin && e.value.any((t) => _coTu(chu, t))) e.key,
  };
  return nhac.length == 1 ? nhac.single : null;
}

/// [dangCho]: mọi hàng biến động chưa gạt của tài khoản (có thể gồm cả [d]). `null` = không gợi ý.
GoiYChuyenKhoan? goiYChuyenKhoan(DienSanBienDong d, List<DienSanBienDong> dangCho) {
  final tien = d.soTien;
  final chieu = d.chieu;
  if (tien == null || chieu == null) return null;

  final luc = d.thoiGian;
  if (luc != null) {
    DienSanBienDong? tot;
    Duration? lech;
    var hoa = false;
    for (final p in dangCho) {
      final pl = p.thoiGian;
      final pt = p.soTien;
      if (p.khoa == d.khoa || p.nguon == d.nguon || pl == null || pt == null) continue;
      if (p.chieu == null || p.chieu == chieu || (pt - tien).abs() >= 0.5) continue;
      final l = pl.difference(luc).abs();
      if (l > kCuaSoCapChuyenKhoan) continue;
      if (lech == null || l < lech) {
        tot = p;
        lech = l;
        hoa = false;
      } else if (l == lech) {
        hoa = true;
      }
    }
    if (tot != null) {
      // Gợi ý sai ví tệ hơn không gợi ý — mơ hồ thì im, không rơi sang luật nội dung.
      if (hoa) return null;
      final (di, den) = chieu == 'chi' ? (d, tot) : (tot, d);
      return GoiYChuyenKhoan(
          nguonTu: di.nguon, duoiTu: di.duoi, nguonDen: den.nguon, duoiDen: den.duoi, khoaCap: tot.khoa);
    }
  }

  final kia = nguonNhacTrongTin(d.ghiChu, nguonCuaTin: d.nguon);
  if (kia == null) return null;
  return chieu == 'thu'
      ? GoiYChuyenKhoan(nguonTu: kia, nguonDen: d.nguon, duoiDen: d.duoi)
      : GoiYChuyenKhoan(nguonTu: d.nguon, duoiTu: d.duoi, nguonDen: kia);
}

/// Ví **duy nhất** có tên chứa tên nguồn (*"Ví MoMo"* ⊃ *MoMo*) — so `normalizeCategoryName` bỏ khoảng trắng, KHÔNG
/// bỏ dấu (quy tắc 7). Hai ví khớp hoặc không ví nào → `null` (không đoán). [vi] phải là ví HOẠT ĐỘNG.
String? viTheoTenNguon(String nguon, Iterable<({String id, String ten})> vi) {
  String gon(String s) => normalizeCategoryName(s).replaceAll(' ', '');
  final khoa = gon(nguon);
  final khop = [for (final v in vi) if (gon(v.ten).contains(khoa)) v.id];
  return khop.length == 1 ? khop.single : null;
}
