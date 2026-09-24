/// Tool `chi_tieu_theo_ky` — tổng chi, tổng thu và chi theo DANH MỤC (có tên)
/// của một kỳ (spec 4b mục 3.4). Tham số là MÃ KỲ chữ: E2B sinh `"2026-08-01"`
/// là rủi ro, `thang_truoc` thì không. Kỳ dựng bằng đúng phép của bộ chọn kỳ
/// trang Phân tích (`cacKyGanNhat`, `lui`) — không tự tính quý.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

/// Mã mô hình được chọn → chữ kèm cho mô hình. ⚠️ Chữ, không số: `trichSo`
/// đọc mọi chữ số là số, và số không có trong gói làm câu bị chặn.
///
/// Tám mã từ bước 2 (2026-09-23) — thêm `hom_nay`, `hom_qua`, `tuan_truoc`.
/// Bảng DUY NHẤT của các mã kỳ CHUNG — mọi tool nhận tham số kỳ đọc nó, để hai
/// tool không bao giờ hiểu cùng một chữ kỳ theo hai cách. `tim_giao_dich` nhận
/// thêm đúng một mã riêng, [kMaKyMoiLuc] (bước 2b).
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

/// Mã kỳ RIÊNG của `tim_giao_dich` (bước 2b, spec mục 2.5): câu không nêu kỳ —
/// "lần gần nhất", "lần cuối", "tìm theo ghi chú" — tìm trên mọi thời gian thay
/// vì chỉ tháng này (sang tháng mới, câu ấy từng ra "chưa có" dù thực tế có).
/// ⚠️ KHÔNG thêm vào [kMaKy]: `chi_tieu_theo_ky` không nhận mã này — `kyTuMa` trả
/// `null` cho nó nên tool ấy từ chối như mọi mã lạ.
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

KetQuaCongCu hangChiTieu(ThongKeKy tk, {required String ma}) {
  final chuKy = kMaKy[ma];
  if (chuKy == null) return tuChoiGiaTri('ky', ma, kMaKy.keys);
  // `tk.danhMuc` đã giảm dần và đã tra tên — chỉ chép (test quét 14).
  final hang = [
    for (final d in tk.danhMuc.take(kToiDaMucMoiGoi))
      HangSoLieu(
        ten: d.ten,
        trangThai: null,
        canhBao: false,
        soLieu: [soTien('Chi', d.soTien, ten: d.ten)],
      ),
  ];
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Tổng chi', tk.tong.chi),
      soTien('Tổng thu', tk.tong.thu),
    ],
    chuThem: {'ky': chuKy},
  );
}
