/// Văn bản pháp lý viết cứng trong app (đơn client-app mục 51 đổi hướng 2026-11-16; spec
/// `2026-11-16-dieu-khoan-chinh-sach-viet-cung-design.md`). Không API, không lưu trạng thái đồng ý.
/// Đổi nội dung = sửa tệp văn bản đã duyệt, chép lại hằng, tăng `phienBan` và đổi `ngayHieuLuc`.
library;

import 'chinh_sach_bao_mat.dart';
import 'dieu_khoan_su_dung.dart';

enum LoaiKhoi { doan, gach, tieuDeCon }

class KhoiVanBan {
  const KhoiVanBan.doan(this.chu) : loai = LoaiKhoi.doan;
  const KhoiVanBan.gach(this.chu) : loai = LoaiKhoi.gach;
  const KhoiVanBan.tieuDeCon(this.chu) : loai = LoaiKhoi.tieuDeCon;
  final LoaiKhoi loai;
  final String chu;
}

class MucVanBan {
  const MucVanBan(this.tieuDe, this.khoi);
  final String tieuDe;
  final List<KhoiVanBan> khoi;
}

class VanBan {
  const VanBan({
    required this.ma,
    required this.tenNgan,
    required this.tieuDe,
    required this.phienBan,
    required this.ngayHieuLuc,
    required this.moDau,
    required this.muc,
  });

  /// `dieu-khoan` / `bao-mat` — đoạn cuối đường dẫn `/chinh-sach/:ma`.
  final String ma;

  /// Tên trên AppBar và danh sách.
  final String tenNgan;

  /// Tiêu đề đầy đủ in đầu trang.
  final String tieuDe;
  final String phienBan;
  final DateTime ngayHieuLuc;
  final String moDau;
  final List<MucVanBan> muc;
}

List<VanBan> get danhSachVanBan => [kDieuKhoanSuDung, kChinhSachBaoMat];

VanBan? vanBanTheoMa(String? ma) {
  for (final v in danhSachVanBan) {
    if (v.ma == ma) return v;
  }
  return null;
}
