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

/// Có tên đối tượng thì nêu tên trước — mô hình chỉ nói được tên nếu tên có
/// ở đây. Không có thì giữ nguyên dạng cũ, vì `ten == null` là ca **thường**
/// (tổng thu, tổng chi) chứ không phải dấu hiệu thiếu dữ liệu.
String _dongSoLieu(GoiSo g) => [
      for (final s in g.soLieu)
        s.ten == null
            ? '${s.nhan}: ${s.chuoi}'
            : '${s.ten} · ${s.nhan}: ${s.chuoi}',
    ].join('\n');

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

/// Ba ví dụ few-shot **riêng cho hỏi đáp** (việc số 1, 2026-09-22). Trước đó
/// `promptHoiDap` mượn hai ví dụ nhận xét ở trên: không ví dụ hỏi–đáp nào,
/// không ví dụ *"không có dữ liệu"* nào — một trong bốn nguyên nhân đo được
/// của "AI trả lời sai" (mục 9.5 `AI_EDGE_FEATURE.md`).
///
/// Ba điều mỗi ví dụ làm mẫu, có ca test canh từng điều:
/// - câu trả lời **chép nguyên nhãn** đứng trước con số (lý do của `kiemNhan`:
///   mô hình hay gắn nhãn của *câu hỏi* vào con số gần nghĩa nhất);
/// - mọi con số ở phần trả lời đều có ở phần số liệu của chính ví dụ ấy;
/// - ví dụ 3 hỏi thứ **không có** số liệu và trả lời **không có chữ số nào** —
///   E2B không tự suy ra được hành vi ấy từ chỉ dẫn suông.
const String _viDuHoiDap = '''
Ví dụ 1.
Số liệu:
== Chi tiêu tháng này ==
Tổng chi: 1.200.000 đ
Tổng thu: 9.000.000 đ
Để dành: 86,7%
Câu hỏi: Tháng này tôi tiêu thế nào?
Trả lời: Tổng chi tháng này là 1.200.000 đ trên tổng thu 9.000.000 đ; bạn để dành được 86,7% thu nhập.

Ví dụ 2.
Số liệu:
== Mục tiêu ==
Tiến độ: 40,0%
Còn thiếu: 3.000.000 đ
Còn: 20 ngày
Câu hỏi: Mục tiêu của tôi sao rồi?
Trả lời: Mục tiêu đạt tiến độ 40,0%, còn thiếu 3.000.000 đ và còn 20 ngày.

Ví dụ 3.
Số liệu:
== Chi tiêu tháng này ==
Tổng chi: 1.200.000 đ
Câu hỏi: Tháng trước tôi chi cho ăn uống bao nhiêu?
Trả lời: Mình không có số liệu về chi tiêu tháng trước theo danh mục, nên không trả lời được.

Ví dụ 4.
Số liệu:
== Ngân sách ==
Giáo dục · Tỉ lệ: 90,0%
Mua sắm · Tỉ lệ: 7,1%
Câu hỏi: Ngân sách nào sắp hết?
Trả lời: Giáo dục căng nhất, đã dùng 90,0%; Mua sắm mới dùng 7,1%.
''';

/// Tên màn in làm tiêu đề khối số liệu. Hai nhãn trùng tên ở hai gói (`Còn
/// thiếu` ở ngân sách lẫn mục tiêu, `Tiến độ` ở mục tiêu lẫn hoá đơn) chỉ
/// phân biệt được nhờ tiêu đề này.
String tenMan(String man) => switch (man) {
      'phan_tich' => 'Chi tiêu tháng này',
      'ngan_sach' => 'Ngân sách',
      'muc_tieu' => 'Mục tiêu',
      'hoa_don' => 'Hoá đơn',
      'vi' => 'Ví',
      'trang_chu' => 'Trang chủ',
      _ => man,
    };

/// Gói thiếu dữ liệu in **câu mẫu** của nó thay vì im lặng: im lặng là để mô
/// hình lấy số của gói khác trả lời thay.
String _khoiSoLieu(GoiSo g) =>
    '== ${tenMan(g.man)} ==\n${g.thieuDuLieu ? g.mauCau().cau : _dongSoLieu(g)}';

String promptHoiDap(String cauHoi, List<GoiSo> goi) =>
    '$kPromptHeThong\n\n$_viDuHoiDap\n'
    'Trả lời câu hỏi dưới đây bằng tiếng Việt, dưới 80 từ, chỉ dùng số trong '
    'phần Số liệu và dùng đúng nhãn đứng trước mỗi con số. Không có số liệu '
    'để trả lời thì nói rõ là không có, không lấy số khác thay.\n'
    'Số liệu:\n${goi.map(_khoiSoLieu).join('\n')}\n'
    'Câu hỏi: $cauHoi\nTrả lời:';

/// Chỉ dẫn hệ thống cho BẬC TOOL (chặng 4b, spec mục 3.7) — đi bằng
/// `systemInstruction` native của LiteRT-LM, không nằm trong tin người dùng.
///
/// KHÔNG few-shot: thứ dẫn E2B chọn tool là mô tả tool tiếng Việt (`KhaiBaoCongCu.moTa`).
/// Không mang con số nào ngoài giới hạn độ dài — một số ở đây là một số mô hình
/// có thể chép vào câu mà không gói nào có (ca test canh).
const String kPromptHeThongCongCu =
    'Bạn là trợ lý tài chính của ứng dụng FlowMoney. Bạn KHÔNG có sẵn số liệu nào '
    'của người dùng: muốn biết bất kỳ con số hay tên nào (ngân sách, hoá đơn, ví, '
    'chi tiêu, mục tiêu, gợi ý hạn mức, từng giao dịch), hãy gọi công cụ phù hợp '
    'TRƯỚC khi trả lời. Công cụ trả "loi" thì gọi lại ngay với tham số đúng theo '
    'lời ấy, chưa trả lời. Khi trả lời: chỉ dùng tên và số mà công cụ trả về, chép '
    'nguyên chuỗi số và ngày tháng (kể cả "đ", dấu phẩy và dấu gạch chéo), nêu tên '
    'đối tượng trước con số, không tự tính toán hay suy đoán. Công cụ báo không có '
    'dữ liệu thì nói rõ là không có. Trả lời bằng tiếng Việt, ngắn gọn, dưới 60 từ.';
