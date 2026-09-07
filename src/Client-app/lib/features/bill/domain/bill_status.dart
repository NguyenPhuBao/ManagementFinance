/// Trạng thái hiển thị của hoá đơn, và số liệu thẻ tổng đầu trang.
///
/// Tách khỏi `bill_page.dart` vì trang đó tính cả hai ngay trong `build` và
/// tính sai ở bốn chỗ cùng lúc: hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN
/// HẠN" với vạch màu xanh lá của khoản thu, hoá đơn thật sự sắp đến hạn không
/// có nhãn riêng, thanh tiến độ là hằng số `0.66`, và tổng tiền gộp cả kỳ của
/// tháng sau.
library;

import '../../../core/database/app_database.dart';
import '../../../core/notification/notification_rules.dart';

/// Bốn trạng thái một hoá đơn có thể mang trên danh sách.
///
/// Bản dựng hình Stitch chỉ vẽ ba (*Sắp đến hạn* / *Chưa thanh toán* / *ĐÃ
/// THANH TOÁN*) vì lúc ấy chưa có trạng thái quá hạn ở đâu. Cột `payStatus`
/// thì có `'Overdue'` từ 2026-09-04, nên nhãn thứ tư là để nói đúng nó.
enum BillDisplayStatus { paid, overdue, dueSoon, pending }

/// Đã thanh toán chưa — đọc **cả hai** cột.
///
/// `markPaid()` đặt cả hai, nhưng hàng do bản client cũ ghi có thể lệch:
/// mang `payStatus = 'Payed'` trong khi `isPaid` còn false. `getUpcoming` đã
/// lọc cả hai từ 2026-09-04; danh sách thì tới 06/09 mới theo kịp, nên trước
/// đó nó bày nút "Thanh toán" cho hoá đơn đã trả và cộng luôn vào tổng nợ.
bool _daTra(Bill bill) => bill.isPaid || bill.payStatus == 'Payed';

DateTime _dauNgay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Trạng thái hiển thị của [bill] tại thời điểm [now].
///
/// So theo **NGÀY**, cùng quy ước với `BillDao.markOverdue`: hoá đơn đến hạn
/// đúng hôm nay chưa phải quá hạn, người dùng vẫn còn cả ngày để trả.
///
/// Ngưỡng "sắp đến hạn" lấy từ [billLeadDays] — **cùng một định nghĩa** với bộ
/// luật thông báo. Hai mốc riêng thì dải nhắc và nhãn trên danh sách nói hai
/// chuyện khác nhau về cùng một hoá đơn.
BillDisplayStatus billDisplayStatusOf(Bill bill, DateTime now) {
  if (_daTra(bill)) return BillDisplayStatus.paid;

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

/// Hai nhóm của danh sách hoá đơn, tương ứng hai tab.
class BillSections {
  /// Còn phải trả — hạn gần nhất lên đầu, nên hoá đơn quá hạn nằm trên cùng.
  final List<Bill> unpaid;

  /// Lịch sử đã trả — kỳ mới nhất lên đầu.
  final List<Bill> paid;

  const BillSections({this.unpaid = const [], this.paid = const []});
}

/// Chia [bills] thành hai nhóm cho hai tab.
///
/// Vì sao cần: mỗi kỳ của một hoá đơn lặp là **một hàng mới** với UUID riêng,
/// và danh sách phẳng xếp theo hạn nên lịch sử đã trả nằm lẫn vào giữa những
/// hoá đơn đang chờ. Trên máy thật đã thấy: kỳ đã trả của "di h0c" nằm giữa
/// hai hoá đơn chưa trả. Hoá đơn tuần sinh 52 hàng mỗi năm.
///
/// **Không sắp xếp tại chỗ**: danh sách đến từ stream của bloc và nhiều nơi
/// khác đang đọc chung nó.
BillSections splitBills(List<Bill> bills) {
  final unpaid = <Bill>[];
  final paid = <Bill>[];
  for (final b in bills) {
    (_daTra(b) ? paid : unpaid).add(b);
  }
  unpaid.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  paid.sort((a, b) => b.dueDate.compareTo(a.dueDate));
  return BillSections(unpaid: unpaid, paid: paid);
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

/// Gộp [bills] thành số liệu của **kỳ này**: mọi hoá đơn đến hạn từ nay tới
/// hết tháng của [now], **kể cả** hoá đơn quá hạn từ những tháng trước.
///
/// Vì sao chặn ở cuối tháng: thẻ nói "Tổng tiền cần thanh toán", nên nó phải
/// là số phải trả trong kỳ. Gộp cả kỳ tháng sau làm con số to lên vô cớ — trên
/// máy thật nó hiện 183.000 đ trong khi tháng này chỉ nợ 60.000 đ.
///
/// Vì sao **không** chặn ở đầu tháng: nợ cũ chưa trả vẫn là tiền phải trả.
/// Cắt nó ra khỏi thẻ là giấu đúng khoản đáng lo nhất.
BillSummary summarizeBills(List<Bill> bills, DateTime now) {
  // Đầu tháng SAU. `DateTime(y, m + 1, 1)` tự sang năm mới khi m = 12.
  final cuoiKy = DateTime(now.year, now.month + 1, 1);

  var unpaidAmount = 0.0;
  var unpaidCount = 0;
  var paidAmount = 0.0;
  var paidCount = 0;

  for (final b in bills) {
    if (!b.dueDate.isBefore(cuoiKy)) continue;
    if (_daTra(b)) {
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
