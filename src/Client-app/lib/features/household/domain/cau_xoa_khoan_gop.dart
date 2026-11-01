import '../../../core/utils/currency_formatter.dart';

/// Câu của hộp *Xoá khoản góp?* / *Xoá khoản rút?* (Stitch `6dc96c4a…` 8B): nói rõ quỹ và ví riêng thay đổi thế nào, vì xoá một
/// khoản cặp xoá CẢ HAI nửa. Bốn nhánh:
/// - [tenNguoiKhac] có (Chủ nhà xoá hộ khoản của người khác — máy này không có nửa riêng) → nêu tên người, tiền về ví riêng của họ;
/// - [tenViRieng] có → tiền về / khoản nhận ở ví riêng ấy;
/// - cả hai `null` → *tiền mặt trao tay*, chỉ quỹ đổi.
/// [gop] `true` là góp, `false` là rút. [tenQuy] là tên ví chung, không kèm chữ *Quỹ*.
String cauXoaKhoanGop({
  required bool gop,
  required String tenQuy,
  required double soTien,
  String? tenViRieng,
  String? tenNguoiKhac,
}) {
  final tien = CurrencyFormatter.format(soTien);
  if (tenNguoiKhac != null) {
    return gop
        ? 'Khoản góp của $tenNguoiKhac bị xoá, quỹ $tenQuy giảm $tien. Tiền được trả về ví riêng của $tenNguoiKhac.'
        : 'Khoản rút của $tenNguoiKhac bị xoá, quỹ $tenQuy được cộng lại $tien. Khoản nhận ở ví riêng của $tenNguoiKhac bị huỷ.';
  }
  if (gop) {
    return tenViRieng == null
        ? 'Quỹ $tenQuy cũng giảm $tien.'
        : 'Quỹ $tenQuy cũng giảm $tien, và số tiền được trả về $tenViRieng.';
  }
  return tenViRieng == null
      ? 'Quỹ $tenQuy được cộng lại $tien.'
      : 'Quỹ $tenQuy được cộng lại $tien, và khoản nhận ở $tenViRieng bị huỷ.';
}
