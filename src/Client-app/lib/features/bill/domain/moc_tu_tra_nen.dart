/// Phần HOÁ ĐƠN của lịch lượt nền tự chuyển tiền (spec `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.1) — tách khỏi
/// `core/nen/lich_nen.dart` 2026-10-15 (G88 gạch 4: hạ tầng `core` không biết mảng); `core/nen` chỉ gộp các phần
/// (`gopLichNen`).
///
/// Hoá đơn bật tự trả, còn phải trả, có ví và danh mục, chưa xoá (các điều kiện của `denLuotTuTra` trừ phép so ngày): ngày
/// đến hạn lúc **giờ nhắc chung** [gioNhac]:[phutNhac]. Chỉ mốc **ở tương lai**.
///
/// ⚠️ Kỳ đã tới hạn mà chưa xong (ví không đủ) KHÔNG được hẹn "ngay": lượt một-lần sẽ tự hẹn lại ngay — vòng lặp tốn pin.
/// Nó chờ lượt định kỳ hoặc lần mở app; `coTuDong` vẫn `true` để giữ lượt định kỳ.
///
/// Quyền gói (`coQuyenNen(MaQuyen.billAutoPay)`) xét ở DI: không quyền thì không gọi hàm này — phần hoá đơn không góp
/// `coTuDong`, Basic không cần đánh thức máy.
library;

import '../data/models/bill_entity.dart';
import 'bill_pay_status.dart';

({DateTime? moc, bool coTuDong}) mocTuTraNen(
  List<BillEntity> bills, {
  required DateTime now,
  required int gioNhac,
  required int phutNhac,
}) {
  DateTime? moc;
  var coTuDong = false;
  void xet(DateTime m) {
    final cu = moc;
    if (m.isAfter(now) && (cu == null || m.isBefore(cu))) moc = m;
  }

  for (final b in bills) {
    if (!b.autoPayEnabled || b.isDeleted || !conPhaiTra(b)) continue;
    if (b.walletId == null || b.categoryId == null) continue;
    coTuDong = true;
    xet(DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day, gioNhac, phutNhac));
  }
  return (moc: moc, coTuDong: coTuDong);
}
