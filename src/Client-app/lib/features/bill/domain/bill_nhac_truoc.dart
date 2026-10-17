/// Số ngày nhắc trước hạn của hoá đơn, và mốc mặc định của nhãn "Sắp đến hạn".
///
/// Ở mảng hoá đơn vì hàm đọc cột `bill.timeNotification` và hằng khớp mặc định
/// của cột `Time_notification` phía backend — cả hai là chuyện của hoá đơn. Ba
/// nơi đọc: trạng thái hiển thị hoá đơn (`bill_status.dart`), bộ luật thông báo và bộ
/// đặt lịch nhắc hệ điều hành.
///
/// `timeNotification` NULL nghĩa là **tắt nhắc** — form Thêm hoá đơn ghi NULL khi tắt
/// công tắc "Nhắc trước hạn", màn Chi tiết và sheet Thanh toán hiện "Không nhắc" (mục 7b
/// `BILL_DOCUMENTATION.md`). Bộ nhắc đọc qua [soNgayNhacRieng] và bỏ hoá đơn tắt nhắc;
/// nhãn đọc qua [billLeadDays] với mặc định là tuỳ chọn "Nhắc trước" của Cài đặt thông
/// báo, vì hoá đơn tắt nhắc vẫn cần một ngưỡng để hiện "Sắp đến hạn". Trước 2026-10-16
/// bộ nhắc đọc NULL thành "theo tuỳ chọn chung" nên hoá đơn đã tắt nhắc vẫn bị nhắc,
/// còn nhãn dùng mốc 3 cố định — người dùng chốt "tắt là tắt thật". Từ 2026-10-17 tuỳ
/// chọn ấy còn là mặc định cho hoá đơn mới — form Thêm chọn sẵn chip qua [mucNhacChonSan].
///
/// Trước đây hàm và hằng ở `notification_rules.dart`, làm hai mảng `bill` và
/// `notification` phụ thuộc nhau hai chiều ở tầng `domain/`; gỡ ngày 2026-10-16.
library;

import '../data/models/bill_entity.dart';

/// Mốc "sắp đến hạn" khi nơi gọi không truyền mặc định nào.
///
/// Khớp `@default("3")` của cột `Time_notification` phía backend và mặc định
/// của tuỳ chọn "Nhắc trước" (`NotificationPrefs`).
const int mocNhacMacDinh = 3;

/// Số ngày nhắc trước hạn người dùng đặt riêng cho [bill]; `null` là **tắt nhắc**.
///
/// Giá trị không đọc được (chuỗi rỗng, chữ lạ) cũng là tắt nhắc: mục 7b chỉ cho
/// `1 · 3 · 5 · 7` hoặc NULL, và đoán một số mặc định là nhắc một hoá đơn người
/// dùng không chọn nhắc.
int? soNgayNhacRieng(BillEntity bill) =>
    int.tryParse(bill.timeNotification ?? '');

/// Ngưỡng nhãn "Sắp đến hạn" của [bill]: số ngày riêng của hoá đơn nếu có, không
/// thì [fallback] (tuỳ chọn "Nhắc trước" nơi gọi truyền vào).
///
/// Giá trị đặt riêng cho một hoá đơn **thắng** mặc định chung — cùng số bộ nhắc
/// dùng cho hoá đơn ấy, để nhãn và dải nhắc nói cùng một chuyện.
int billLeadDays(BillEntity bill, {int fallback = mocNhacMacDinh}) =>
    soNgayNhacRieng(bill) ?? fallback;

/// Các mức "nhắc trước" chọn được: chip của form Thêm hoá đơn, danh sách của form Sửa và của hàng "Nhắc trước" ở
/// Cài đặt thông báo. Một định nghĩa — trước 2026-10-17 Cài đặt cho chọn cả 0 · 2 mà form không có chip nào khớp.
const List<int> kMucNhacTruoc = [1, 3, 5, 7];

/// Chip form Thêm hoá đơn chọn sẵn cho tuỳ chọn "Nhắc trước" [tuyChon] (người dùng chốt 2026-10-17: hàng ấy là
/// mặc định cho hoá đơn mới). Ngoài [kMucNhacTruoc] (giá trị cũ 0 · 2) thì [mocNhacMacDinh] — không đoán mức gần
/// nhất, và không lưu một số mà form không có chip.
int mucNhacChonSan(int tuyChon) => kMucNhacTruoc.contains(tuyChon) ? tuyChon : mocNhacMacDinh;
