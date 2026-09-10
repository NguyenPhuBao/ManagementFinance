import '../../wallet/domain/dieu_chinh_so_du.dart';

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
/// ## Hai thứ bị loại, vì hai lý do khác nhau
///
/// - **Khoản chuyển** (`'transfer'`): tiền **đổi chỗ**, không rời khỏi tài sản
///   của người dùng. Đếm nó là mỗi kỳ trích tự động vào mục tiêu làm "Tổng chi"
///   tăng.
/// - **Khoản điều chỉnh số dư**: phép **sửa sổ**, không phải thu nhập hay chi
///   tiêu. Đếm nó là tháng nào người dùng đối soát ví cũng thấy thu nhập tăng
///   vọt. Phép nhận dạng nằm ở `wallet/domain/dieu_chinh_so_du.dart` — nó đòi
///   **cặp** điều kiện, không chỉ ghi chú.
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
  return true;
}
