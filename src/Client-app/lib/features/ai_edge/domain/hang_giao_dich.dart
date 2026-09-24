/// Tool `tim_giao_dich` — phần của `ai_edge`: CHÉP kết quả của `timGiaoDich`
/// (transaction/domain) thành hàng (spec bước 2 mục 3.8). Không lọc, không so
/// chiều tiền (test quét 14): chiều đi bằng enum `ChieuTim`.
///
/// ⚠️ Tên hàng là ghi chú (luật tiêu đề dòng sổ), nên ghi chú hệ thống dài như
/// "Tích lũy mục tiêu: MuaXe" là tên, và `kiemNhan` đòi câu nêu ĐỦ mọi âm tiết
/// của nó. Mô hình rút gọn thì câu rơi về mẫu câu — an toàn, cố ý không nới.
library;

import '../../transaction/domain/tim_giao_dich.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

/// Mã tham số `chieu` của mô hình → chiều. ⚠️ Không dùng chữ trần của cột
/// `type` làm mã — test quét 14 cấm chúng trong `ai_edge/`.
const Map<String, ChieuTim> kChieuTim = {
  'khoan_chi': ChieuTim.chi,
  'khoan_thu': ChieuTim.thu,
  'chuyen_vi': ChieuTim.chuyen,
  'tat_ca': ChieuTim.tatCa,
};

const Map<String, SapXepTim> kSapXepTim = {
  'so_tien': SapXepTim.soTien,
  'moi_nhat': SapXepTim.moiNhat,
};

KetQuaCongCu hangGiaoDich(
  KetQuaTimGiaoDich kq, {
  required TieuChiTim tieuChi,
  required String chuKy,
  required DateTime now,
}) {
  final loi = kq.loi;
  if (loi != null) {
    final (thamSo, loai) = switch (loi.truong) {
      TruongTen.danhMuc => ('danh_muc', 'danh mục'),
      TruongTen.vi => ('vi', 'ví'),
    };
    return loi.nhieu
        ? tuChoiKhopNhieu(thamSo, loi.hoi, loi.tenGoiY, loai: loai)
        : tuChoiKhongKhop(thamSo, loi.hoi, loi.tenGoiY, loai: loai);
  }
  final chieu = tieuChi.chieu;
  final tatCa = chieu == ChieuTim.tatCa;
  final kt = tieuChi.khoangTien;
  return KetQuaCongCu(
    hang: [
      for (final d in kq.dong)
        HangSoLieu(
          ten: d.tieuDe,
          trangThai: _trangThai(d),
          canhBao: false,
          soLieu: [
            soTien('Số tiền', d.soTien, ten: d.tieuDe),
            soNgayThang('Ngày', d.ngay, ten: d.tieuDe, now: now),
          ],
        ),
    ],
    tongHop: [
      soDem('Số khoản', kq.soKhop),
      if (tatCa || chieu == ChieuTim.chi) soTien('Tổng chi', kq.tongChi),
      if (tatCa || chieu == ChieuTim.thu) soTien('Tổng thu', kq.tongThu),
      if (tatCa || chieu == ChieuTim.chuyen)
        soTien('Tổng chuyển', kq.tongChuyen),
      if (kt?.tu != null) soTien('Từ', kt!.tu!),
      if (kt?.den != null) soTien('Đến', kt!.den!),
    ],
    chuThem: {
      'ky': chuKy,
      'sap_xep': tieuChi.sapXep == SapXepTim.soTien
          ? 'lớn nhất trước'
          : 'mới nhất trước',
    },
    tenLienQuan: {
      for (final d in kq.dong) ...[
        if (d.tenDanhMuc != null) d.tenDanhMuc!,
        d.tenVi,
        if (d.tenViDich != null) d.tenViDich!,
      ],
      ...kq.tenKhop,
    }.toList(),
  );
}

String _trangThai(DongTimThay d) {
  final dm = d.tenDanhMuc ?? 'Chưa phân loại';
  return switch (d.chieu) {
    ChieuTim.chi => 'khoản chi · $dm · ${d.tenVi}',
    ChieuTim.thu => 'khoản thu · $dm · ${d.tenVi}',
    ChieuTim.chuyen => d.tenViDich == null
        ? 'chuyển ví · ${d.tenVi}'
        : 'chuyển ví · ${d.tenVi} → ${d.tenViDich}',
    // Hàng mang một loại lạ (không phải thu, chi, chuyển).
    ChieuTim.tatCa => 'giao dịch · $dm · ${d.tenVi}',
  };
}
