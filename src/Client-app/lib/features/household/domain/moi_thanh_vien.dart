/// Phép thuần của màn Mời và Tạo nhà (spec gia đình mục 12.6). Server thi hành lại mọi luật; ở đây chỉ để khoá nút và chọn câu.
library;

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/gioi_han_do_dai.dart';

/// Lời mời còn hiệu lực cũng chiếm chỗ (đơn 50 C.2) — nguồn câu khoá hai nút màn Mời.
bool conChoMoi({required int soThanhVien, required int soLoiMoiConHieuLuc, required int toiDa}) =>
    soThanhVien + soLoiMoiConHieuLuc < toiDa;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool emailHopLeSoBo(String email) => _email.hasMatch(email.trim());

bool tenNhaHopLe(String ten) {
  final t = ten.trim();
  return t.isNotEmpty && t.runes.length <= DoRongCot.tenNha;
}

String cauChiaSeMaMoi({required String tenNha, required String ma, DateTime? hetHan}) {
  final han = hetHan == null ? '' : ' Mã hết hạn lúc ${DateFormatter.formatDateTime(hetHan.toLocal())}.';
  return 'Mời bạn vào nhà "$tenNha" trên FlowMoney. Mã mời: $ma.$han';
}
