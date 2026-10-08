/// A5 mục 5.1 — luật đọc HOÁ ĐƠN GIẤY từ chữ OCR (mỗi dòng một hàng, đã `ghepDongTheoHang`): tổng tiền, tên cửa hàng,
/// ngày, giờ. Hàm thuần.
///
/// Nâng từ spike C4 (`features/ai_chat/spike/spike_c4.dart`, lối A) ngày 2026-10-08 cho nút Quét. Spike giữ bí danh
/// gọi lại tệp này để màn đo và `spike_c4_test` không đổi.
library;

import '../../../core/category/category_name.dart';
import '../../../core/ocr/so_tien_tren_anh.dart';

class KetQuaHoaDon {
  final int? tong;
  final String? cuaHang;

  /// `dd/MM/yyyy`.
  final String? ngay;

  /// `HH:mm` in trên hoá đơn (A5 — giờ giao dịch đi cùng ngày).
  final String? gio;

  /// Dòng mà luật lấy tổng từ đó — để người chấm thấy vì sao.
  final String? canCu;
  const KetQuaHoaDon({this.tong, this.cuaHang, this.ngay, this.gio, this.canCu});

  @override
  String toString() =>
      'tong=$tong | cua_hang=$cuaHang | ngay=$ngay | gio=$gio${canCu == null ? '' : ' | can_cu="$canCu"'}';
}

/// Chữ thường, bỏ dấu, gom khoảng trắng — phép so nhãn của mọi luật đọc ảnh hoá đơn.
String boDauHoaDon(String s) => removeVietnameseTones(normalizeCategoryName(s));

/// Nhãn của dòng tổng, theo thứ tự ƯU TIÊN (đứng trước thắng). So trên chữ bỏ dấu.
const List<String> kNhanTongHoaDon = [
  'tong thanh toan',
  'can thanh toan',
  'phai thanh toan',
  'khach phai tra',
  'phai tra',
  'tong cong',
  'tong tien',
  'thanh tien',
  'grand total',
  'total',
  'thanh toan',
  'so tien',
  'tong',
];

/// Dòng trông như tổng nhưng không phải số phải trả.
const List<String> kNhanLoaiHoaDon = [
  'khach dua',
  'tien khach',
  'tien thoi',
  'thoi lai',
  'tien thua',
  'tra lai',
  'giam gia',
  'chiet khau',
  'tong so luong',
  'tong sl',
  'subtotal',
  'tam tinh',
];

final RegExp _ngay = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
final RegExp _gio = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?\b');

String? _docGio(String vanBan) {
  for (final m in _gio.allMatches(vanBan)) {
    final h = int.parse(m.group(1)!), p = int.parse(m.group(2)!);
    if (h < 24 && p < 60) return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
  }
  return null;
}

/// Chữ OCR (mỗi dòng một dòng) → tổng tiền + tên cửa hàng + ngày + giờ.
///
/// Tổng: dòng mang nhãn tổng (ưu tiên theo [kNhanTongHoaDon], hoà thì dòng SAU thắng — tổng cuối cùng nằm dưới), lấy số
/// lớn nhất trên dòng ấy; dòng nhãn không có số thì nhìn dòng kế (OCR hay tách nhãn và số). Không có nhãn nào → số lớn
/// nhất của cả hoá đơn.
KetQuaHoaDon docHoaDonTuChu(String vanBan) {
  final dong = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
  if (dong.isEmpty) return const KetQuaHoaDon();
  final bo = [for (final d in dong) boDauHoaDon(d)];

  int? tong;
  String? canCu;
  var hang = kNhanTongHoaDon.length;
  for (var i = 0; i < dong.length; i++) {
    if (kNhanLoaiHoaDon.any(bo[i].contains)) continue;
    final h = kNhanTongHoaDon.indexWhere(bo[i].contains);
    if (h < 0 || h > hang) continue;
    var tien = tienTrenDong(dong[i]);
    var nguon = dong[i];
    if (tien.isEmpty && i + 1 < dong.length && !kNhanLoaiHoaDon.any(bo[i + 1].contains)) {
      tien = tienTrenDong(dong[i + 1]);
      nguon = '${dong[i]} ⏎ ${dong[i + 1]}';
    }
    if (tien.isEmpty) continue;
    hang = h;
    tong = tien.reduce((a, b) => a > b ? a : b);
    canCu = nguon;
  }
  if (tong == null) {
    for (var i = 0; i < dong.length; i++) {
      if (kNhanLoaiHoaDon.any(bo[i].contains)) continue;
      for (final v in tienTrenDong(dong[i])) {
        if (tong == null || v > tong) {
          tong = v;
          canCu = '(không nhãn — số lớn nhất) ${dong[i]}';
        }
      }
    }
  }

  final cuaHang = dong.where((d) => RegExp(r'\p{L}{3,}', unicode: true).hasMatch(d)).firstOrNull;
  final n = _ngay.firstMatch(vanBan);
  return KetQuaHoaDon(
    tong: tong,
    cuaHang: cuaHang,
    ngay: n == null
        ? null
        : '${n.group(1)!.padLeft(2, '0')}/${n.group(2)!.padLeft(2, '0')}/'
            '${n.group(3)!.length == 2 ? '20${n.group(3)}' : n.group(3)}',
    gio: _docGio(vanBan),
    canCu: canCu,
  );
}
