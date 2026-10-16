/// Số ngày nhắc trước hạn của hoá đơn, và mốc mặc định khi hoá đơn không nói gì.
///
/// Ở mảng hoá đơn vì hàm đọc cột `bill.timeNotification` và hằng khớp mặc định
/// của cột `Time_notification` phía backend — cả hai là chuyện của hoá đơn. Bộ
/// luật thông báo (dải nhắc) và trạng thái hiển thị hoá đơn (`bill_status.dart`)
/// cùng đọc nên đây là **một định nghĩa**, không mốc thứ hai. Trước đây hai thứ
/// này nằm ở `notification_rules.dart`, làm hai mảng `bill` và `notification`
/// phụ thuộc nhau hai chiều ở tầng `domain/`; gỡ ngày 2026-10-16.
library;

import '../data/models/bill_entity.dart';

/// Số ngày nhắc trước hạn khi cả hoá đơn lẫn tuỳ chọn đều không nói gì.
///
/// Khớp `@default("3")` của cột `Time_notification` phía backend, để một hoá
/// đơn tạo ở client và một hoá đơn tạo ở nơi khác hành xử như nhau.
const int mocNhacMacDinh = 3;

/// Số ngày nhắc trước hạn thật sự dùng cho [bill].
///
/// Giá trị đặt riêng cho một hoá đơn **thắng** giá trị mặc định chung: nó là
/// lựa chọn cụ thể hơn.
int billLeadDays(BillEntity bill, {int fallback = mocNhacMacDinh}) =>
    int.tryParse(bill.timeNotification ?? '') ?? fallback;
