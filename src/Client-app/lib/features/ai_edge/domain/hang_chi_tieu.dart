/// Tool `tong_ket_thu_chi_ky` (tên cũ `chi_tieu_theo_ky` tới 2026-09-24) — tổng
/// chi, tổng thu và chi theo DANH MỤC (có tên)
/// của một kỳ (spec 4b mục 3.4). Tham số là MÃ KỲ chữ: E2B sinh `"2026-08-01"`
/// là rủi ro, `thang_truoc` thì không. Kỳ dựng bằng đúng phép của bộ chọn kỳ
/// trang Phân tích (`cacKyGanNhat`, `lui`) — không tự tính quý.
library;

import '../../analytics/data/analytics_repository.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';
import 'ma_ky.dart';

// Mã kỳ tách sang `ma_ky.dart` (2026-09-27); export để chỗ import tệp này còn
// thấy tên cho tới khi tool tổng kết bị xoá.
export 'ma_ky.dart';

/// Trạng thái hai đầu của danh sách danh mục — chữ để mô hình đọc, không phải
/// để suy luận (lần đo 15, 2026-09-27, câu E3 "danh mục nào ít tiêu nhất"):
/// trần bốn hàng cắt mất danh mục nhỏ, và có đủ dữ liệu E2B cũng không tự lọc
/// (E18 cùng lượt). Nên hàng cuối là danh mục ÍT NHẤT chứ không phải hàng thứ
/// tư theo thứ tự giảm dần, và hai đầu mang nhãn.
const String kTrangThaiChiNhieuNhat = 'chi nhiều nhất';
const String kTrangThaiChiItNhat = 'chi ít nhất';

KetQuaCongCu hangChiTieu(ThongKeKy tk, {required String ma}) {
  final chuKy = kMaKy[ma];
  if (chuKy == null) return tuChoiGiaTri('ky', ma, kMaKy.keys);
  // `tk.danhMuc` đã giảm dần và đã tra tên — chỉ chép (test quét 14).
  final ds = tk.danhMuc;
  final chon = ds.length <= kToiDaMucMoiGoi
      ? ds
      : [...ds.take(kToiDaMucMoiGoi - 1), ds.last];
  String? trangThai(int i) {
    if (ds.length < 2) return null;
    if (i == 0) return kTrangThaiChiNhieuNhat;
    if (i == chon.length - 1) return kTrangThaiChiItNhat;
    return null;
  }

  final hang = [
    for (var i = 0; i < chon.length; i++)
      HangSoLieu(
        ten: chon[i].ten,
        trangThai: trangThai(i),
        canhBao: false,
        // Xung đột "Thu" (bẫy 4.42): C10 cổng D gán số Chi của Cho vay làm
        // "khoản thu". Chữ hoa — test quét 14 chỉ cấm chuỗi chiều tiền thường.
        soLieu: [
          soTien('Chi', chon[i].soTien, ten: chon[i].ten, nhanXungDot: const ['Thu']),
        ],
      ),
  ];
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Tổng chi', tk.tong.chi),
      soTien('Tổng thu', tk.tong.thu),
      // Mô hình phải biết còn danh mục không hiện trong bốn hàng.
      soDem('Số danh mục', ds.length),
    ],
    chuThem: {'ky': chuKy},
  );
}
