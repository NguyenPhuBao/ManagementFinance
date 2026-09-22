// lib/features/ai_edge/domain/chu_de_chan.dart
/// Blocklist chủ đề cho hỏi đáp tự do (spec mục 4.4).
///
/// App có số liệu chi tiêu của một người; nó **không** có cơ sở nào để khuyên
/// về đầu tư, chứng khoán, tiền mã hoá, vay ngân hàng hay thuế — và một mô hình
/// 2,3 tỉ tham số chạy trên điện thoại thì càng không. Lời khuyên sai ở những
/// chủ đề ấy gây thiệt hại thật.
///
/// ⚠️ So **có dấu** (quy tắc 7 `CLAUDE.md`): bỏ dấu gộp "đầu tư" với "đầu
/// tuần" và từ chối một câu hỏi hợp lệ.
library;

const String kCauTuChoi =
    'Mình chỉ nhận xét được trên số liệu của bạn trong app.';

const List<String> _tuKhoaChan = [
  'đầu tư',
  'chứng khoán',
  'cổ phiếu',
  'trái phiếu',
  'tiền mã hoá',
  'tiền mã hóa',
  'tiền ảo',
  'bitcoin',
  'crypto',
  'vay ngân hàng',
  'lãi suất ngân hàng',
  'thuế',
];

bool chuDeBiChan(String cauHoi) {
  final s = cauHoi.toLowerCase();
  return _tuKhoaChan.any(s.contains);
}
