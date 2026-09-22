/// Khoảng số tiền của bộ lọc sổ giao dịch (2026-09-21).
///
/// ## Vì sao là một lớp chứ không hai trường phẳng trên `TransactionFilter`
///
/// `TransactionFilter.copyWith` dùng khuôn cờ `clearWallet` / `clearCategory` để
/// phân biệt *"không truyền"* với *"truyền null"*. Khoảng tiền có **hai** vế nên
/// khuôn ấy vỡ: một cờ `clearSoTien` sẽ xoá nhầm cả cặp khi người dùng chỉ muốn
/// bỏ vế dưới. Gói thành một khái niệm thì `copyWith` nhận đúng khuôn đã có, và
/// phép so nằm cùng chỗ với dữ liệu.
///
/// ## Hai vế đều được phép trống
///
/// Để trống vế trên là *lớn hơn*, để trống vế dưới là *nhỏ hơn*, điền cả hai là
/// *khoảng giữa*. Ba dạng ấy phủ trọn bốn toán tử mà Monarch Money bày thành một
/// dropdown riêng — nên không cần dropdown nào.
library;

import '../../../core/utils/currency_formatter.dart';

/// Dung sai khi so số tiền: **nửa đồng**.
///
/// `amount` là `double`, và khoản **điều chỉnh số dư** mang đuôi lẻ có thật. Một
/// khoản đúng `500.000` mà máy giữ là `499999.99999994` sẽ rơi khỏi bộ lọc
/// "từ 500.000" — không exception, không log, chỉ một dòng biến mất khỏi danh
/// sách. Cùng ngưỡng mà `dieu_chinh_so_du_service.dart` và `ranhVuotTrungBinh`
/// đã dùng cho đúng loại đuôi lẻ này.
const double kDungSaiTien = 0.5;

class KhoangTien {
  const KhoangTien({this.tu, this.den});

  /// Chặn dưới; `null` = không chặn.
  final double? tu;

  /// Chặn trên; `null` = không chặn.
  final double? den;

  bool get rong => tu == null && den == null;

  /// Người dùng gõ ngược hai ô. Chỗ gọi **chặn** thay vì tự hoán đổi: hoán đổi
  /// là đoán ý, và đoán sai thì kết quả trông vẫn hoàn toàn hợp lý.
  bool get hopLe => tu == null || den == null || tu! <= den!;

  /// Phép so **duy nhất** cho "khoản này có nằm trong khoảng không".
  ///
  /// ⚠️ [soTien] là `amount` thô của giao dịch, và cột ấy **luôn dương** trong
  /// SQLite client — chiều tiền nằm ở `type`. Nên không `.abs()`, và khoảng áp
  /// cho cả `thu`, `chi` lẫn `transfer`: "khoản trên 500k" không phân biệt chiều.
  bool chua(double soTien) {
    if (tu != null && soTien < tu! - kDungSaiTien) return false;
    if (den != null && soTien > den! + kDungSaiTien) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is KhoangTien && other.tu == tu && other.den == den;

  @override
  int get hashCode => Object.hash(tu, den);

  @override
  String toString() => 'KhoangTien($tu → $den)';
}

/// Nhãn của chip "Số tiền" trên thanh lọc.
///
/// Ở tầng thuần để test được: tầng vẽ không test được bề rộng thật (bẫy 4.9), và
/// font của bộ test rộng gấp đôi ngoài đời.
///
/// Ký hiệu `đ` chỉ hiện **một lần, ở cuối** khi có hai vế — "100.000 đ – 500.000 đ"
/// dài gần gấp rưỡi mà không thêm thông tin nào.
String nhanKhoangTien(KhoangTien? kt) {
  if (kt == null || kt.rong) return 'Số tiền';
  final tu = kt.tu;
  final den = kt.den;
  if (tu != null && den != null) {
    return '${CurrencyFormatter.formatSoThoi(tu)} – ${CurrencyFormatter.format(den)}';
  }
  if (tu != null) return 'Từ ${CurrencyFormatter.format(tu)}';
  return 'Đến ${CurrencyFormatter.format(den!)}';
}
