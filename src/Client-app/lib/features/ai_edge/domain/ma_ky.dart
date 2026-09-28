/// MÃ KỲ cho tham số `ky` của tool — bảng DUY NHẤT của các mã kỳ chung, để hai
/// tool không bao giờ hiểu cùng một chữ kỳ theo hai cách. Tách khỏi
/// `hang_chi_tieu.dart` ngày 2026-09-27 khi tool tổng kết bị thay bởi
/// `truy_van_giao_dich` (spec `2026-09-27-tool-truy-van-giao-dich-design.md`).
///
/// Tham số là MÃ KỲ chữ: E2B sinh `"2026-08-01"` là rủi ro, `thang_truoc` thì
/// không. Kỳ dựng bằng đúng phép của bộ chọn kỳ trang Phân tích (`cacKyGanNhat`,
/// `lui`) — không tự tính quý.
library;

import '../../../core/notification/tuan_iso.dart';
import '../../analytics/domain/pham_vi_ky.dart';

/// Mã mô hình được chọn → chữ kèm cho mô hình. ⚠️ Chữ, không số: `trichSo`
/// đọc mọi chữ số là số, và số không có trong gói làm câu bị chặn.
///
/// Tám mã từ bước 2 (2026-09-23) — thêm `hom_nay`, `hom_qua`, `tuan_truoc`.
const Map<String, String> kMaKy = {
  'hom_nay': 'hôm nay',
  'hom_qua': 'hôm qua',
  'tuan_nay': 'tuần này',
  'tuan_truoc': 'tuần trước',
  'thang_nay': 'tháng này',
  'thang_truoc': 'tháng trước',
  'quy_nay': 'quý này',
  'nam_nay': 'năm nay',
};

/// Mã kỳ RIÊNG của tool giao dịch (bước 2b, spec mục 2.5): câu không nêu kỳ —
/// "lần gần nhất", "lần cuối", "tìm theo ghi chú" — tìm trên mọi thời gian thay
/// vì chỉ tháng này (sang tháng mới, câu ấy từng ra "chưa có" dù thực tế có).
/// ⚠️ KHÔNG thêm vào [kMaKy]: `kyTuMa` trả `null` cho nó — tool nào chỉ nhận
/// [kMaKy] thì từ chối nó như mọi mã lạ.
const String kMaKyMoiLuc = 'moi_luc';
const String kChuKyMoiLuc = 'mọi thời gian';

/// `null` = mã lạ. `cacKyGanNhat(...).first` là kỳ chứa [now]. Hai mã ngày dựng
/// bằng `Ky.tuyChon` trọn một ngày — `DateTime(y, m, d - 1)` tự lùi qua biên
/// tháng, năm và tháng hai nhuận.
Ky? kyTuMa(String ma, DateTime now) {
  final dauNgay = DateTime(now.year, now.month, now.day);
  return switch (ma) {
    'hom_nay' => Ky.tuyChon(
        from: dauNgay,
        to: DateTime(now.year, now.month, now.day + 1),
      ),
    'hom_qua' => Ky.tuyChon(
        from: DateTime(now.year, now.month, now.day - 1),
        to: dauNgay,
      ),
    'tuan_nay' => cacKyGanNhat(now, DonViKy.tuan).first,
    'tuan_truoc' => lui(cacKyGanNhat(now, DonViKy.tuan).first, 1),
    'thang_nay' => cacKyGanNhat(now, DonViKy.thang).first,
    'thang_truoc' => lui(cacKyGanNhat(now, DonViKy.thang).first, 1),
    'quy_nay' => cacKyGanNhat(now, DonViKy.quy).first,
    'nam_nay' => cacKyGanNhat(now, DonViKy.nam).first,
    _ => null,
  };
}

/// Mã kỳ của KHOẢNG NÊU CỤ THỂ (spec mở rộng tool 2026-09-27 §3.1): hai mốc đi
/// ở `tu_ngay` / `den_ngay`. ⚠️ KHÔNG thêm vào [kMaKy] — `kyTuMa` không dựng
/// được nó từ mỗi cái mã, và chữ kỳ của nó mang chữ số nên đi `boLoc`.
const String kMaKyTuyChon = 'tuy_chon';
const String kChuKyTuyChon = 'khoảng đã chọn';

/// Kỳ NÊU CỤ THỂ trong câu hỏi — câu [q] đã bỏ dấu, chữ thường (dạng bộ chỉnh
/// tham số dùng). Trả biên `[from, to)` và chữ kỳ CÓ SỐ cho `boLoc`.
///
/// Tháng không kèm năm lấy năm của [now]; tháng ấy chưa tới thì lùi một năm.
/// "N tháng/tuần/ngày gần nhất" đóng ở đầu ngày mai — không nuốt giao dịch ghi
/// ngày tương lai, cùng lý do `cuaSoNhinLai`.
///
/// `null` = câu không nêu kỳ cụ thể, HOẶC mốc không hợp lệ (31/6, mốc ngược,
/// tháng 13) — người gọi không điền gì, không tự cuộn sang ngày khác.
({DateTime from, DateTime to, String chu})? kyTuCauHoi(String q, DateTime now) {
  final ngayMai = DateTime(now.year, now.month, now.day + 1);

  // 1. "tu [ngay] d/m[/y] den|toi [ngay] d/m[/y]"
  final mKhoang = RegExp(
    r'tu (?:ngay )?(\d{1,2})/(\d{1,2})(?:/(\d{4}))? (?:den|toi) (?:het )?(?:ngay )?(\d{1,2})/(\d{1,2})(?:/(\d{4}))?',
  ).firstMatch(q);
  if (mKhoang != null) {
    final y2 = int.tryParse(mKhoang.group(6) ?? '') ??
        int.tryParse(mKhoang.group(3) ?? '') ??
        now.year;
    final y1 = int.tryParse(mKhoang.group(3) ?? '') ?? y2;
    final tu = ngayHopLe(y1, int.parse(mKhoang.group(2)!), int.parse(mKhoang.group(1)!));
    final den = ngayHopLe(y2, int.parse(mKhoang.group(5)!), int.parse(mKhoang.group(4)!));
    if (tu == null || den == null || den.isBefore(tu)) return null;
    return (
      from: tu,
      to: DateTime(den.year, den.month, den.day + 1),
      chu: chuKhoangNgay(tu, den),
    );
  }

  // 2. "N thang|tuan|ngay gan nhat|qua|gan day|vua qua"
  final mLui = mauKyLuiGanNhat.firstMatch(q);
  if (mLui != null) {
    final n = int.parse(mLui.group(1)!);
    if (n < 1) return null;
    final dv = mLui.group(2)!;
    final from = switch (dv) {
      'thang' => _luiThang(now, n),
      'tuan' => DateTime(now.year, now.month, now.day - 7 * n),
      _ => DateTime(now.year, now.month, now.day - n),
    };
    final chuDv = switch (dv) { 'thang' => 'tháng', 'tuan' => 'tuần', _ => 'ngày' };
    return (from: from, to: ngayMai, chu: '$n $chuDv gần nhất');
  }

  // 3. "thang m[/y | nam y]" — "thang nay/truoc" không có chữ số nên không khớp.
  final mThang =
      RegExp(r'thang (\d{1,2})(?:/(\d{4})| nam (\d{4}))?(?![\d/])').firstMatch(q);
  if (mThang != null) {
    final m = int.parse(mThang.group(1)!);
    if (m < 1 || m > 12) return null;
    final namNeu = int.tryParse(mThang.group(2) ?? mThang.group(3) ?? '');
    final y = namNeu ?? (m > now.month ? now.year - 1 : now.year);
    final ky = Ky.thang(y, m);
    return (from: ky.from, to: ky.to, chu: 'tháng $m/$y');
  }

  // 4. "quy q[/y | nam y]"
  final mQuy =
      RegExp(r'quy ([1-4])(?:/(\d{4})| nam (\d{4}))?(?![\d/])').firstMatch(q);
  if (mQuy != null) {
    final y = int.tryParse(mQuy.group(2) ?? mQuy.group(3) ?? '') ?? now.year;
    final ky = Ky.quy(y, int.parse(mQuy.group(1)!));
    return (from: ky.from, to: ky.to, chu: 'quý ${mQuy.group(1)}/$y');
  }

  // 5. "tuan w" — tuần ISO của năm nay.
  final mTuan = RegExp(r'tuan (\d{1,2})(?![\d/])').firstMatch(q);
  if (mTuan != null) {
    final w = int.parse(mTuan.group(1)!);
    if (w < 1 || w > 53) return null;
    // 4/1 luôn thuộc tuần ISO 1; cộng theo NGÀY LỊCH chứ không theo Duration.
    final moc = DateTime(now.year, 1, 4);
    final b = bienTuan(DateTime(moc.year, moc.month, moc.day + 7 * (w - 1)));
    return (from: b.from, to: b.to, chu: 'tuần $w/${now.year}');
  }

  // 6. "nam ngoai" | "nam y"
  if (RegExp(r'(?<![a-z])nam ngoai(?![a-z])').hasMatch(q)) {
    final ky = Ky.nam(now.year - 1);
    return (from: ky.from, to: ky.to, chu: 'năm ${now.year - 1}');
  }
  final mNam = RegExp(r'(?<![a-z/])nam (\d{4})(?![\d/])').firstMatch(q);
  if (mNam != null) {
    final ky = Ky.nam(int.parse(mNam.group(1)!));
    return (from: ky.from, to: ky.to, chu: 'năm ${mNam.group(1)}');
  }
  return null;
}

/// "N tháng / tuần / ngày gần nhất" — công khai vì bộ chỉnh tham số phải bỏ cụm
/// này khỏi câu trước khi dò "gần nhất / gần đây" của luật sắp xếp: *"3 tháng
/// gần nhất"* là KỲ, không phải *"lần gần nhất"*.
final RegExp mauKyLuiGanNhat = RegExp(
  r'(?<!\d)(\d{1,3}) (thang|tuan|ngay) (?:gan nhat|qua|gan day|vua qua)',
);

/// Chữ của một khoảng hai mốc, [den] BAO GỒM — một định nghĩa cho bộ chỉnh lẫn tool.
String chuKhoangNgay(DateTime tu, DateTime den) =>
    'từ ${tu.day}/${tu.month} đến ${den.day}/${den.month}/${den.year}';

/// `null` khi ngày không tồn tại trên lịch — `DateTime(2026, 6, 31)` tự cuộn
/// sang 1/7, nên phải so lại tháng và ngày.
DateTime? ngayHopLe(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final x = DateTime(y, m, d);
  return (x.month == m && x.day == d) ? x : null;
}

/// Lùi [n] tháng, KẸP ngày về ngày cuối của tháng đích (31/3 lùi một tháng là
/// 28/2 hay 29/2, không phải 3/3).
DateTime _luiThang(DateTime now, int n) {
  final dauThang = DateTime(now.year, now.month - n, 1);
  final ngayCuoi = DateTime(dauThang.year, dauThang.month + 1, 0).day;
  return DateTime(dauThang.year, dauThang.month, now.day < ngayCuoi ? now.day : ngayCuoi);
}
