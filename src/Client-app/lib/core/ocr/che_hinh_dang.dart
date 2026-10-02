/// Hình dạng ĐÃ CHE của một dòng chữ đọc từ ảnh biên lai — để log lúc thu mẫu (chỉ bản debug) mà không lộ số tiền,
/// số tài khoản, tên người, nội dung chuyển khoản (quy tắc §13.6 `progress/Client-app.md`). Cùng phép với
/// `BienDongListenerService.che` phía Kotlin: mọi chữ số → `9`, mọi từ ngoài [kTuCauTrucBienLai] → `…`.
library;

/// Nhãn, đơn vị, động từ của một biên lai — giữ nguyên khi che. Có cả dạng không dấu: chữ đọc từ ảnh hay rụng dấu.
///
/// ⚠️ Chỉ thêm từ là NHÃN. Một từ cũng hay nằm trong nội dung chuyển khoản (*"tien"*, *"chuyen"*) lọt qua ở dạng
/// nguyên văn là chấp nhận được — nó không định danh ai; tên riêng và con số thì không bao giờ lọt.
const Set<String> kTuCauTrucBienLai = {
  'số', 'so', 'tiền', 'tien', 'nội', 'noi', 'dung', 'mã', 'ma', 'giao', 'dịch', 'dich', 'gd', 'thời', 'thoi', 'gian',
  'ngày', 'ngay', 'giờ', 'gio', 'tài', 'tai', 'khoản', 'khoan', 'tk', 'người', 'nguoi', 'nhận', 'nhan', 'gửi', 'gui',
  'chuyển', 'chuyen', 'ngân', 'ngan', 'hàng', 'hang', 'phí', 'phi', 'vnd', 'đ', 'thành', 'thanh', 'công', 'cong',
  'tham', 'chiếu', 'chieu', 'lời', 'loi', 'nhắn', 'từ', 'tu', 'đến', 'den', 'tới', 'toi', 'tổng', 'tong',
  'dư', 'du', 'nguồn', 'nguon', 'thụ', 'hưởng', 'huong', 'chi', 'tiết', 'tiet', 'loại', 'loai', 'ví', 'vi',
  'toán', 'toan', 'hình', 'hinh', 'thức', 'thuc', 'trạng', 'trang', 'thái', 'thai', 'lệnh', 'lenh',
};

final RegExp _chuSo = RegExp(r'\d');
final RegExp _tu = RegExp(r'\p{L}+', unicode: true);

String cheHinhDang(String s) => s
    .replaceAll(_chuSo, '9')
    .replaceAllMapped(_tu, (m) => kTuCauTrucBienLai.contains(m.group(0)!.toLowerCase()) ? m.group(0)! : '…');
