/// Tiền tố ghi chú của nửa RIÊNG trong cặp góp / rút (`docs/Family/02A` mục 5.2). Chỉ để HIỂN THỊ: nhận dạng khoản góp / rút
/// luôn qua `fundPairId`, không qua tiền tố (tên ví chung đổi thì ghi chú cũ vẫn mang tên cũ).
library;

const String kTienToGopQuy = 'Góp quỹ · ';
const String kTienToRutQuy = 'Rút quỹ · ';

/// Ghi chú của nửa riêng: tiền tố + tên ví chung, thêm ` · ghi chú` khi người dùng có gõ.
String ghiChuNuaRieng({required bool gop, required String tenViChung, String ghiChu = ''}) {
  final dau = '${gop ? kTienToGopQuy : kTienToRutQuy}$tenViChung';
  return ghiChu.isEmpty ? dau : '$dau · $ghiChu';
}
