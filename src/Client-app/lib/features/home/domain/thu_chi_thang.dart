import '../../../core/database/app_database.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import '../../analytics/domain/thong_ke_thang.dart';

/// Tổng thu và tổng chi của tháng chứa [now] — con số của thẻ số liệu tháng
/// ở Trang chủ (`TheSoLieuThang`).
///
/// Tách thành hàm thuần vì từ 2026-09-19 có **hai** chỗ đọc nó: thẻ số liệu
/// và gói số của khối Nhận xét (`GoiSoTrangChu.tu`). Điều kiện 12 của mảng AI
/// là *số trên thẻ = số trong gói*; hai vòng lặp chép tay là hai định nghĩa
/// sẽ lệch nhau im lặng.
///
/// Từ 2026-09-23 nó **đi qua `tongThuChi`** của trang Phân tích — cùng hàm mà
/// tool `chi_tieu_theo_ky` của trợ lý AI đọc — và cắt tháng bằng `Ky.thang`,
/// cùng biên `[from, to)` với tháng của trang ấy. Trước đó nó cộng **thô**
/// theo `type`, nên đếm cả khoản điều chỉnh số dư lẫn khoản "Số dư ban đầu":
/// Trang chủ nói thu 15.145.000 đ trong khi trang Phân tích và trợ lý nói
/// 15.135.000 đ. Người dùng chốt con số của Phân tích là con số đúng.
/// ⚠️ Đừng viết lại vòng cộng ở đây — một vòng thứ hai là định nghĩa thứ hai.
({double thu, double chi}) thuChiThangCua(
  Iterable<Transaction> ds,
  DateTime now,
) {
  final thang = Ky.thang(now.year, now.month);
  final tong = tongThuChi(
    [
      for (final t in ds)
        KhoanThuChi(
          ngay: t.date,
          soTien: t.amount,
          loai: t.type,
          categoryId: t.categoryId,
          ghiChu: t.note,
        ),
    ],
    from: thang.from,
    to: thang.to,
  );
  return (thu: tong.thu, chi: tong.chi);
}
