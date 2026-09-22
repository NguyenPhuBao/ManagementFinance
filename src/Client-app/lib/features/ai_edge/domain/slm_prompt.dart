// lib/features/ai_edge/domain/slm_prompt.dart
/// Dựng prompt cho SLM từ gói số. Hàm **thuần**: không chạm runtime, không đọc
/// đồng hồ — nên test được trọn vẹn mà không cần thiết bị.
///
/// ⚠️ Bơm `SoLieu.chuoi` chứ **không** bơm `soTho`. Chuỗi ấy là thứ người dùng
/// thấy trên thẻ số liệu; mô hình chép lại nguyên văn thì câu và thẻ nói cùng
/// một con số, và `kiemSo` khớp được.
library;

import 'goi_so.dart';
import 'nhan_xet.dart';

/// Chép **nguyên văn** mục 3.2 đặc tả gốc của backend (`docs/AI/AI_Edge-SLM.md/
/// Client-app.md`) — đừng sửa chữ ở đây mà không sửa tài liệu ấy trước.
const String kPromptHeThong =
    'Bạn là trợ lý tài chính. CHỈ sử dụng số liệu trong JSON được cung cấp. '
    'KHÔNG được tự tính toán, suy đoán, hoặc tạo ra con số không có trong dữ liệu. '
    'Nếu thiếu thông tin để trả lời, hãy nói rõ là không có dữ liệu, không bịa.';

/// Hai ví dụ few-shot. ⚠️ Mọi con số ở đây xuất hiện **cả** ở phần số liệu lẫn
/// phần câu của chính ví dụ — xem ca test cùng tên. Một ví dụ dạy mô hình nói
/// con số không có trong gói là làm mọi câu thật bị bộ kiểm số chặn.
const String _viDu = '''
Ví dụ 1.
Số liệu:
Ngân sách: Ăn uống
Đã chi: 400.000 đ
Hạn mức: 500.000 đ
Tỉ lệ: 80,0%
Câu: Ăn uống đã dùng 400.000 đ trên hạn mức 500.000 đ, tức 80,0%.

Ví dụ 2.
Số liệu:
Tổng chi: 1.200.000 đ
Tổng thu: 9.000.000 đ
Câu: Kỳ này chi 1.200.000 đ trên 9.000.000 đ thu.
''';

String _dongSoLieu(GoiSo g) =>
    [for (final s in g.soLieu) '${s.nhan}: ${s.chuoi}'].join('\n');

/// Dòng MỨC: hệ luật đã kết luận, mô hình chỉ diễn đạt. Không có dòng này thì
/// mô hình tự "đánh giá" từ số và có thể nói ngược (kiemGiong là lớp chắn sau).
String _dongMuc(GoiSo goi) => switch (goi.mauCau().muc) {
      MucNhanXet.canhBao =>
        'MỨC: CẢNH BÁO. Câu phải mang giọng cảnh báo, không được trấn an.',
      MucNhanXet.binhThuong =>
        'MỨC: BÌNH THƯỜNG. Câu mang giọng trung tính, không hù doạ.',
      MucNhanXet.thieuDuLieu => 'MỨC: THIẾU DỮ LIỆU.',
    };

String promptCauTheoMan(GoiSo goi) => '$kPromptHeThong\n\n$_viDu\n'
    '${_dongMuc(goi)}\n'
    'Viết MỘT câu tiếng Việt nhận xét, dưới 40 từ, chỉ dùng số dưới đây. '
    'Bỏ qua dòng nào không đáng nhắc với người đọc.\n'
    'Số liệu:\n${_dongSoLieu(goi)}\nCâu:';

String promptHoiDap(String cauHoi, List<GoiSo> goi) => '$kPromptHeThong\n\n$_viDu\n'
    'Trả lời câu hỏi dưới đây bằng tiếng Việt, dưới 80 từ, chỉ dùng số trong '
    'phần Số liệu.\n'
    'Số liệu:\n${goi.map(_dongSoLieu).join('\n')}\n'
    'Câu hỏi: $cauHoi\nTrả lời:';
