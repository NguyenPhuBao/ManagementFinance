/// Phép thuần của màn Mời và Tạo nhà (spec gia đình mục 12.6). Server thi hành lại mọi luật; ở đây chỉ để khoá nút và chọn câu.
library;

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/gioi_han_do_dai.dart';

/// Lời mời còn hiệu lực cũng chiếm chỗ (đơn 50 C.2) — nguồn câu khoá hai nút màn Mời.
bool conChoMoi({required int soThanhVien, required int soLoiMoiConHieuLuc, required int toiDa}) =>
    soThanhVien + soLoiMoiConHieuLuc < toiDa;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool emailHopLeSoBo(String email) => !emailCoDau(email) && _email.hasMatch(email.trim());

/// Bộ gõ Telex vẫn đổi chữ trong ô email (`.test` thành `.tét`, đo trên Realme 2026-11-01), và nhà cung cấp thư từ chối
/// địa chỉ ngoài ASCII. Tách riêng để màn Mời nói được lý do thay vì chỉ khoá nút.
bool emailCoDau(String email) => email.codeUnits.any((c) => c > 0x7E);

bool tenNhaHopLe(String ten) {
  final t = ten.trim();
  return t.isNotEmpty && t.runes.length <= DoRongCot.tenNha;
}

String cauChiaSeMaMoi({required String tenNha, required String ma, DateTime? hetHan}) {
  final han = hetHan == null ? '' : ' Mã hết hạn lúc ${DateFormatter.formatDateTime(hetHan.toLocal())}.';
  return 'Mời bạn vào nhà "$tenNha" trên FlowMoney. Mã mời: $ma.$han';
}
