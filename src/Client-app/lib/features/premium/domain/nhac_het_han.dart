import 'trang_thai_goi.dart';

/// Còn bao nhiêu ngày để nhắc ở Trang chủ (spec Premium 9.5): `0..3` → nhắc,
/// `null` → im. Hết hạn rồi thì im — không nhắc người đã về Basic; chưa biết
/// hạn cũng im (không bịa một con số).
///
/// Backend chỉ phát `payment.expiring_soon` lên EventBus, app không nhận gì,
/// nên con số này tính từ hạn đã cache.
int? canNhacHetHan(TrangThaiGoi goi, DateTime now) {
  final n = goi.soNgayConLai(now);
  if (n == null || n < 0 || n > 3) return null;
  return n;
}
