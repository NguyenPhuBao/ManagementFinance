/// Kỳ kế tiếp của một hoá đơn — **phép tính ngày**, tách khỏi việc dựng hàng.
///
/// Đây là **định nghĩa duy nhất** (2026-09-16). Hai nơi dùng:
/// - `BillRepositoryImpl._nextPeriodOf` — sinh hàng thật khi trả/bỏ qua kỳ;
/// - `analytics/domain/du_bao_dong_tien.dart` — chiếu kỳ tương lai cho dự
///   báo 30 ngày, KHÔNG ghi gì.
///
/// Trước ngày ấy phép này nằm trộn trong `_nextPeriodOf` cùng với việc dựng
/// `BillsCompanion`, nên dự báo muốn chiếu kỳ thì phải chép lại — và bản chép
/// sẽ lệch ở lần sửa sau, im lặng. Hai bẫy đã vấp thật mà tệp này giữ:
///
/// - Kỳ sau bắt đầu tại **NGÀY KẾT THÚC KỲ** (`periodEnd`), không phải hạn
///   trả: với ân hạn 15 ngày, nối từ hạn trả là hở nửa tháng và mỗi kỳ trôi
///   thêm. Hàng cũ (`periodEnd` NULL) thì hai mốc trùng nhau.
/// - **Ngày gốc** (`anchorDay`) đi theo cả chuỗi và **không cộng dồn**: kỳ
///   31/01 kẹp về 28/02 rồi bước tiếp *từ 28* là nhịp tụt xuống 28 vĩnh viễn.
///   Xem `core/bill/bill_recurrence.dart`.
library;

import '../../../core/bill/bill_recurrence.dart';
import '../../../core/database/app_database.dart';
import 'bill_an_han.dart';

/// Ba mốc của kỳ kế tiếp, cộng ngày gốc để kỳ sau nữa neo tiếp.
class KyKeTiep {
  /// Ngày bắt đầu kỳ sau = ngày kết thúc kỳ hiện tại.
  final DateTime batDau;

  /// Ngày kết thúc kỳ tính tiền của kỳ sau (`periodEnd` của hàng sẽ sinh).
  final DateTime ketThuc;

  /// Hạn trả kỳ sau = [ketThuc] + ân hạn (suy từ kỳ hiện tại).
  final DateTime hanTra;

  /// Ngày gốc dùng cho kỳ sau — chính ngày gốc của kỳ hiện tại, hoặc ngày
  /// của [batDau] khi hàng cũ chưa có.
  final int anchorDay;

  const KyKeTiep({
    required this.batDau,
    required this.ketThuc,
    required this.hanTra,
    required this.anchorDay,
  });
}

/// Kỳ kế tiếp của [current]. Không đọc đồng hồ, không ghi gì.
KyKeTiep kyKeTiepCua(Bill current) {
  // Kỳ sau bắt đầu tại NGÀY KẾT THÚC KỲ, không phải hạn trả — bẫy §4.4 tài
  // liệu xin backend. Hàng cũ (periodEnd NULL) thì hai mốc trùng nhau, kết quả
  // y hệt trước v21.
  final batDau = current.periodEnd ?? current.dueDate;
  // Ngày gốc đi theo cả chuỗi. Kỳ cũ chưa có (tạo trước v18, hoặc kéo từ
  // server) thì neo vào mốc hiện tại — giữ hành vi cũ thay vì đoán.
  final goc = current.anchorDay ?? batDau.day;
  final ketThuc = nextBillDueDate(
    batDau,
    current.timeRecurrence,
    anchorDay: goc,
  );
  // Ân hạn đi theo chuỗi mà không cần cột riêng: suy từ kỳ hiện tại.
  final anHan = anHanCua(current);
  return KyKeTiep(
    batDau: batDau,
    ketThuc: ketThuc,
    hanTra: hanTraTu(ketThuc, anHan),
    anchorDay: goc,
  );
}
