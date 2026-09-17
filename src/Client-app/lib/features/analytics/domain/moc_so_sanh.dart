/// Mốc so sánh của hai thẻ tổng trang Phân tích (#2 khảo sát lần hai,
/// 2026-09-16).
///
/// Trang này vốn chỉ so với **kỳ liền trước**. Chip thứ hai mở thêm mốc **cùng
/// kỳ năm trước** — thứ Monarch và Copilot đều đặt ngay cạnh con số của kỳ.
///
/// [nenSoSanh] là **định nghĩa duy nhất** của việc "chip nào thì lấy con số nào,
/// và gọi kỳ ấy là gì". Có một hàm riêng thay vì hai nhánh `if` rải trong
/// widget, vì cặp *số* và *nhãn* phải đi cùng nhau: lấy số của năm trước mà in
/// nhãn của kỳ trước thì thẻ nói một câu hoàn toàn hợp lý và hoàn toàn sai —
/// không exception, không log, và người đọc không có cách nào biết.
library;

import 'pham_vi_ky.dart';
import 'thong_ke_thang.dart';

/// Hai mốc mà hai thẻ tổng so vào.
///
/// Thứ tự **có nghĩa**: phần tử đầu là mặc định, và nó phải là [kyTruoc] để
/// người dùng cũ mở trang lên thấy đúng con số họ vẫn thấy.
enum MocSoSanh {
  kyTruoc,
  cungKyNamTruoc;

  /// Chữ trên chip. Ngắn, vì hàng chip nằm trên khổ 411dp.
  String get nhanChip => switch (this) {
        MocSoSanh.kyTruoc => 'So với kỳ trước',
        MocSoSanh.cungKyNamTruoc => 'Cùng kỳ năm trước',
      };
}

/// Nền so sánh của [moc] khi đang xem [ky]: tổng thu/chi của kỳ nền, và **tên**
/// kỳ ấy cho câu "so với …".
///
/// Trả cả hai cùng lúc là có chủ ý — xem docstring đầu tệp.
///
/// Phần trăm **không** tính ở đây: `phanTramSoVoi` đã là định nghĩa duy nhất,
/// và nó trả `null` khi nền bằng 0 để giao diện nói "Không có dữ liệu …" thay vì
/// in "tăng 100%", một con số bịa. ⚠️ Nền bằng 0 ở mốc năm trước **không phải ca
/// hiếm**: mọi tài khoản chưa đủ một năm tuổi đều rơi vào đó ở mọi kỳ.
({TongThuChi nen, String nhan}) nenSoSanh({
  required MocSoSanh moc,
  required Ky ky,
  required TongThuChi kyTruoc,
  required TongThuChi namTruoc,
}) =>
    switch (moc) {
      MocSoSanh.kyTruoc => (nen: kyTruoc, nhan: nhanKyTruoc(ky)),
      MocSoSanh.cungKyNamTruoc => (
          nen: namTruoc,
          nhan: nhanCungKyNamTruoc(ky),
        ),
    };
