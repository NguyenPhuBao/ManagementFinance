/// Chia sẻ biên lai — các hằng và phép kiểm tên tệp dùng chung (Dart thuần, không phụ thuộc gì). Tách khỏi
/// `nhap_bien_lai.dart` để tầng domain của form (`dien_san_bien_dong.dart`) và `nhap_bien_dong.dart` dùng được mà
/// không kéo theo Drift / bộ đọc chữ. `nhap_bien_lai.dart` xuất lại tệp này.
library;

/// Tệp hàng chờ và thư mục ảnh trong `filesDir` — khớp TAY với `NhanBienLaiActivity.TEP_HANG_CHO` / `THU_MUC`
/// (`bien_lai_noi_day_test.dart` canh).
const String kTepBienLaiCho = 'bien_lai_cho.jsonl';
const String kThuMucBienLai = 'bien_lai';

/// Nguồn hiển thị khi app gửi không nằm trong `kNguonTheoGoi` (hoặc không lấy được tên gói).
const String kNguonBienLai = 'Biên lai';

final RegExp _tenTep = RegExp(r'^[A-Za-z0-9_-]{4,64}\.[A-Za-z0-9]{1,5}$');

/// Tên tệp ảnh do Kotlin đặt (`<uuid>.<đuôi>`). ⚠️ Tên này đi vào `deeplink` (`anh=`) rồi được ghép thành đường dẫn —
/// không khớp khuôn thì coi như không có ảnh, không bao giờ ghép.
bool tenTepBienLaiHopLe(String tep) => _tenTep.hasMatch(tep);
