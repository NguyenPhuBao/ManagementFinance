/// Gói số — đầu vào DUY NHẤT của mọi bộ diễn giải (mẫu câu ở P2, SLM ở P3).
///
/// Lớp này **không tính**: mọi con số đến từ hàm domain đã có của từng màn
/// (`budgetPaceOf`, `thuNhapCua`, `tyLeTietKiem`, `phanTramSoVoi`, `duBaoCua`,
/// `GoalEntity.progress`…). Bản định nghĩa thứ hai là thứ đã sinh bẫy A8 #8
/// (thu nhập gồm cả tiền đi vay), im lặng. Test quét
/// `test/features/ai_edge/ai_edge_khong_tinh_test.dart` cấm ở thư mục này mọi
/// phép so chiều tiền và mọi truy cập bảng giao dịch.
///
/// [SoLieu.chuoi] là **ba thứ cùng lúc**: thẻ số liệu người dùng thấy (G3),
/// tập cho phép của bộ kiểm số (`kiem_so.dart`), và phần đưa vào prompt để mô
/// hình chép nguyên. Vì thế nó đi qua `CurrencyFormatter` như mọi số tiền khác
/// của app, và phần trăm theo luật G2 (một chữ số thập phân).
library;

import '../../../core/utils/currency_formatter.dart';
import 'dau_van.dart';
import 'nhan_xet.dart';

enum LoaiSo { tien, phanTram, soNgay, soDem }

class SoLieu {
  final String nhan;
  final double soTho;

  /// Chuỗi đã định dạng — xem docstring đầu tệp.
  final String chuoi;
  final LoaiSo loai;

  const SoLieu({
    required this.nhan,
    required this.soTho,
    required this.chuoi,
    required this.loai,
  });
}

SoLieu soTien(String nhan, double v) => SoLieu(
      nhan: nhan,
      soTho: v,
      chuoi: CurrencyFormatter.format(v),
      loai: LoaiSo.tien,
    );

/// G2: một chữ số thập phân, phẩy thập phân. [phanTram] ở thang 0–100.
SoLieu soPhanTram(String nhan, double phanTram) => SoLieu(
      nhan: nhan,
      soTho: phanTram,
      chuoi: '${phanTram.toStringAsFixed(1).replaceAll('.', ',')}%',
      loai: LoaiSo.phanTram,
    );

SoLieu soNgay(String nhan, int ngay) => SoLieu(
      nhan: nhan,
      soTho: ngay.toDouble(),
      chuoi: '$ngay ngày',
      loai: LoaiSo.soNgay,
    );

SoLieu soDem(String nhan, int n) => SoLieu(
      nhan: nhan,
      soTho: n.toDouble(),
      chuoi: '$n',
      loai: LoaiSo.soDem,
    );

abstract class GoiSo {
  /// Tên màn: `ngan_sach` | `phan_tich` | `trang_chu` | `muc_tieu`.
  String get man;

  List<SoLieu> get soLieu;

  bool get thieuDuLieu;

  /// Bản mẫu câu — luôn có, là thứ SLM rơi về.
  NhanXet mauCau();

  String get dauVan => dauVanCua(this);
}
