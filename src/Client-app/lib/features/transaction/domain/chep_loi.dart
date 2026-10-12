/// C4 — chép lời bằng Gemma (lối mất mạng, spec 2026-10-12 §3.5). Hàm thuần.
library;

/// Prompt chép lời — **giữ nguyên** bản spike C4 (2026-10-01). Đổi chữ là phải đo lại.
const String kPromptChepLoi =
    'Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về câu ấy, không giải thích.';

/// Lời chép thô → câu cho ô Nhập nhanh: bỏ khoảng trắng hai đầu, một cặp ngoặc kép bao ngoài, dấu chấm cuối câu.
String lamSachLoiChep(String tho) {
  var s = tho.trim();
  final bao = (s.startsWith('"') && s.endsWith('"')) || (s.startsWith('“') && s.endsWith('”'));
  if (s.length >= 2 && bao) s = s.substring(1, s.length - 1).trim();
  while (s.endsWith('.')) {
    s = s.substring(0, s.length - 1).trimRight();
  }
  return s;
}
