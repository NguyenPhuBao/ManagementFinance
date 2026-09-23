/// Tool `chi_tieu_theo_ky` — tổng chi, tổng thu và chi theo DANH MỤC (có tên)
/// của một kỳ (spec 4b mục 3.4). Tham số là MÃ KỲ chữ: E2B sinh `"2026-08-01"`
/// là rủi ro, `thang_truoc` thì không. Kỳ dựng bằng đúng phép của bộ chọn kỳ
/// trang Phân tích (`cacKyGanNhat`, `lui`) — không tự tính quý.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';

/// Mã mô hình được chọn → chữ kèm cho mô hình. ⚠️ Chữ, không số: `trichSo`
/// đọc mọi chữ số là số, và số không có trong gói làm câu bị chặn.
const Map<String, String> kMaKy = {
  'tuan_nay': 'tuần này',
  'thang_nay': 'tháng này',
  'thang_truoc': 'tháng trước',
  'quy_nay': 'quý này',
  'nam_nay': 'năm nay',
};

String loiMaKy(String ma) =>
    'ky "$ma" không hợp lệ. Chỉ nhận: ${kMaKy.keys.join(', ')}.';

/// `null` = mã lạ. `cacKyGanNhat(...).first` là kỳ chứa [now].
Ky? kyTuMa(String ma, DateTime now) => switch (ma) {
      'tuan_nay' => cacKyGanNhat(now, DonViKy.tuan).first,
      'thang_nay' => cacKyGanNhat(now, DonViKy.thang).first,
      'thang_truoc' => lui(cacKyGanNhat(now, DonViKy.thang).first, 1),
      'quy_nay' => cacKyGanNhat(now, DonViKy.quy).first,
      'nam_nay' => cacKyGanNhat(now, DonViKy.nam).first,
      _ => null,
    };

KetQuaCongCu hangChiTieu(ThongKeKy tk, {required String ma}) {
  final chuKy = kMaKy[ma];
  if (chuKy == null) return KetQuaCongCu.loi(loiMaKy(ma));
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
