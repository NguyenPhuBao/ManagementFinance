/// Tham số `chon` — MỘT định nghĩa cho tool giao dịch (hai giá trị đầu) và tool
/// ngân sách (cả bốn) — spec `2026-09-27-tool-truy-van-giao-dich-design.md` mục 4.
/// Lý do có nó: lần đo 15 (mục 9.29 `AI_EDGE_FEATURE.md`) E3 và E18 — mô hình có
/// đủ dữ liệu vẫn không làm phép chọn / lọc mà câu hỏi đòi, nên phép ấy về tay
/// hàm domain; mô hình chỉ điền mã.
library;

/// `chua_dat` (2026-09-27, spec chắn oan + chưa đặt): danh mục CHI đang tiêu
/// mà chưa có ngân sách — tool ngân sách đi đường `hangChuaDatNganSach`, không
/// qua `hangNganSach`.
///
/// `can_doi` (2026-09-28, lát 3 Task 11): kế hoạch tái phân bổ — tool ngân sách
/// đi đường `hangCanDoiNganSach`, cùng kế hoạch với thẻ *Đề xuất cân đối*.
const List<String> kChon = [
  'nhieu_nhat',
  'it_nhat',
  'duoi_nua',
  'tren_nua',
  'chua_dat',
  'can_doi',
];
const List<String> kChonGiaoDich = ['nhieu_nhat', 'it_nhat'];

/// `sap_het` (G2 Realme 2026-10-04, người dùng chốt): ngân sách chạm NGƯỠNG CẢNH
/// BÁO riêng (`isNearLimit` — cùng luật thông báo *Sắp vượt*) hoặc đã vượt. Mã
/// NỘI BỘ: chỉ bộ chỉnh tham số đặt khi câu hỏi nói *"sắp hết / vượt"*; cố ý
/// KHÔNG nằm trong [kChon] để enum gửi mô hình — và `tools_json` đã đo trên
/// Realme — không đổi.
const String kChonSapHet = 'sap_het';
const String kChuChonSapHet = 'sắp hết hoặc vượt hạn mức';

/// Chữ kèm cho mô hình — không chữ số (số ở đây không có trong gói và làm câu
/// chép nó bị chặn).
const Map<String, String> kChuChon = {
  'nhieu_nhat': 'lớn nhất, nhiều nhất, cao nhất',
  'it_nhat': 'nhỏ nhất, ít nhất, thấp nhất',
  'duoi_nua': 'đã dùng dưới một nửa',
  'tren_nua': 'đã dùng từ một nửa trở lên',
  'chua_dat': 'chưa đặt ngân sách',
  'can_doi': 'cần cân đối',
};
