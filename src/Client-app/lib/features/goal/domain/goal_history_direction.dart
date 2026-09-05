/// Tiền tố ghi chú của khoản **nạp** vào mục tiêu.
const String kGhiChuNapMucTieu = 'Tích lũy mục tiêu: ';

/// Tiền tố ghi chú của khoản **rút** khỏi mục tiêu.
const String kGhiChuRutMucTieu = 'Rút từ mục tiêu: ';

/// Một hàng trong lịch sử mục tiêu là khoản **rút ra** hay khoản **nạp vào**.
///
/// Cả hai đều là giao dịch `'transfer'` mang cùng một `goal_id`, nên `type`
/// không phân biệt được.
///
/// ## Vì sao đọc ghi chú chứ không đọc vị trí ví
///
/// Cách hiển nhiên hơn là so ví: nạp thì ví tích lũy là ĐÍCH, rút thì nó là
/// NGUỒN. Cách ấy **sai với dữ liệu lịch sử**, vì nó diễn giải hàng cũ bằng cấu
/// hình **hiện tại** của mục tiêu. Đổi ví tích lũy một lần là mọi khoản nạp
/// trước đó có thể bỗng đọc thành khoản rút — đã gặp trên máy ảo ngày
/// 2026-09-05: một mục tiêu đổi ví xong thì cả hai dòng lịch sử đều hiện dấu
/// trừ, kể cả dòng người dùng thật sự đã gửi vào.
///
/// Tiền tố ghi chú thì do **chính app sinh ra** lúc ghi hàng, nằm luôn trong
/// hàng, đi qua được đồng bộ, và không đổi khi cấu hình mục tiêu đổi. Đây khác
/// hẳn với việc so **tên mục tiêu** trong ghi chú — thứ mà cột `goal_id` sinh ra
/// để thay thế: tên là dữ liệu người dùng đặt và không duy nhất, còn hai tiền tố
/// dưới đây là hằng số của mã nguồn, dùng chung cho cả nơi ghi lẫn nơi đọc.
///
/// Vị trí ví vẫn được dùng làm **phương án dự phòng** cho hàng không mang tiền
/// tố nào nhận ra được.
///
/// Vì sao đáng có hàm riêng: bỏ phép phân biệt này thì khoản rút hiện lên màn
/// hình giống hệt khoản nạp — cùng dấu `+`, cùng màu xanh — trong khi tiến độ
/// mục tiêu lại giảm. Người dùng thấy hai thứ nói ngược nhau trên cùng màn hình.
bool laKhoanRutKhoiMucTieu({
  required String ghiChu,
  required String viCuaHang,
  required String? viTichLuy,
}) {
  if (ghiChu.startsWith(kGhiChuRutMucTieu)) return true;
  if (ghiChu.startsWith(kGhiChuNapMucTieu)) return false;

  // Hàng lạ — không do luồng mục tiêu sinh ra, hoặc ghi chú đã bị sửa. Lúc này
  // vị trí ví là căn cứ duy nhất còn lại.
  if (viTichLuy == null || viTichLuy.isEmpty) return false;
  return viCuaHang == viTichLuy;
}
