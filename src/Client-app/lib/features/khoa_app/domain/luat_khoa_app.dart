/// Luật của khoá ứng dụng — hàm thuần (spec `docs/superpowers/specs/2026-10-24-khoa-app-pin-sinh-trac-design.md` mục 4, 6).
library;

/// Mức *Tự khoá sau*: app ở nền bằng hoặc lâu hơn mức này thì quay lại phải mở khoá.
enum TuKhoaSau {
  ngay(Duration.zero, 'Ngay khi rời app'),
  giay30(Duration(seconds: 30), '30 giây'),
  phut1(Duration(minutes: 1), '1 phút'),
  phut5(Duration(minutes: 5), '5 phút');

  const TuKhoaSau(this.thoiGian, this.nhan);

  final Duration thoiGian;
  final String nhan;

  /// Mặc định khi bật khoá (người dùng chốt 2026-10-24).
  static const TuKhoaSau macDinh = giay30;

  /// Đọc tên đã cất; tên lạ / `null` → [macDinh].
  static TuKhoaSau tuTen(String? ten) =>
      values.firstWhere((m) => m.name == ten, orElse: () => macDinh);
}

/// Số chữ số của mã PIN (người dùng chốt 6).
const int kDoDaiPin = 6;

/// Sai liền bao nhiêu lần thì bắt đầu phải chờ.
const int kSaiBatDauCho = 5;

final RegExp _pin = RegExp('^[0-9]{$kDoDaiPin}\$');

bool maPinHopLe(String pin) => _pin.hasMatch(pin);

/// Rời app lúc [roiLuc], quay lại lúc [nay]: có phải mở khoá không. Đồng hồ lùi → khoá (không biết đã ở nền bao lâu).
///
/// [oNenTheoKhoiDong] = thời gian ở nền đo bằng đồng hồ KHỞI ĐỘNG (đơn điệu, tính cả lúc máy ngủ — `null` = nền tảng không
/// đọc được): giờ tường chỉnh được bằng Cài đặt giờ nên chỉ một mình nó thì chỉnh lùi về sau mốc rời là vượt khoá. Khoá khi
/// MỘT trong hai đo vượt mức; đồng hồ khởi động âm (máy khởi động lại giữa chừng) → khoá.
bool canKhoaKhiQuayLai({
  required DateTime roiLuc,
  required DateTime nay,
  required TuKhoaSau muc,
  Duration? oNenTheoKhoiDong,
}) {
  final oNen = nay.difference(roiLuc);
  if (oNen.isNegative) return true;
  if (oNen >= muc.thoiGian) return true;
  final kd = oNenTheoKhoiDong;
  return kd != null && (kd.isNegative || kd >= muc.thoiGian);
}

/// Mức chờ dài nhất sau sai PIN — không lần chờ hợp lệ nào còn lại lâu hơn thế (M8 kẹp theo hằng này).
const Duration kChoToiDa = Duration(minutes: 15);

/// Sai liền [soLanSai] lần thì chờ bao lâu (`null` = chưa phải chờ).
Duration? thoiGianCho(int soLanSai) {
  if (soLanSai < kSaiBatDauCho) return null;
  switch (soLanSai) {
    case 5:
      return const Duration(seconds: 30);
    case 6:
      return const Duration(minutes: 1);
    case 7:
      return const Duration(minutes: 5);
    default:
      return kChoToiDa;
  }
}

/// M8: mốc chờ cách [nay] xa hơn [kChoToiDa] chỉ có khi giờ máy từng chạy trước lúc sai PIN rồi bị chỉnh lại — kẹp về
/// `nay + kChoToiDa`. Người gọi phải GHI LẠI mốc đã kẹp (`KhoaAppService`): kẹp mà không ghi là mỗi lần đọc lại dời mốc
/// thêm 15 phút, đồng hồ đếm ngược không bao giờ về 0. Chỉnh giờ lùi không mở được chờ (chỉ rút về 15 phút); chỉnh tới thì
/// vẫn rút được — giới hạn đã chấp nhận (bẫy 7).
DateTime? kepChoDen(DateTime? choDen, DateTime nay) {
  if (choDen == null) return null;
  final toiDa = nay.add(kChoToiDa);
  return choDen.isAfter(toiDa) ? toiDa : choDen;
}

/// Còn phải chờ bao lâu tới [choDen] lúc [nay] (`null` = không chờ: không có mốc, đúng mốc, hoặc đã qua).
/// MỘT định nghĩa "đang chờ" cho service, màn khoá và trang đặt PIN.
Duration? conCho(DateTime? choDen, DateTime nay) {
  if (choDen == null) return null;
  final con = choDen.difference(nay);
  return con <= Duration.zero ? null : con;
}

/// Đếm ngược `mm:ss`, làm tròn LÊN giây (còn 29,2 s hiện `00:30`).
String chuDemNguoc(Duration con) {
  final giay = (con.inMilliseconds / 1000).ceil();
  return '${(giay ~/ 60).toString().padLeft(2, '0')}:${(giay % 60).toString().padLeft(2, '0')}';
}
