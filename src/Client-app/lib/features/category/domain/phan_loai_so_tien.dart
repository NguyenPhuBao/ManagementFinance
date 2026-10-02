/// Dự án C, việc đầu — gợi ý danh mục theo SỐ TIỀN khi ghi chú không giúp được (spec
/// `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`). Hàm thuần: không Drift, không Flutter, không đồng hồ.
///
/// Naive Bayes phân loại trên ba đặc trưng — bậc tiền (thang 1·2·5), nhóm thứ (ngày thường / cuối tuần), ví — chỉ
/// trên mẫu CÙNG CHIỀU với đoạn đang chọn: số tiền không mang nghĩa chiều, nên 9.000.000 dưới đoạn Thu là *Lương*,
/// dưới đoạn Chi là *Nhà cửa*.
///
/// ⚠️ KHÔNG có giờ: giờ lưu trong giao dịch là giờ NHẬP (màn Thêm giao dịch khởi tạo ngày bằng `DateTime.now()`, và
/// `showDatePicker` trả 00:00), không phải giờ chi.
///
/// Đặt ở `category/domain/`, không ở `ai_edge/`: nó đọc sổ giao dịch và so chiều tiền — thứ test quét 14 cấm ở đó.
/// Cùng chỗ với `phan_loai_ghi_chu.dart` (B1) và dùng lại ngưỡng của nó, không khai bản thứ hai.
library;

import '../../transaction/domain/khoang_tien.dart';
import 'phan_loai_ghi_chu.dart';

/// Giá trị cột `nguon` của bảng phản hồi cho thẻ gợi ý theo số tiền.
const String kNguonGoiYSoTien = 'so_tien';

const String kNhomNgayThuong = 'ngay_thuong';
const String kNhomCuoiTuan = 'cuoi_tuan';

/// Dưới mốc này là MỘT bậc: khoản vài nghìn không đáng chia nhỏ hơn.
const int kSanBacTien = 10000;

/// Bậc tiền `[duoi, tren)`.
typedef BacTien = ({int duoi, int tren});

/// Bậc của [soTien] trên thang 1·2·5 × 10^k. Biên dưới thuộc bậc trên (50.000 → 50–100k); so biên bằng ngưỡng nửa
/// đồng vì `amount` là `double` (khoản điều chỉnh số dư mang đuôi lẻ).
BacTien bacTienCua(double soTien) {
  final x = soTien + kDungSaiTien;
  if (x < kSanBacTien) return (duoi: 0, tren: kSanBacTien);
  var muoi = kSanBacTien;
  while (muoi * 10 <= x) {
    muoi *= 10;
  }
  if (x < muoi * 2) return (duoi: muoi, tren: muoi * 2);
  if (x < muoi * 5) return (duoi: muoi * 2, tren: muoi * 5);
  return (duoi: muoi * 5, tren: muoi * 10);
}

/// Mã bậc — khoá của luật thôi gợi ý, và là `amTietChinh` trong bảng phản hồi.
String maBacCua(BacTien b) => '${b.duoi}-${b.tren}';

/// Hai nhóm chứ không bảy thứ: với vài chục mẫu, mỗi thứ riêng quá ít dữ liệu để nói gì (người dùng chốt 2026-10-02).
String nhomThuCua(DateTime ngay) => ngay.weekday >= DateTime.saturday ? kNhomCuoiTuan : kNhomNgayThuong;

class MauSoTien {
  final String categoryId;

  /// `'thu'` | `'chi'`.
  final String chieu;
  final String maBac;
  final String nhomThu;
  final String walletId;
  final DateTime ngay;
  const MauSoTien({
    required this.categoryId,
    required this.chieu,
    required this.maBac,
    required this.nhomThu,
    required this.walletId,
    required this.ngay,
  });
}

/// Mẫu có nhãn: khoản thu / chi có danh mục, chưa xoá, số tiền dương, không do máy sinh (`laGhiChuMay` của B1 — trả
/// hoá đơn, nạp / rút mục tiêu, điều chỉnh số dư, số dư ban đầu). Có hay không có ghi chú đều tính — khác `mauHocTu`
/// của B1 ở đúng chỗ ấy: tín hiệu ở đây là số tiền, không phải chữ.
List<MauSoTien> mauSoTienTu(
        Iterable<
                ({
                  String loai,
                  String? categoryId,
                  String? ghiChu,
                  double soTien,
                  String walletId,
                  DateTime ngay,
                  bool daXoa
                })>
            giaoDich) =>
    [
      for (final t in giaoDich)
        if (!t.daXoa &&
            t.categoryId != null &&
            (t.loai == 'thu' || t.loai == 'chi') &&
            t.soTien > 0 &&
            !laGhiChuMay(loai: t.loai, categoryId: t.categoryId, ghiChu: t.ghiChu))
          MauSoTien(
            categoryId: t.categoryId!,
            chieu: t.loai,
            maBac: maBacCua(bacTienCua(t.soTien)),
            nhomThu: nhomThuCua(t.ngay),
            walletId: t.walletId,
            ngay: t.ngay,
          ),
    ];
