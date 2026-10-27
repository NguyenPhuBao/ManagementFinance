/// Mọi câu khoá theo gói — MỘT chỗ (spec B1 2026-10-27 mục 4), test từng ký tự ở `cau_quyen_test.dart`.
library;

import '../data/models/tran_goi.dart';
import 'hang_goi.dart';
import 'quyen_tinh_nang.dart';
import 'tran_goi.dart';

/// Câu mở đầu màn Nâng cấp khi đến từ cửa chặn trần (`/premium?tran=`). [laPremium] — người ĐANG Premium chạm trần cột
/// Premium (B1): *"Gói Premium hiện cho tạo tối đa 10 ví."*; Basic giữ câu cũ (`3ec874aa`). Trần 0 → *"Gói … hiện không
/// cho tạo thêm ví."* [tranGoi] phải là `tranHieuLuc(…)` — trần thô của kho là G109. Trần `null` (không giới hạn — deeplink
/// tay) → `null`, không câu (bản trước in *"Bạn đã dùng null/null…"*).
String? cauMoDau(LoaiTran tran, TranGoi tranGoi, {bool laPremium = false}) {
  final n = tranGoi.cua(tran);
  if (n == null) return null;
  if (n == 0) return 'Gói ${laPremium ? 'Premium' : 'Basic'} hiện không cho tạo thêm ${tenTran(tran)}.';
  if (laPremium) return 'Gói Premium hiện cho tạo tối đa $n ${tenTran(tran)}.';
  return 'Bạn đã dùng $n/$n ${tenTran(tran)} của gói Basic.';
}

/// Câu mở đầu khi đến từ một tính năng bị khoá (`/premium?quyen=`) — spec phân quyền 2026-10-08 mục 4.4; [tamNgung] (B1).
String cauMoDauQuyen(MaQuyen ma, {bool tamNgung = false}) =>
    tamNgung ? '${ma.ten} hiện đang tạm ngừng.' : '${ma.ten} là tính năng Premium.';
