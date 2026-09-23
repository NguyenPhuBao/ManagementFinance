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
library;

/// `* `, `- `, `• ` ở đầu câu hoặc sau một lần xuống dòng.
final RegExp _gachDauDong = RegExp(r'(^|\n)[ \t]*[*\-•][ \t]+');

String boDanhDauMarkdown(String cau) => cau
    .replaceAllMapped(_gachDauDong, (m) => m.group(1)!)
    .replaceAll('**', '');
