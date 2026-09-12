/// Bốn giá trị của `bills.payStatus`, và ba câu hỏi rút ra từ chúng.
///
/// **Đây là định nghĩa duy nhất.** Trước 2026-09-12, câu "đã trả chưa" được
/// chép tay ở 10 chỗ thuộc 7 tệp (đếm bằng script); ba trong số đó tình cờ
/// đúng với giá trị `'Skipped'` mới do may chứ không do thiết kế.
///
/// Dart **thuần**, không import Flutter, để `core/` dùng được — cùng lý do và
/// cùng khuôn với `features/wallet/domain/wallet_type.dart`, thứ mà
/// `core/sync/sync_payload_normalizer.dart` đang import.
///
/// Bốn hằng chuỗi tồn tại vì `BillDao.getUpcoming` và `BillDao.markOverdue` là
/// **truy vấn SQL** — chúng không gọi được vị từ Dart, chỉ dùng được hằng.
///
/// ⚠️ PostgreSQL có `chk_bill_pay_status` chỉ nhận đúng bốn chuỗi này, và cột
/// `bill."Pay_status"` là `varchar(7)` (đo 2026-09-12). Giá trị thứ năm lọt lên
/// là hoá đơn **kẹt hàng đợi đẩy vĩnh viễn, im lặng** — cùng loại hỏng với
/// `ewallet`/`debt` của bảng ví ngày trước.
library;

import '../../../core/database/app_database.dart';

/// Chờ trả.
const kBillPending = 'Pending';

/// Đã trả — chú ý backend viết `Payed`, không phải `Paid`.
const kBillPayed = 'Payed';

/// Đã trễ hạn mà chưa trả. `BillDao.markOverdue` gắn và gỡ cờ này.
const kBillOverdue = 'Overdue';

/// Người dùng chủ động bỏ qua kỳ này: không trả, và **không tính là nợ**.
const kBillSkipped = 'Skipped';

/// Kỳ này đã sinh ra một khoản chi chưa.
///
/// Đọc **cả hai** cột: hàng kéo về từ backend chỉ mang `pay_status` (cột
/// `isPaid` là cục bộ), còn hàng do bản client cũ ghi thì chỉ đặt `isPaid`.
/// Đọc một cột thôi là hỏng im lặng theo cả hai chiều.
///
/// Dùng cho: hoàn tác thanh toán, dòng "Trả dd/MM", tra `transactions.billId`.
bool daCoKhoanChi(Bill bill) => bill.isPaid || bill.payStatus == kBillPayed;

/// Kỳ này có bị bỏ qua không.
///
/// **Không** đoán rộng ra giá trị khác: một chuỗi lạ chỉ nghĩa là client chưa
/// biết, không nghĩa là người dùng đã bỏ qua.
bool daBoQua(Bill bill) => bill.payStatus == kBillSkipped;

/// Kỳ này còn là tiền phải trả không.
///
/// Dùng cho: nhắc nhở, tự động thanh toán, tổng nợ ở thẻ đầu trang,
/// `getUpcoming`.
///
/// Giá trị lạ đọc là **còn phải trả**: thà giục nhầm còn hơn im lặng giấu mất
/// một khoản nợ thật.
bool conPhaiTra(Bill bill) => !daCoKhoanChi(bill) && !daBoQua(bill);
