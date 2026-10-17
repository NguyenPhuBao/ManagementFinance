/// Gỡ dấu markdown khỏi một câu trả lời trước khi HIỆN — bẫy **4.36**.
///
/// Ở bậc tool (chặng 4b) lượt trả lời của E2B tự do hơn bậc 1, và OnePlus đo
/// được ngày 2026-09-23 câu *"Danh sách ngân sách sắp hết:\n*   Giáo dục: …
/// *   Di chuyển: …"* — màn Trợ lý AI hiện chữ trần nên dấu `*` lộ ra giữa câu.
///
/// Gỡ ở lúc hiện, **sau** khi câu đã qua `kiemCauTraLoi`: không đổi prompt,
/// không đụng bộ kiểm, và không chạm con số nào. ⚠️ Dấu gạch đầu dòng chỉ
/// được coi là dấu khi **theo sau bởi khoảng trắng** — `-100.000 đ` ở đầu câu
/// là số âm, gỡ nhầm là đổi nghĩa con số theo chiều nguy hiểm.
///
/// Mở rộng nghiệm thu máy thật 2026-10-18 (đường online): Gemini dùng thêm
/// tiêu đề `###`, trích dẫn `> ` và dòng kẻ ngang `---`, hiện trần trong bong
/// bóng *Trợ lý online*. Hàm gỡ thêm cả ba; luật bẫy 4.36 giữ nguyên — dấu chỉ
/// là dấu khi đứng đầu dòng và (với `#`, gạch) **theo sau bởi khoảng trắng**,
/// nên `#1 ưu tiên` và `-100.000 đ` còn nguyên.
library;

/// `>` (lồng được) ở đầu dòng, khoảng trắng theo sau có hoặc không.
final RegExp _trichDan = RegExp(r'^(?:[ \t]*>[ \t]*)+', multiLine: true);

/// `#` ×1–6 ở đầu dòng, BẮT BUỘC có khoảng trắng theo sau.
final RegExp _tieuDe = RegExp(r'^[ \t]*#{1,6}[ \t]+', multiLine: true);

/// Cả dòng chỉ gồm ≥ 3 ký tự `-` / `*` / `_` cùng loại (xen khoảng trắng),
/// kèm một dấu xuống dòng.
final RegExp _keNgang =
    RegExp(r'^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*(?:\n|$)', multiLine: true);

/// `* `, `- `, `• ` ở đầu câu hoặc sau một lần xuống dòng.
final RegExp _gachDauDong = RegExp(r'(^|\n)[ \t]*[*\-•][ \t]+');

String boDanhDauMarkdown(String cau) => cau
    .replaceAll(_trichDan, '')
    .replaceAll(_tieuDe, '')
    .replaceAll(_keNgang, '')
    .replaceAllMapped(_gachDauDong, (m) => m.group(1)!)
    .replaceAll('**', '');
