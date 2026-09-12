/// Ân hạn hoá đơn — số ngày giữa NGÀY KẾT THÚC KỲ (`Bills.periodEnd`) và HẠN
/// TRẢ (`Bills.dueDate`).
///
/// Con số này **không lưu** trong bảng: nó suy từ hai cột, và đây là chỗ DUY
/// NHẤT làm phép suy ấy. Lý do không thêm cột thứ ba: hai nguồn sự thật cho
/// một con số sẽ lệch nhau ngay lần đầu có hàng kéo về từ máy khác.
///
/// Spec: docs/superpowers/specs/2026-09-12-bill-an-han-period-end-design.md §4.1
library;

import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';

/// Trần ân hạn, chặn gõ nhầm (ô nhập lọc 3 chữ số).
const int kAnHanToiDa = 365;

/// Bốn gợi ý trên thanh chọn của form; "Khác" mở ô nhập số.
const List<int> kAnHanGoiY = [0, 7, 15, 30];

DateTime _dauNgay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số ngày lịch từ [ketThucKy] tới [hanTra]. Âm (dữ liệu hỏng) → 0.
///
/// Tính theo NGÀY, không theo mili-giây: hàng kéo về từ server mang 00:00 UTC
/// còn hàng ghi tại chỗ mang giờ máy, trừ thô rồi `inDays` sẽ thiếu một ngày.
int anHanTuMoc({required DateTime ketThucKy, required DateTime hanTra}) {
  final n = _dauNgay(hanTra).difference(_dauNgay(ketThucKy)).inDays;
  return n < 0 ? 0 : n;
}

/// Ân hạn của một hàng. `periodEnd` NULL = hàng cũ, kết thúc kỳ trùng hạn trả → 0.
int anHanCua(Bill b) {
  final ketThuc = b.periodEnd;
  if (ketThuc == null) return 0;
  return anHanTuMoc(ketThucKy: ketThuc, hanTra: b.dueDate);
}

/// Hạn trả = [ketThucKy] + [anHanNgay] ngày lịch, **giữ nguyên giờ phút giây**
/// của mốc gốc. Với 0 ngày trả về đúng [ketThucKy] — ân hạn 0 phải cho kết quả
/// y hệt trước v21, kể cả phần giờ mà `nextBillDueDate` đang giữ lại.
DateTime hanTraTu(DateTime ketThucKy, int anHanNgay) {
  if (anHanNgay == 0) return ketThucKy;
  final k = ketThucKy;
  return DateTime(k.year, k.month, k.day + anHanNgay, k.hour, k.minute,
      k.second, k.millisecond, k.microsecond);
}

/// Lý do từ chối một số ngày ân hạn, hoặc `null` khi hợp lệ.
///
/// Luật (c) — hạn trả phải TRƯỚC ngày kết thúc kỳ kế tiếp — là chốt chống hai
/// kỳ cùng mở: ân hạn 45 ngày cho chu kỳ tháng nghĩa là kỳ 2 đã bắt đầu và kết
/// thúc khi kỳ 1 còn chưa tới hạn; bộ tự động thanh toán và thẻ tổng sẽ đếm
/// hai khoản cùng lúc. Với chu kỳ tuần luật này giới hạn ở 6 ngày — đúng ý.
String? loiAnHan({
  required int anHanNgay,
  required DateTime ketThucKy,
  required DateTime ketThucKyKeTiep,
}) {
  if (anHanNgay < 0) return 'Số ngày ân hạn không được âm';
  if (anHanNgay > kAnHanToiDa) return 'Ân hạn tối đa $kAnHanToiDa ngày';
  final hanTra = _dauNgay(hanTraTu(ketThucKy, anHanNgay));
  if (!hanTra.isBefore(_dauNgay(ketThucKyKeTiep))) {
    return 'Hạn trả phải trước ngày kết thúc kỳ kế tiếp '
        '(${DateFormat('dd/MM').format(ketThucKyKeTiep)})';
  }
  return null;
}
