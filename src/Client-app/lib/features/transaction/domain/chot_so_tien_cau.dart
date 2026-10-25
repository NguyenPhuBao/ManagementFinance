/// C4 §3.4 — chốt SỐ TIỀN của một câu (gõ hoặc nói) khi luật đọc bằng dạng nói mới học và Gemma đọc lại. Hàm thuần. Cả
/// hai số đều ∈ `cachDocSoTien(câu)` (luật chọn trong tập ấy; Gemma qua `soTienAiHopLe`) — người dùng chọn bằng chip
/// (người dùng chốt 2026-10-12, như màn Quét ảnh).
///
/// Người dùng chốt 2026-10-22: chỉ số AI nằm trong [khac] (`KetQuaDocCau.soTienKhac` — số tiền còn sót trong ghi chú)
/// mới là lệch. Số AI khác số luật mà ngoài [khac] là Gemma đọc lại CHÍNH cụm luật theo cách khác (*"một triệu hai"* →
/// 1.000.000 — đo Realme 2026-10-21, 2/2 lần): giữ số luật, không chip.
library;

import '../../../core/utils/dung_sai_tien.dart';
import 'chot_tong_quet.dart' show ChotTong;

ChotTong chotSoTienCau({required double luat, required double? ai, required Set<double> khac}) =>
    ai != null && (ai - luat).abs() > kDungSaiTien && khac.any((v) => (v - ai).abs() <= kDungSaiTien)
        ? ChotTong(luaChon: [ai, luat])
        : ChotTong(soTien: luat);
