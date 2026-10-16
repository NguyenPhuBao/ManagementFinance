/// C4 §3.4 — chốt SỐ TIỀN của một câu (gõ hoặc nói) khi luật đọc bằng dạng nói mới học và Gemma đọc lại. Hàm thuần. Cả
/// hai số đều ∈ `cachDocSoTien(câu)` (luật chọn trong tập ấy; Gemma qua `soTienAiHopLe`) nên "lệch" là hai cách đọc
/// THẬT của cùng một câu — người dùng chọn bằng chip (người dùng chốt 2026-10-12, như màn Quét ảnh).
library;

import 'chot_tong_quet.dart' show ChotTong;

ChotTong chotSoTienCau({required double luat, required double? ai}) =>
    ai == null || (ai - luat).abs() <= 0.5 ? ChotTong(soTien: luat) : ChotTong(luaChon: [ai, luat]);
