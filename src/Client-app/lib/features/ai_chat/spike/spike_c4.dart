/// Spike C4 — giọng nói và chụp hoá đơn (kế hoạch `plans/2026-09-28-c4-spike-giong-noi-chup-hoa-don.md`). Đường ĐO
/// TẠM: chỉ sống khi build với `--dart-define=SPIKE_C4=true`; bản thường hằng [kSpikeC4] là `false` và trình biên dịch
/// loại cả nhánh. Mã ở đây là mã BỎ ĐI — đầu ra của spike là một bảng số đo, không phải tính năng.
///
/// Tệp này giữ phần THUẦN (luật đọc hoá đơn từ chữ OCR, đọc JSON của mô hình, prompt) để test được; màn đo ở
/// `spike_c4_page.dart`.
library;

import 'dart:convert';

import '../../../core/ocr/so_tien_tren_anh.dart';
import '../../transaction/domain/doc_hoa_don.dart';

// `DongOcr` + `ghepDongTheoHang` dời về `core/ocr` (2026-10-02, chia sẻ biên lai dùng chung) — xuất lại để màn đo
// và test của spike gọi như cũ.
export '../../../core/ocr/dong_ocr.dart';
// Luật đọc hoá đơn (lối A) nâng sang `transaction/domain/doc_hoa_don.dart` ngày 2026-10-08 (A5) — xuất lại.
export '../../transaction/domain/doc_hoa_don.dart' show KetQuaHoaDon, docHoaDonTuChu;

/// Bật bằng `flutter build apk --debug --dart-define=SPIKE_C4=true`.
const bool kSpikeC4 = bool.fromEnvironment('SPIKE_C4');

/// Lối B giọng nói, kiểu 1: chép lời — để so ngang với lối A (câu → `docCauGiaoDich`).
const String kPromptChepLoi = 'Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về câu ấy, không giải thích.';

/// Lối B giọng nói, kiểu 2: hỏi thẳng thứ cần (mục 8.7 `AI_EDGE_FEATURE.md`: đi qua bản chép là thêm một nguồn sai).
const String kPromptYDinh = 'Người nói vừa kể một khoản thu hoặc chi. Trả về đúng một dòng dạng: '
    '<số tiền bằng chữ số, đơn vị đồng> | <nội dung ngắn>. Không giải thích.';

/// Lối B chụp hoá đơn.
const String kPromptHoaDon = 'Đây là ảnh một hoá đơn hoặc biên lai. Trả về DUY NHẤT một JSON: '
    '{"tong": <tổng tiền phải trả, số nguyên đồng>, "cua_hang": "<tên cửa hàng>", "ngay": "<dd/MM/yyyy hoặc rỗng>"}. '
    'Không giải thích.';

/// A5 (2026-10-08) — Gemma nhìn ảnh, liệt kê món.
const String kPromptMonHoaDon = 'Đây là ảnh một hoá đơn bán hàng. Liệt kê MỌI món hàng in trên hoá đơn. Trả về DUY '
    'NHẤT một JSON: {"mon": [{"ten": "<tên món>", "tien": <thành tiền, số nguyên đồng>}], "tong": <tổng phải trả, số '
    'nguyên đồng>, "cua_hang": "<tên cửa hàng>", "ngay": "<dd/MM/yyyy hoặc rỗng>", "gio": "<HH:mm hoặc rỗng>"}. '
    'Không giải thích.';

/// Tên cũ của `docSoTrenAnh` (`core/ocr/so_tien_tren_anh.dart`) — màn đo và test của spike còn gọi.
int? docSoHoaDon(String s) => docSoTrenAnh(s);

/// Lối B chụp hoá đơn: chữ mô hình trả về → [KetQuaHoaDon]. Bỏ rào ```json```, lấy khối `{…}` đầu tiên. `null` khi
/// không đọc ra JSON — người chấm xem chữ thô.
KetQuaHoaDon? docHoaDonTuJson(String chuMoHinh) {
  final a = chuMoHinh.indexOf('{');
  final b = chuMoHinh.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  try {
    final j = jsonDecode(chuMoHinh.substring(a, b + 1));
    if (j is! Map) return null;
    final t = j['tong'];
    final tong = switch (t) {
      final int v => v,
      final double v => v.round(),
      final String v => docSoHoaDon(v.replaceAll(RegExp(r'[^\d.,]'), '')),
      _ => null,
    };
    String? chu(Object? v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    return KetQuaHoaDon(tong: tong, cuaHang: chu(j['cua_hang']), ngay: chu(j['ngay']));
  } catch (_) {
    return null;
  }
}
