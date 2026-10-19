/// Gỡ dấu markdown khỏi một câu trả lời trước khi HIỆN — bẫy **4.36**.
///
/// Ở bậc tool (chặng 4b) lượt trả lời của E2B tự do hơn bậc 1, và OnePlus đo
/// được ngày 2026-09-23 câu *"Danh sách ngân sách sắp hết:\n*   Giáo dục: …
/// *   Di chuyển: …"* — màn Trợ lý AI hiện chữ trần nên dấu `*` lộ ra giữa câu.
///
/// Gỡ ở lúc hiện, **sau** khi câu đã qua `kiemCauTraLoi`: không đổi prompt,
/// không đụng bộ kiểm, và không chạm con số nào (kể cả `>` đứng trước con số
/// hay dấu so sánh, như `> 5 triệu` — giữ nguyên). ⚠️ Dấu gạch đầu dòng chỉ
/// được coi là dấu khi **theo sau bởi khoảng trắng** — `-100.000 đ` ở đầu câu
/// là số âm, gỡ nhầm là đổi nghĩa con số theo chiều nguy hiểm.
///
/// Mở rộng nghiệm thu máy thật 2026-10-18 (đường online): Gemini dùng thêm
/// tiêu đề `###`, trích dẫn `> ` và dòng kẻ ngang `---`, hiện trần trong bong
/// bóng *Trợ lý online*. Hàm gỡ thêm cả ba; luật bẫy 4.36 giữ nguyên — dấu chỉ
/// là dấu khi đứng đầu dòng và (với `#`, gạch) **theo sau bởi khoảng trắng**,
/// nên `#1 ưu tiên` và `-100.000 đ` còn nguyên.
library;

/// `>` (lồng được) ở đầu dòng, khoảng trắng theo sau có hoặc không. ⚠️ KHÔNG
/// gỡ khi `>` đứng trước chữ số (`> 5 triệu`) hoặc dính liền `=` / `<`
/// (`>= 5`): đó là so sánh, gỡ là đổi nghĩa con số (bẫy 4.36) — hàm được gọi
/// cho từng câu đã tách nên "đầu dòng" thực chất là đầu câu.
final RegExp _trichDan =
    RegExp(r'^(?:[ \t]*>(?![ \t]*\d|[=<])[ \t]*)+', multiLine: true);

/// `#` ×1–6 ở đầu dòng, BẮT BUỘC có khoảng trắng theo sau.
final RegExp _tieuDe = RegExp(r'^[ \t]*#{1,6}[ \t]+', multiLine: true);

/// Cả dòng chỉ gồm ≥ 3 ký tự `-` / `*` / `_` cùng loại (xen khoảng trắng),
/// kèm một dấu xuống dòng.
final RegExp _keNgang =
    RegExp(r'^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*(?:\n|$)', multiLine: true);

/// `* `, `- `, `• ` ở đầu câu hoặc sau một lần xuống dòng.
final RegExp _gachDauDong = RegExp(r'(^|\n)[ \t]*[*\-•][ \t]+');

/// Ba xuống dòng trở lên (dòng trống quanh `---` sau khi gỡ).
final RegExp _dongTrongKep = RegExp(r'\n{3,}');

String boDanhDauMarkdown(String cau) {
  var s = cau.replaceAll(_trichDan, '').replaceAll(_tieuDe, '');
  if (_keNgang.hasMatch(s)) {
    s = s.replaceAll(_keNgang, '').replaceAll(_dongTrongKep, '\n\n');
  }
  return s
      .replaceAllMapped(_gachDauDong, (m) => m.group(1)!)
      .replaceAll('**', '');
}
