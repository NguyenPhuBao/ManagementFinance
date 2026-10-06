/// Đợt âm của một ví (E6 lượt UX, 2026-10-06).
///
/// Thông báo "Số dư ví đang âm" từng khoá theo NGÀY, nên một ví âm bốn ngày là
/// bốn dòng giống hệt nhau trong trung tâm thông báo. Người dùng chọn **mỗi đợt
/// âm một lần**: mốc của khoá là giao dịch đã làm số dư tụt dưới 0 lần gần nhất
/// — ví còn âm thì mốc đứng yên, hồi lên rồi âm lại thì mốc mới.
///
/// Số dư ví suy từ sổ giao dịch (G37), nên lịch sử số dư cũng suy được từ sổ:
/// cộng dồn theo NGÀY giao dịch. Cùng ngày thì theo id — tuỳ ý nhưng ổn định,
/// và đủ cho một mốc chống trùng.
library;

/// Một khoản trong sổ của MỘT ví: số tiền đã mang dấu theo vai của ví ấy.
typedef BienDongSo = ({String id, DateTime ngay, double soTien});

/// Id giao dịch mở đợt âm hiện tại; `null` khi số dư cuối (theo sổ) không âm.
///
/// "Âm" là `< 0`, cùng luật `walletNegative` (`balance >= 0` là không âm).
String? giaoDichMoDotAm(Iterable<BienDongSo> so) {
  final xep = [...so]
    ..sort((a, b) {
      final n = a.ngay.compareTo(b.ngay);
      return n != 0 ? n : a.id.compareTo(b.id);
    });
  var soDu = 0.0;
  String? moc;
  for (final b in xep) {
    final truoc = soDu;
    soDu += b.soTien;
    if (truoc >= 0 && soDu < 0) moc = b.id;
  }
  return soDu < 0 ? moc : null;
}
