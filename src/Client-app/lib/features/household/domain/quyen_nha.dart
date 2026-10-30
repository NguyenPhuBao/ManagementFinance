/// MỘT định nghĩa "vai × trạng thái nhà ⇒ làm được việc ấy không" — bảng mục 1 đơn 50 (spec gia đình 2026-10-23 mục 1,
/// 5.4–5.6). Server thi hành lại mọi luật; client dùng để khoá nút và chọn câu, không thay phép kiểm của server.
library;

import 'vai_nha.dart';

enum ViecNha { taoMa, huyMa, doiVai, moiRa, chuyenChu, giaiTan, roiNha, ghiDuLieu }

/// - Nhà giải tán, hoặc chưa có nhà ([vai] / [trangThai] `null`) → không việc nào.
/// - Chủ: mọi việc quản lý; tạo mã chỉ khi nhà hoạt động; KHÔNG rời (phải chuyển chủ hoặc giải tán trước).
/// - Thành viên / Chỉ xem: rời được lúc nào cũng được.
/// - Ghi dữ liệu của nhà: chủ hoặc thành viên, khi nhà hoạt động (nhà chỉ xem — chủ hết Premium — không ai ghi).
bool duocLamViecNha(ViecNha viec, {required VaiNha? vai, required TrangThaiNha? trangThai}) {
  if (vai == null || trangThai == null || trangThai == TrangThaiNha.daGiaiTan) return false;
  final chu = vai == VaiNha.chu;
  final hoatDong = trangThai == TrangThaiNha.hoatDong;
  return switch (viec) {
    ViecNha.taoMa => chu && hoatDong,
    ViecNha.huyMa || ViecNha.doiVai || ViecNha.moiRa || ViecNha.chuyenChu || ViecNha.giaiTan => chu,
    ViecNha.roiNha => !chu,
    ViecNha.ghiDuLieu => hoatDong && vai != VaiNha.chiXem,
  };
}
