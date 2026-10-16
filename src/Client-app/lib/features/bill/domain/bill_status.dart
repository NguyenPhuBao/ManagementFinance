/// Trạng thái hiển thị của hoá đơn, và số liệu thẻ tổng đầu trang.
///
/// Tách khỏi `bill_page.dart` vì trang đó tính cả hai ngay trong `build` và
/// tính sai ở bốn chỗ cùng lúc: hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN
/// HẠN" với vạch màu xanh lá của khoản thu, hoá đơn thật sự sắp đến hạn không
/// có nhãn riêng, thanh tiến độ là hằng số `0.66`, và tổng tiền gộp cả kỳ của
/// tháng sau.
library;

import '../data/models/bill_entity.dart';
import 'bill_nhac_truoc.dart';
import 'bill_pay_status.dart';

/// Năm trạng thái một hoá đơn có thể mang trên danh sách.
///
/// Bản dựng hình Stitch ban đầu chỉ vẽ ba (*Sắp đến hạn* / *Chưa thanh toán* /
/// *ĐÃ THANH TOÁN*) vì lúc ấy chưa có trạng thái quá hạn ở đâu. Nhãn thứ tư là
/// `overdue`, để nói đúng `payStatus = 'Overdue'` có từ 2026-09-04. Nhãn thứ
/// năm là `skipped` (2026-09-12) — kỳ người dùng chủ động bỏ qua: không trả
/// tiền, và **không phải nợ**.
///
/// Phép đọc "đã trả chưa" nay nằm ở `bill_pay_status.dart`, một chỗ duy nhất
/// cho cả app; hàm `_daTra` cũ của tệp này là một trong mười bản chép tay.
enum BillDisplayStatus { paid, skipped, overdue, dueSoon, pending }

DateTime _dauNgay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Trạng thái hiển thị của [bill] tại thời điểm [now].
///
/// So theo **NGÀY**, cùng quy ước với `BillDao.markOverdue`: hoá đơn đến hạn
/// đúng hôm nay chưa phải quá hạn, người dùng vẫn còn cả ngày để trả.
///
/// Ngưỡng "sắp đến hạn" lấy từ [billLeadDays] (`bill_nhac_truoc.dart`) —
/// **cùng một định nghĩa** bộ luật thông báo dùng cho dải nhắc. Hai mốc riêng thì dải nhắc và nhãn trên danh sách nói hai
/// chuyện khác nhau về cùng một hoá đơn.
BillDisplayStatus billDisplayStatusOf(BillEntity bill, DateTime now) {
  if (daCoKhoanChi(bill)) return BillDisplayStatus.paid;
  // TRƯỚC mọi phép so ngày: một kỳ bỏ qua đã trễ hạn vẫn là kỳ bỏ qua, không
  // phải kỳ quá hạn. Đặt nhánh này sau là hiện nhãn đỏ "QUÁ HẠN" cho một
  // quyết định người dùng đã chủ động ra.
  if (daBoQua(bill)) return BillDisplayStatus.skipped;

  final homNay = _dauNgay(now);
  final han = _dauNgay(bill.dueDate);

  if (han.isBefore(homNay)) return BillDisplayStatus.overdue;

  final soNgay = billLeadDays(bill);
  // `DateTime(y, m, d + n)` tự chuẩn hoá qua biên tháng, khỏi phải cộng
  // `Duration` rồi lo chuyện giờ.
  final motNguong = DateTime(homNay.year, homNay.month, homNay.day + soNgay);
  return han.isAfter(motNguong)
      ? BillDisplayStatus.pending
      : BillDisplayStatus.dueSoon;
}

/// Hoá đơn [bill] có thuộc **kỳ này** của [now] không: hạn trước đầu tháng
/// sau, **kể cả** nợ quá hạn từ những tháng trước.
///
/// Định nghĩa duy nhất cho cả thẻ tổng ([summarizeBills]) lẫn số trên tab
/// "Cần thanh toán" ([splitBills]). Hai chỗ từng dùng hai luật: tab đếm mọi kỳ
/// chưa đóng, mà `payBill` sinh ngay kỳ tháng sau mỗi lần trả một hoá đơn lặp
/// — nên tab nói (4) khi thẻ nói "3 hóa đơn" (người dùng chốt 2026-10-16).
///
/// Vì sao chặn ở đầu tháng sau: thẻ nói "Tổng tiền cần thanh toán", nên nó
/// phải là số phải trả trong kỳ. Gộp cả kỳ tháng sau làm con số to lên vô cớ —
/// trên máy thật nó hiện 183.000 đ trong khi tháng này chỉ nợ 60.000 đ.
///
/// Vì sao **không** chặn ở đầu tháng: nợ cũ chưa trả vẫn là tiền phải trả.
/// Cắt nó ra là giấu đúng khoản đáng lo nhất.
bool thuocKyNay(BillEntity bill, DateTime now) =>
    // Đầu tháng SAU, biên mở. `DateTime(y, m + 1, 1)` tự sang năm mới khi m = 12.
    bill.dueDate.isBefore(DateTime(now.year, now.month + 1, 1));

/// Các nhóm của danh sách hoá đơn: tab thứ nhất có hai nhóm, tab thứ hai một.
class BillSections {
  /// Còn phải trả trong **kỳ này** ([thuocKyNay]) — hạn gần nhất lên đầu, nên
  /// hoá đơn quá hạn nằm trên cùng. Số trên tab "Cần thanh toán" đếm nhóm này,
  /// nên nó luôn bằng `BillSummary.unpaidCount` của thẻ tổng.
  final List<BillEntity> chuaDong;

  /// Còn phải trả nhưng hạn từ đầu tháng sau trở đi — thường là kỳ `payBill`
  /// vừa sinh sẵn. Vẫn hiện trong tab thứ nhất (trả trước được), dưới tiêu đề
  /// nhóm riêng, và **không** vào số trên tab. Hạn gần nhất lên đầu.
  final List<BillEntity> chuaDongCacThangSau;

  /// Đã đóng sổ: kỳ đã trả **và** kỳ đã bỏ qua. Kỳ mới nhất lên đầu.
  ///
  /// Tên trường cố ý **không** phải `paid`: từ 2026-09-12 nhóm này chứa cả kỳ
  /// chưa hề được trả đồng nào. Tab hiển thị nó cũng đổi tên theo, từ "Đã
  /// thanh toán" sang "Lịch sử", vì cùng lý do.
  final List<BillEntity> daDong;

  const BillSections({
    this.chuaDong = const [],
    this.chuaDongCacThangSau = const [],
    this.daDong = const [],
  });
}

/// Chia [bills] thành các nhóm cho hai tab, theo kỳ của [now].
///
/// Vì sao cần: mỗi kỳ của một hoá đơn lặp là **một hàng mới** với UUID riêng,
/// và danh sách phẳng xếp theo hạn nên lịch sử đã trả nằm lẫn vào giữa những
/// hoá đơn đang chờ. Trên máy thật đã thấy: kỳ đã trả của "di h0c" nằm giữa
/// hai hoá đơn chưa trả. Hoá đơn tuần sinh 52 hàng mỗi năm.
///
/// **Không sắp xếp tại chỗ**: danh sách đến từ stream của bloc và nhiều nơi
/// khác đang đọc chung nó.
BillSections splitBills(List<BillEntity> bills, DateTime now) {
  final chuaDong = <BillEntity>[];
  final cacThangSau = <BillEntity>[];
  final daDong = <BillEntity>[];
  for (final b in bills) {
    if (!conPhaiTra(b)) {
      daDong.add(b);
    } else {
      (thuocKyNay(b, now) ? chuaDong : cacThangSau).add(b);
    }
  }
  chuaDong.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  cacThangSau.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  daDong.sort((a, b) => b.dueDate.compareTo(a.dueDate));
  return BillSections(
      chuaDong: chuaDong, chuaDongCacThangSau: cacThangSau, daDong: daDong);
}

/// Số liệu thẻ tổng đầu trang hoá đơn, tính cho **kỳ này**.
class BillSummary {
  /// Tiền còn phải trả trong kỳ.
  final double unpaidAmount;

  /// Số hoá đơn còn phải trả trong kỳ.
  final int unpaidCount;

  /// Tiền đã trả trong kỳ — mẫu số của [progress].
  final double paidAmount;

  final int paidCount;

  const BillSummary({
    this.unpaidAmount = 0,
    this.unpaidCount = 0,
    this.paidAmount = 0,
    this.paidCount = 0,
  });

  /// Tỉ lệ tiền đã trả trên tổng phải trả trong kỳ, `0` khi kỳ chưa có hoá đơn.
  ///
  /// Trước đây thanh này là hằng số `0.66`, tức chỉ có hai trạng thái 66% hoặc
  /// 0%. Một thanh không đo gì tệ hơn không có thanh.
  double get progress {
    final tong = paidAmount + unpaidAmount;
    return tong <= 0 ? 0 : paidAmount / tong;
  }
}

/// Gộp [bills] thành số liệu của **kỳ này** ([thuocKyNay]): mọi hoá đơn đến
/// hạn từ nay tới hết tháng của [now], **kể cả** hoá đơn quá hạn từ những
/// tháng trước. Lý do của hai biên ở docstring của [thuocKyNay].
BillSummary summarizeBills(List<BillEntity> bills, DateTime now) {
  var unpaidAmount = 0.0;
  var unpaidCount = 0;
  var paidAmount = 0.0;
  var paidCount = 0;

  for (final b in bills) {
    if (!thuocKyNay(b, now)) continue;
    // Kỳ bỏ qua không vào vế nào: không phải nợ, cũng không phải tiền đã chi.
    // Cộng vào `paidAmount` là thổi phồng thanh tiến độ bằng tiền chưa từng
    // chi ra — cùng loại lỗi với thanh hằng số 0,66, chỉ tinh vi hơn.
    if (daBoQua(b)) continue;
    if (daCoKhoanChi(b)) {
      paidAmount += b.amount;
      paidCount++;
    } else {
      unpaidAmount += b.amount;
      unpaidCount++;
    }
  }

  return BillSummary(
    unpaidAmount: unpaidAmount,
    unpaidCount: unpaidCount,
    paidAmount: paidAmount,
    paidCount: paidCount,
  );
}
