/// Bộ kiểm NHÃN — lớp chắn thứ ba, đứng sau `kiemSo` và cạnh `kiemGiong`.
///
/// `kiemSo` chặn *số bịa*. Hàm này chặn *tên bịa cho một số thật*: đo trên máy
/// thật 2026-09-22 (mục 9.5 `AI_EDGE_FEATURE.md`), mô hình nói *"Tỉ lệ phân
/// bổ là 85,4%"* trong khi gói gọi con số ấy là `Để dành` — mọi số đều thật
/// nên mọi chốt đều cho qua, và người đọc tin một đại lượng không tồn tại.
///
/// Luật: với **mỗi** con số trong câu, tìm các nhãn gói khớp nó (mượn phép
/// khớp của `kiemSo` qua `soLieuKhop`), rồi đòi câu chứa **mọi âm tiết có
/// nghĩa** của **ít nhất một** nhãn ấy — thứ tự tự do, chen chữ tự do.
///
/// ⚠️ Từ khoá suy **từ nhãn lúc chạy**, không ghi cứng chữ nào ở đây: test
/// quét thứ 14 cấm `ai_edge/` chứa chuỗi chiều tiền, và một danh sách từ khoá
/// chép tay sẽ lệch với gói ngay khi ai đó đổi một nhãn.
///
/// Giới hạn cố ý: đây là phép lọc từ vựng như `kiemGiong`, không hiểu nghĩa.
/// Câu đúng nhưng diễn đạt xa nhãn (*"bạn tiêu 2.141.000 đ"* không có chữ
/// *chi*) bị chặn — sai theo chiều **an toàn**, và few-shot của prompt hỏi
/// đáp dạy mô hình chép nhãn nên ca ấy hiếm.
library;

import 'goi_so.dart';
import 'kiem_so.dart';

/// Âm tiết xuất hiện ở nhiều nhãn mà không nói con số là gì: `Tổng chi` và
/// `Tổng thu` cùng có "tổng", nên "tổng" khớp được là gán nhầm chi thành thu.
const List<String> kAmTietChung = ['tổng', 'số', 'đã', 'so', 'với', 'là'];

/// Âm tiết có nghĩa của [nhan], chữ thường. Nhãn chỉ toàn âm tiết chung thì
/// giữ nguyên nhãn — không có nhãn nào rỗng từ khoá.
List<String> tuKhoaNhan(String nhan) {
  final amTiet = nhan
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final coNghia = amTiet.where((t) => !kAmTietChung.contains(t)).toList();
  return coNghia.isEmpty ? amTiet : coNghia;
}

/// Tập âm tiết của [cau] — chữ thường, tách ở mọi ký tự không phải chữ.
/// ⚠️ So theo **âm tiết**, không theo chuỗi con: "chiều" chứa "chi" mà không
/// phải chữ "chi".
Set<String> _amTietCua(String cau) => cau
    .toLowerCase()
    .split(RegExp(r'[^\p{L}]+', unicode: true))
    .where((t) => t.isNotEmpty)
    .toSet();

/// `true` khi mọi số trong [cau] đứng cùng câu với đủ từ khoá của một nhãn
/// gói khớp nó. Câu không có số thì lọt — không có nhãn nào để gán sai.
bool kiemNhan(String cau, List<GoiSo> goi) {
  final amTiet = _amTietCua(cau);
  for (final x in trichSo(cau)) {
    final nhans = soLieuKhop(x, goi);
    if (nhans.isEmpty) return false;
    final coNhanDung = nhans.any(
      (s) => tuKhoaNhan(s.nhan).every(amTiet.contains),
    );
    if (!coNhanDung) return false;
  }
  return true;
}
