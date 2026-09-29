import '../../goal/domain/goal_history_direction.dart';
import '../../transaction/domain/transaction_owner.dart';
import '../../wallet/domain/dieu_chinh_so_du.dart';
import '../../wallet/domain/so_du_mo_so.dart';

/// "Hàng này có được tính vào thống kê không" — **định nghĩa duy nhất**.
///
/// ## Nó thay cái gì
///
/// Luật `loai != 'transfer'` từng là câu chép tay ở **năm** chỗ: bốn trong
/// `bao_cao_xuat.dart` (danh sách giao dịch, gom theo danh mục, dòng tiền, so
/// kỳ trước) và một trong `thong_ke_thang.dart`. Mỗi lần thêm một loại hàng
/// cần loại trừ là phải sửa đủ năm; chỗ nào quên thì con số ở đó lệch với bốn
/// chỗ kia, và người dùng thấy cùng một khoản được đếm ở màn này mà không ở
/// màn kia — không màn nào nói ra.
///
/// ## Bốn thứ bị loại (thứ tư — cặp nạp mục tiêu dạng cũ — thêm 2026-09-29, xem `laNuaCapNapMucTieuCu`)
///
/// - **Khoản chuyển** (`'transfer'`): tiền **đổi chỗ**, không rời khỏi tài sản
///   của người dùng. Đếm nó là mỗi kỳ trích tự động vào mục tiêu làm "Tổng chi"
///   tăng.
/// - **Khoản điều chỉnh số dư**: phép **sửa sổ**, không phải thu nhập hay chi
///   tiêu. Đếm nó là tháng nào người dùng đối soát ví cũng thấy thu nhập tăng
///   vọt. Phép nhận dạng nằm ở `wallet/domain/dieu_chinh_so_du.dart` — nó đòi
///   **cặp** điều kiện, không chỉ ghi chú.
/// - **Khoản mở sổ** (`Số dư ban đầu`): **điểm neo** để số dư ví suy được từ sổ
///   giao dịch, không phải thu nhập. Đếm nó là mỗi ví người dùng tạo ra lại làm
///   thu nhập tháng ấy tăng vọt đúng bằng số dư ban đầu. Nhận dạng ở
///   `wallet/domain/so_du_mo_so.dart`, cùng khuôn **cặp** điều kiện.
///
/// ⚠️ Khoản **chưa phân loại thật** thì **vẫn được tính**. Giao dịch kéo về từ
/// server có thể trống danh mục — 17 hàng như thế đã có trên CSDL, đo
/// 2026-09-10 — nên loại theo mỗi cột danh mục là giấu mất chi tiêu thật.
bool khoanVaoThongKe({
  required String loai,
  required String? categoryId,
  required String? ghiChu,
}) {
  if (loai == 'transfer') return false;
  if (laKhoanDieuChinh(loai: loai, categoryId: categoryId, ghiChu: ghiChu)) {
    return false;
  }
  if (laKhoanMoSo(loai: loai, categoryId: categoryId, ghiChu: ghiChu)) {
    return false;
  }
  if (laNuaCapNapMucTieuCu(loai: loai, categoryId: categoryId, ghiChu: ghiChu)) {
    return false;
  }
  return true;
}

/// Một nửa của **cặp nạp mục tiêu dạng cũ** — bản app trước 2026-09-05 ghi mỗi lần nạp thành HAI hàng thường thay vì
/// một khoản `'transfer'`: thu *"Tích lũy nhận từ Tiền mặt: MuaXe"* vào ví tích luỹ + chi *"Tích lũy mục tiêu: MuaXe"*
/// từ ví nguồn. Tiền đổi chỗ, cùng lý do đã loại khoản chuyển; đếm nó là thu VÀ chi cùng phồng (đo 2026-09-29, tài
/// khoản 10: chi tháng 9 2.351.000 thay vì 1.851.000 — cặp duy nhất trên PostgreSQL dev).
///
/// **Cặp** dấu hiệu như khoản điều chỉnh: không danh mục **và** tiền tố — app không bao giờ ghi khoản nạp có danh
/// mục, nên hàng có danh mục là người dùng tự gõ và phải được tính. Không nhận tiền tố **rút**: chưa thấy hàng rút dạng
/// cũ nào trong dữ liệu.
bool laNuaCapNapMucTieuCu({
  required String loai,
  required String? categoryId,
  required String? ghiChu,
}) {
  if (loai != 'thu' && loai != 'chi') return false;
  if (categoryId != null) return false;
  final g = (ghiChu ?? '').trimLeft();
  return g.startsWith(kGhiChuNapMucTieuCu) || g.startsWith(kGhiChuNapMucTieu);
}
