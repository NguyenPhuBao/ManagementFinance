/// C1 — gắn danh mục hàng loạt cho giao dịch chưa phân loại (spec `2026-09-28-c1-gan-danh-muc-hang-loat-design.md`
/// §2). Hàm thuần: không Drift query, không Flutter, không đồng hồ.
///
/// Nó KHÔNG có mô hình riêng: mọi dự đoán là của B1 (`phan_loai_ghi_chu.dart`), chạy trên giao dịch đã có thay vì
/// trên ghi chú đang gõ. Bất biến ④ của nhóm C: đây chỉ là đề xuất điền sẵn — người dùng bấm *Áp dụng* mới ghi.
library;

import '../../../core/database/app_database.dart';
import 'phan_loai_ghi_chu.dart';

/// Một dòng của màn duyệt: giao dịch chưa phân loại, kèm dự đoán của B1 nếu có.
class DongGanDanhMuc {
  final Transaction giaoDich;

  /// `null` = không đoán được (sổ mỏng, ghi chú rỗng/lạ, hậu nghiệm thấp, cặp đang bị thôi gợi ý…).
  final DoanDanhMuc? doan;

  /// `cauLyDoHoc(...)` khi có [doan]; `null` khi không.
  final String? lyDo;
  const DongGanDanhMuc({required this.giaoDich, this.doan, this.lyDo});
}

/// Điều kiện "xét" — **định nghĩa duy nhất**, dùng cho cả thẻ ở Sổ giao dịch ([demChuaGan]) lẫn màn duyệt
/// ([dungDanhSachGan]). Hai chỗ đếm hai kiểu là thẻ hứa N dòng mà màn hiện số khác.
///
/// Khoản do máy sinh (điều chỉnh số dư, mở sổ, nạp/rút mục tiêu, trả hoá đơn, khoản chuyển) cố ý không có danh mục
/// — nhận dạng qua `laGhiChuMay` của B1, không viết luật thứ hai.
bool xetGan(Transaction t) =>
    !t.isDeleted &&
    t.deletedAt == null &&
    t.categoryId == null &&
    t.type != 'transfer' &&
    !laGhiChuMay(loai: t.type, categoryId: t.categoryId, ghiChu: t.note);

int demChuaGan(List<Transaction> giaoDich) => giaoDich.where(xetGan).length;

/// Danh mục gắn được cho một khoản theo chiều tiền: `chi` → {chi, vay_no}; `thu` → {thu, vay_no}.
///
/// ⚠️ Thiếu bộ lọc này thì mô hình — học trên CẢ BA phân loại — gắn được *"Lương"* cho một khoản chi, tức đảo chiều
/// tiền trong mọi thống kê. [chonDuoc] là tập `selectableChildrenAll` của màn Thêm giao dịch; vẫn bỏ hàng đã xoá và
/// nhóm cho chắc.
Set<String> hopLeTheoChieu(String loai, List<Category> chonDuoc) {
  final phanLoai = switch (loai) {
    'chi' => const {'chi', 'vay_no'},
    'thu' => const {'thu', 'vay_no'},
    _ => const <String>{},
  };
  return {
    for (final c in chonDuoc)
      if (!c.isDeleted && !c.isGroup && phanLoai.contains(c.classify)) c.id,
  };
}

/// Danh sách dòng của màn duyệt: mọi giao dịch [xetGan], mỗi dòng kèm dự đoán của [mo] (lọc theo chiều tiền).
///
/// Thứ tự: dòng CÓ dự đoán trước (xác suất giảm dần) — người dùng duyệt phần máy đã làm trước; rồi dòng không có
/// (ngày mới nhất trước).
List<DongGanDanhMuc> dungDanhSachGan({
  required List<Transaction> giaoDich,
  required List<Category> chonDuoc,
  required BoPhanLoaiGhiChu? mo,
  required Set<(String, String)> tatCap,
}) {
  final ten = {for (final c in chonDuoc) c.id: c.name};
  final coDoan = <DongGanDanhMuc>[];
  final khong = <DongGanDanhMuc>[];
  for (final t in giaoDich.where(xetGan)) {
    final d = mo?.doan(t.note, hopLe: hopLeTheoChieu(t.type, chonDuoc), tatCap: tatCap);
    if (d == null) {
      khong.add(DongGanDanhMuc(giaoDich: t));
    } else {
      coDoan.add(DongGanDanhMuc(
        giaoDich: t,
        doan: d,
        lyDo: cauLyDoHoc(d, ghiChuGoc: t.note, tenDanhMuc: ten[d.categoryId]!),
      ));
    }
  }
  coDoan.sort((a, b) => b.doan!.xacSuat.compareTo(a.doan!.xacSuat));
  khong.sort((a, b) => b.giaoDich.date.compareTo(a.giaoDich.date));
  return [...coDoan, ...khong];
}

/// Phản hồi ghi vào bảng B1 cho một dòng ĐANG TICK được áp dụng với danh mục [categoryIdCuoi] (spec §5).
///
/// `null` = không ghi: dòng không có dự đoán thì không có gì để phán xét. Dòng bỏ tick không bao giờ tới đây — bỏ tick
/// là *"chưa muốn sửa dòng này"*, không phải *"dự đoán sai"*. Cùng nghĩa với màn Thêm giao dịch: giữ dự đoán là
/// `chon`, đổi sang danh mục khác là `khac`; cả hai mang danh mục cuối cùng.
({String ketQua, String chonCategoryId})? phanHoiGan(DongGanDanhMuc dong, String categoryIdCuoi) {
  final d = dong.doan;
  if (d == null) return null;
  return (
    ketQua: d.categoryId == categoryIdCuoi ? kKetQuaGoiYChon : kKetQuaGoiYKhac,
    chonCategoryId: categoryIdCuoi,
  );
}

/// Câu toast sau lượt áp dụng — tối giản, KHÔNG nêu số (nếp thông báo tạm thời của dự án: nói đủ ý, phân biệt *xong*
/// với *còn kẹt*; con số còn lại đã hiện ngay trên thẻ Sổ giao dịch khi quay về). `null` = không có gì để nói.
String? cauKetQuaGan({required int thanhCong, required int loi}) {
  if (loi == 0) return thanhCong == 0 ? null : 'Đã gắn danh mục';
  if (thanhCong == 0) return 'Chưa lưu được danh mục — thử lại sau';
  return 'Đã gắn danh mục — có giao dịch chưa lưu được';
}
