/// Phần **quyết định** của tự động thanh toán hoá đơn.
///
/// Toàn bộ tệp này là hàm thuần: không Drift, không Flutter, không đồng hồ hệ
/// thống. Việc *ghi* nằm ở `BillAutoPayRunner`, việc *báo* nằm ở
/// `notification_rules.dart`. Tách ra vì đây là chỗ **thứ hai** trong app tự ý
/// chuyển tiền của người dùng khi họ không có mặt (chỗ đầu là trích tiền mục
/// tiêu, `goal_auto_deposit.dart`) — mọi luật về *dừng đúng lúc* phải test
/// được mà không cần dựng CSDL.
///
/// ## Khác gì với trích tiền mục tiêu
///
/// Mục tiêu là **một hàng sống lâu** nên cần "mốc chạy gần nhất" làm sàn và
/// một vòng dò kỳ. Hoá đơn thì **mỗi kỳ là một hàng riêng**, sinh ra lúc trả
/// kỳ trước, nên:
///
/// - Chốt chống trả hai lần là chính cờ đã trả (`isPaid`/`payStatus`).
/// - "Kỳ đến hạn" là một câu hỏi về **một hàng**: hạn của nó đã tới chưa.
/// - Trả bù nhiều kỳ là trả hàng này, rồi nhìn kỳ kế tiếp vừa sinh ra.
library;

import '../../../core/database/app_database.dart';

/// Dòng phụ hiện dưới công tắc khi bật, dùng chung cho form Thêm và Sửa.
///
/// Ba điều người dùng cần biết trước khi uỷ quyền: trừ ví nào, lúc nào (bộ
/// chạy chỉ chạy khi app mở), và vì sao chỉ nên bật trên một thiết bị (cột
/// cục bộ — hai máy cùng bật, cùng offline, cùng trả một kỳ là hai khoản chi).
const String kBillAutoPayHint =
    'Khi bạn mở app vào ngày đến hạn, hoá đơn được trả từ ví thanh toán ở '
    'trên và ghi thành một khoản chi. Kỳ bỏ lỡ được trả bù, tối đa 3 kỳ mỗi '
    'lần. Chỉ nên bật trên một thiết bị.';

/// Trần số kỳ trả cho **mỗi hoá đơn** trong một lượt chạy.
///
/// Bỏ app nửa năm thì sáu tháng tiền điện trả một lúc là rút cạn ví ngay khi
/// mở app. Phần dư **không mất** — kỳ chưa trả vẫn nằm đó, lượt sau xử lý.
const int tranKyTuTraMoiLuot = 3;

DateTime _dauNgay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Hoá đơn này có đến lượt tự trả tại [now] không.
///
/// So theo **NGÀY** — cùng quy ước với `BillDao.markOverdue` và
/// `billDisplayStatusOf`. So DateTime thô thì cùng một hoá đơn trả hay không
/// tuỳ vào giờ người dùng mở app: hỏng ngẫu nhiên và rất khó lần ra. Người
/// dùng đã chốt "bất kỳ lúc nào trong ngày đến hạn", nên lượt quét đầu tiên
/// từ 00:00 là trả.
///
/// Đọc **cả hai** cột trạng thái: hàng do bản client cũ ghi hoặc kéo về từ
/// backend có thể mang `payStatus = 'Payed'` với `isPaid` còn false, và trả
/// một hoá đơn đã trả là trừ tiền hai lần.
///
/// Thiếu ví hoặc danh mục thì không chạy: khoản chi sinh ra sẽ bị `/sync/push`
/// từ chối ở mọi chu kỳ và kẹt hàng đợi đẩy (quy tắc 4 `CLAUDE.md`).
bool denLuotTuTra(Bill bill, DateTime now) {
  if (!bill.autoPayEnabled) return false;
  if (bill.isDeleted) return false;
  if (bill.isPaid || bill.payStatus == 'Payed') return false;
  if (bill.walletId == null || bill.categoryId == null) return false;
  return !_dauNgay(bill.dueDate).isAfter(_dauNgay(now));
}

/// Chuyện gì xảy ra với một kỳ tự trả.
enum LoaiTuTra {
  /// Trả đủ số ghi trên hoá đơn.
  traDu,

  /// Ví không đủ tiền. **Không** trả gì cả; kỳ vẫn mở, lượt sau tự thử lại.
  viKhongDu,

  /// Không chạy được vì cấu hình hỏng — số tiền không dương, ví đã bị xoá,
  /// hoặc đường trả ném lỗi.
  khongChayDuoc,
}

class QuyetDinhTuTra {
  const QuyetDinhTuTra(this.loai, this.soTien);

  final LoaiTuTra loai;

  /// Số tiền thật sự chuyển. Bằng 0 với mọi nhánh không trả.
  final double soTien;
}

/// Trả bao nhiêu cho **một** kỳ.
///
/// Số tiền là đúng số ghi trên hoá đơn — không có "phần còn thiếu" như mục
/// tiêu, vì một hoá đơn hoặc trả hết hoặc chưa trả.
///
/// ## Vì sao ví thiếu tiền thì bỏ hẳn kỳ, không trả một phần
///
/// Trả một phần làm một kỳ ra hai con số trong sổ sách mà vẫn không hết nợ.
/// Bỏ kỳ đó và **báo**; nơi gọi không đổi gì nên kỳ ấy tự thử lại khi ví có
/// tiền. Số dư 0 sau khi trả là hợp lệ, chỉ số dư âm mới sai.
QuyetDinhTuTra quyetDinhTuTra({
  required double soTien,
  required double soDuVi,
}) {
  if (soTien <= 0) return const QuyetDinhTuTra(LoaiTuTra.khongChayDuoc, 0);
  if (soDuVi < soTien) return const QuyetDinhTuTra(LoaiTuTra.viKhongDu, 0);
  return QuyetDinhTuTra(LoaiTuTra.traDu, soTien);
}

/// Khoá định danh một kỳ tự trả của một hoá đơn — đi thẳng vào `dedupeKey`
/// của bộ luật thông báo.
///
/// Mỗi kỳ là một hàng riêng nên `id` + ngày đến hạn là đủ. Gộp theo lượt
/// quét thì mỗi lần mở app lại thêm một "Đã tự trả" cho việc chỉ xảy ra một
/// lần; không gộp gì thì ví thiếu tiền bắn một thông báo ở mỗi lượt quét.
String khoaKyTuTra(String billId, DateTime dueDate) =>
    '$billId:${dueDate.year.toString().padLeft(4, '0')}-'
    '${dueDate.month.toString().padLeft(2, '0')}-'
    '${dueDate.day.toString().padLeft(2, '0')}';
