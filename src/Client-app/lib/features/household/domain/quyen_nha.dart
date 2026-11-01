/// MỘT định nghĩa "vai × trạng thái nhà ⇒ làm được việc ấy không" — luật quyền ở `docs/Family/01_NEN_MONG.md` mục 3 (thay
/// đoạn D.2 của đơn 50; khi hai nơi lệch thì `docs/Family/` thắng) và bảng trạng thái nhà mục 4. Server thi hành lại mọi luật;
/// client dùng để khoá nút và chọn câu, không thay phép kiểm của server.
library;

import 'vai_nha.dart';

enum ViecNha { taoMa, huyMa, doiVai, moiRa, chuyenChu, giaiTan, roiNha, quanLyViChung, ghiKhoan, chuyenGiuaViChung, suaDanhMuc }

/// - Nhà giải tán, hoặc chưa có nhà ([vai] / [trangThai] `null`) → không việc nào.
/// - Chủ: mọi việc quản lý; tạo mã chỉ khi nhà hoạt động; KHÔNG rời (phải chuyển chủ hoặc giải tán trước).
/// - Thành viên / Chỉ xem: rời được lúc nào cũng được.
/// - Ghi khoản / sửa danh mục của nhà: chủ hoặc thành viên, khi nhà hoạt động (nhà chỉ xem — chủ hết Premium — không ai ghi).
/// - Quản lý ví chung và chuyển giữa ví chung: chỉ chủ, khi nhà hoạt động.
bool duocLamViecNha(ViecNha viec, {required VaiNha? vai, required TrangThaiNha? trangThai}) {
  if (vai == null || trangThai == null || trangThai == TrangThaiNha.daGiaiTan) return false;
  final chu = vai == VaiNha.chu;
  final hoatDong = trangThai == TrangThaiNha.hoatDong;
  return switch (viec) {
    ViecNha.taoMa => chu && hoatDong,
    ViecNha.huyMa || ViecNha.doiVai || ViecNha.moiRa || ViecNha.chuyenChu || ViecNha.giaiTan => chu,
    ViecNha.roiNha => !chu,
    ViecNha.quanLyViChung || ViecNha.chuyenGiuaViChung => chu && hoatDong,
    ViecNha.ghiKhoan || ViecNha.suaDanhMuc => hoatDong && vai != VaiNha.chiXem,
  };
}

/// Sửa một khoản của nhà (`Family/01` mục 3). Khoản có mã cặp chỉ người ghi sửa được: nửa riêng chỉ nằm trên máy họ.
/// Khoản chuyển ([laChuyen]) chỉ Chủ nhà sửa, xoá — server chỉ cho Owner (`sync.service.js`); Chủ cũ đã bị hạ vai thì
/// khoản chuyển người ấy từng ghi không còn sửa, xoá được.
bool duocSuaKhoanNha(
    {required VaiNha? vai,
    required TrangThaiNha? trangThai,
    required bool cuaToi,
    required bool coMaCap,
    required bool laChuyen}) {
  if (!duocLamViecNha(ViecNha.ghiKhoan, vai: vai, trangThai: trangThai)) return false;
  if (laChuyen) return vai == VaiNha.chu;
  if (cuaToi) return true;
  return vai == VaiNha.chu && !coMaCap;
}

/// Xoá một khoản của nhà: người ghi hoặc Chủ nhà; khoản chuyển chỉ Chủ nhà.
bool duocXoaKhoanNha(
    {required VaiNha? vai, required TrangThaiNha? trangThai, required bool cuaToi, required bool laChuyen}) {
  if (!duocLamViecNha(ViecNha.ghiKhoan, vai: vai, trangThai: trangThai)) return false;
  if (laChuyen) return vai == VaiNha.chu;
  return cuaToi || vai == VaiNha.chu;
}
