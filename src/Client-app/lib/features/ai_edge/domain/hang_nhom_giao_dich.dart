/// Hàng NHÓM của `truy_van_giao_dich` — `gop = danh_muc | vi` (spec
/// `2026-09-27-tool-truy-van-giao-dich-design.md` mục 2.3). Chỉ chép
/// `gopGiaoDich`; hai đầu mang trạng thái (lần đo 15: E2B không tự chọn dù có
/// đủ dữ liệu); trần `kToiDaMucMoiGoi` với hàng cuối là nhóm ÍT NHẤT (9.31);
/// `chon` → một hàng. Tổng hợp đếm trên trọn tập `kq`, không trên hàng hiện.
library;

import '../../transaction/domain/gop_giao_dich.dart';
import '../../transaction/domain/tim_giao_dich.dart';
import 'chon.dart';
import 'goi_so.dart';
import 'hang_giao_dich.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

/// Chữ trạng thái hai đầu — chữ để mô hình đọc, không phải để suy luận. Chuỗi
/// chứa chữ *chi* / *thu* nhưng không phải chuỗi chiều tiền trần (test quét 14).
const String kTrangThaiChiNhieuNhat = 'chi nhiều nhất';
const String kTrangThaiChiItNhat = 'chi ít nhất';
const String kTrangThaiThuNhieuNhat = 'thu nhiều nhất';
const String kTrangThaiThuItNhat = 'thu ít nhất';

KetQuaCongCu hangNhomGiaoDich(
  KetQuaTimGiaoDich kq, {
  required TieuChiTim tieuChi,
  required NhomTheo theo,
  required String chuKy,
  String? chon,
}) {
  if (chon != null && !kChonGiaoDich.contains(chon)) {
    return tuChoiGiaTri('chon', chon, kChonGiaoDich);
  }
  final chieu = tieuChi.chieu;
  final theoThu = chieu == ChieuTim.thu;
  final nhom = gopGiaoDich(kq.dong, theo: theo, chieu: chieu);
  // Trần 4 hàng: top (trần − 1) + nhóm ÍT NHẤT — không phải hàng thứ tư giảm dần.
  final catTran = nhom.length <= kToiDaMucMoiGoi
      ? nhom
      : [...nhom.take(kToiDaMucMoiGoi - 1), nhom.last];
  final hien = switch (chon) {
    'nhieu_nhat' when nhom.isNotEmpty => [nhom.first],
    'it_nhat' when nhom.isNotEmpty => [nhom.last],
    _ => catTran,
  };
  String? trangThai(NhomGiaoDich n) {
    if (nhom.length < 2) return null;
    if (identical(n, nhom.first)) {
      return theoThu ? kTrangThaiThuNhieuNhat : kTrangThaiChiNhieuNhat;
    }
    if (identical(n, nhom.last)) {
      return theoThu ? kTrangThaiThuItNhat : kTrangThaiChiItNhat;
    }
    return null;
  }

  final tenNhom = theo == NhomTheo.danhMuc ? 'danh mục' : 'ví';
  return KetQuaCongCu(
    hang: [
      for (final n in hien)
        HangSoLieu(
          ten: n.ten,
          trangThai: trangThai(n),
          canhBao: false,
          soLieu: [
            // Xung đột "Thu" / "Chi" (bẫy 4.42): chữ hoa vì test quét 14.
            if (!theoThu)
              soTien('Chi', n.chi, ten: n.ten, nhanXungDot: const ['Thu']),
            if (n.thu > 0)
              soTien('Thu', n.thu, ten: n.ten, nhanXungDot: const ['Chi']),
            soDem('Số giao dịch', n.soKhoan, ten: n.ten, nhanKhac: const ['Số khoản']),
          ],
        ),
    ],
    tongHop: [
      if (!theoThu) soTien('Tổng chi', kq.tongChi),
      if (theoThu || chieu == ChieuTim.tatCa) soTien('Tổng thu', kq.tongThu),
      soDem('Số giao dịch', kq.soKhop, nhanKhac: const ['Số khoản']),
      soDem('Số $tenNhom', nhom.length),
    ],
    soLieuBoLoc: soLieuBoLocTimGiaoDich(tieuChi),
    boLoc: [
      ...boLocTimGiaoDich(kq, tieuChi),
      'gộp theo $tenNhom',
      if (chon == 'nhieu_nhat') 'chọn nhiều nhất',
      if (chon == 'it_nhat') 'chọn ít nhất',
    ],
    rongTheoBoLoc: kq.soKhop == 0,
    chuThem: {'ky': chuKy},
    tenLienQuan: {
      for (final n in nhom) n.ten,
      ...kq.tenKhop,
      if (tieuChi.tuKhoa.trim().isNotEmpty) tieuChi.tuKhoa.trim(),
    }.toList(),
  );
}
