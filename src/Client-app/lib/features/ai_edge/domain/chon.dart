/// Tham số `chon` — MỘT định nghĩa cho tool giao dịch (hai giá trị đầu) và tool
/// ngân sách (cả bốn) — spec `2026-09-27-tool-truy-van-giao-dich-design.md` mục 4.
/// Lý do có nó: lần đo 15 (mục 9.29 `AI_EDGE_FEATURE.md`) E3 và E18 — mô hình có
/// đủ dữ liệu vẫn không làm phép chọn / lọc mà câu hỏi đòi, nên phép ấy về tay
/// hàm domain; mô hình chỉ điền mã.
library;

const List<String> kChon = ['nhieu_nhat', 'it_nhat', 'duoi_nua', 'tren_nua'];
const List<String> kChonGiaoDich = ['nhieu_nhat', 'it_nhat'];

/// Chữ kèm cho mô hình — không chữ số (số ở đây không có trong gói và làm câu
/// chép nó bị chặn).
const Map<String, String> kChuChon = {
  'nhieu_nhat': 'lớn nhất, nhiều nhất, cao nhất',
  'it_nhat': 'nhỏ nhất, ít nhất, thấp nhất',
  'duoi_nua': 'đã dùng dưới một nửa',
  'tren_nua': 'đã dùng từ một nửa trở lên',
};
