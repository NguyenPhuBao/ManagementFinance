/// A5 mục 11.2b — đọc DANH SÁCH MÓN trên chữ OCR của một hoá đơn giấy (đã `ghepDongTheoHang`). Hàm thuần.
///
/// Người dùng tick món cho từng phần tách; app KHÔNG đoán danh mục món (việc của A5b, sau khi đo hoá đơn thật).
library;

import 'doc_hoa_don.dart';

/// Nhãn dừng đọc: nhãn tổng TRỪ ba nhãn hay là tiêu đề cột / nhãn từng món, CỘNG tạm tính.
///
/// ⚠️ So theo TỪ trọn (`\b…\b`), không chuỗi con như `docHoaDonTuChu`: ở đây khớp nhầm là DỪNG ĐỌC — tên món chứa
/// "tong" (vd "BANH TONGHOP") cắt cụt cả danh sách, im lặng. Ba nhãn bị trừ: dùng nguyên thì dòng tiêu đề cột
/// *"SL Đơn giá Thành tiền"* dừng đọc trước món đầu tiên.
final List<RegExp> kNhanDungMon = [
  for (final n in [
    for (final n in kNhanTongHoaDon)
      if (!const {'thanh tien', 'so tien', 'thanh toan'}.contains(n)) n,
    'tam tinh',
    'subtotal',
  ])
    RegExp('\\b$n\\b'),
];

/// Dòng bỏ qua khi đọc món: tiền khách đưa / thối lại… Giảm giá và chiết khấu KHÔNG bỏ — trong vùng món chúng là món
/// mang số âm.
final List<String> _nhanBoMon = [
  for (final n in kNhanLoaiHoaDon)
    if (!const {'giam gia', 'chiet khau'}.contains(n)) n,
];

class MonHang {
  const MonHang({required this.id, required this.ten, required this.soTien});

  /// Chỉ số dòng (trong chữ OCR của một ảnh) — ổn định trong một ảnh.
  final int id;
  final String ten;

  /// Âm với dòng giảm giá / KM.
  final double soTien;

  Map<String, Object> toJson() => {'id': id, 'ten': ten, 'soTien': soTien};

  static MonHang? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], ten = j['ten'], st = j['soTien'];
    if (id is! int || ten is! String || st is! num) return null;
    return MonHang(id: id, ten: ten, soTien: st.toDouble());
  }
}

/// Số tiền có NGĂN NGHÌN — loại ngày, giờ, năm (`2026` ≥ 1.000 mà `tienTrenDong` vẫn nhận), số điện thoại.
final RegExp _tienNgan = RegExp(r'^-?\d{1,3}(?:[.,]\d{3})+$');
final RegExp _coChu = RegExp(r'\p{L}', unicode: true);
final RegExp _maDai = RegExp(r'\b\d{8,}\b');
final RegExp _amTu = RegExp(r'\b(giam|km|khuyen mai|chiet khau)\b');

/// Token đuôi dòng thuộc phần số: số, `x`, `=`, `@`, `%`… (SL × đơn giá = thành tiền).
final RegExp _tokSo = RegExp(r'^[-xX=@*]?[\d.,]*[xX=@*%]?$');

double? _tienCuoi(List<String> tok) {
  if (tok.isEmpty || !_tienNgan.hasMatch(tok.last)) return null;
  final v = double.tryParse(tok.last.replaceAll('-', '').replaceAll(RegExp(r'[.,]'), ''));
  if (v == null || v < 1000) return null;
  return tok.last.startsWith('-') ? -v : v;
}

String _tenTu(List<String> tok) {
  var n = tok.length;
  while (n > 0 && _tokSo.hasMatch(tok[n - 1])) {
    n--;
  }
  return tok.take(n).join(' ').replaceAll(_maDai, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<MonHang> docMonHang(String vanBan) {
  final dong = [for (final d in vanBan.split('\n')) d.trim()].where((d) => d.isNotEmpty).toList();
  final ds = <MonHang>[];
  for (var i = 0; i < dong.length; i++) {
    final bo = boDauHoaDon(dong[i]);
    if (kNhanDungMon.any((r) => r.hasMatch(bo))) break;
    if (_nhanBoMon.any(bo.contains)) continue;
    final tok = dong[i].split(RegExp(r'\s+'));
    final tien = _tienCuoi(tok);
    if (tien == null) continue;
    var ten = _tenTu(tok);
    var id = i;
    // Món hai dòng: dòng này chỉ có số → tên ở dòng trên (dòng trên có chữ và không tự là một món).
    if (!_coChu.hasMatch(ten) && i > 0) {
      final tren = dong[i - 1].split(RegExp(r'\s+'));
      if (_coChu.hasMatch(dong[i - 1]) && _tienCuoi(tren) == null) {
        ten = _tenTu(tren);
        id = i - 1;
      }
    }
    if (!_coChu.hasMatch(ten)) continue;
    ds.add(MonHang(id: id, ten: ten, soTien: tien > 0 && _amTu.hasMatch(bo) ? -tien : tien));
  }
  return ds;
}
