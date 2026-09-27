/// MÃ KỲ cho tham số `ky` của tool — bảng DUY NHẤT của các mã kỳ chung, để hai
/// tool không bao giờ hiểu cùng một chữ kỳ theo hai cách. Tách khỏi
/// `hang_chi_tieu.dart` ngày 2026-09-27 khi tool tổng kết bị thay bởi
/// `truy_van_giao_dich` (spec `2026-09-27-tool-truy-van-giao-dich-design.md`).
///
/// Tham số là MÃ KỲ chữ: E2B sinh `"2026-08-01"` là rủi ro, `thang_truoc` thì
/// không. Kỳ dựng bằng đúng phép của bộ chọn kỳ trang Phân tích (`cacKyGanNhat`,
/// `lui`) — không tự tính quý.
library;

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
