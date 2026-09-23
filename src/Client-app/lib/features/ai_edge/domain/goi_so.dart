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

enum LoaiSo { tien, phanTram, soNgay, soDem, ngayThang }

/// Trần số mục mà **một** gói được nhồi vào prompt cho mỗi loại danh sách.
///
/// ⚠️ Đây là tham số **đo được**, không phải hằng đoán: prompt hỏi đáp đã
/// 1.700 ký tự và token đầu 4,6 s trên CPU của Realme RMX2205 (bảng đo mục
/// 5.6 `docs/AI_AGENT_ARCHITECTURE.md`). Đổi số này thì phải đo lại độ dài
/// prompt và token đầu trên máy thật, không suy từ máy ảo.
const int kToiDaMucMoiGoi = 4;

class SoLieu {
  final String nhan;

  /// Tên **đối tượng** mang con số này: `Giáo dục`, `Tiền mặt`, `Kiem`.
  ///
  /// Tách khỏi [nhan] — thứ gọi tên *chỉ số* (`Tỉ lệ`, `Còn thiếu`, `Số dư`).
  ///
  /// 🛑 Đừng ghép hai thứ vào [nhan]. `kiemNhan` đòi câu chứa **mọi** âm tiết
  /// có nghĩa của nhãn, nên nhãn ghép `Giáo dục · Tỉ lệ` đòi câu phải có cả
  /// "tỉ" lẫn "lệ", và câu tự nhiên nhất — *"Giáo dục đã dùng 90,0%"* — bị
  /// chính lớp chắn ấy chặn, **im lặng**.
  ///
  /// `null` là ca **thường**, không phải dấu hiệu thiếu dữ liệu: tổng thu,
  /// tổng chi, số ví không thuộc về một đối tượng nào.
  final String? ten;

  final double soTho;

  /// Chuỗi đã định dạng — xem docstring đầu tệp.
  final String chuoi;
  final LoaiSo loai;

  const SoLieu({
    required this.nhan,
    this.ten,
    required this.soTho,
    required this.chuoi,
    required this.loai,
  });
}

SoLieu soTien(String nhan, double v, {String? ten}) => SoLieu(
      nhan: nhan,
      ten: ten,
      soTho: v,
      chuoi: CurrencyFormatter.format(v),
      loai: LoaiSo.tien,
    );

/// G2: một chữ số thập phân, phẩy thập phân. [phanTram] ở thang 0–100.
SoLieu soPhanTram(String nhan, double phanTram, {String? ten}) => SoLieu(
      nhan: nhan,
      ten: ten,
      soTho: phanTram,
      chuoi: '${phanTram.toStringAsFixed(1).replaceAll('.', ',')}%',
      loai: LoaiSo.phanTram,
    );

SoLieu soNgay(String nhan, int ngay, {String? ten}) => SoLieu(
      nhan: nhan,
      ten: ten,
      soTho: ngay.toDouble(),
      chuoi: '$ngay ngày',
      loai: LoaiSo.soNgay,
    );

SoLieu soDem(String nhan, int n, {String? ten}) => SoLieu(
      nhan: nhan,
      ten: ten,
      soTho: n.toDouble(),
      chuoi: '$n',
      loai: LoaiSo.soDem,
    );

/// Một NGÀY theo lịch — hàng giao dịch mang nó (bước 2). [SoLieu.chuoi] là
/// `dd/MM`, thêm `/yyyy` khi khác năm của [now]: năm hiện tại in ra là tiếng ồn,
/// năm khác mà thiếu thì sai nghĩa. [SoLieu.soTho] = `yyyy·10000 + MM·100 + dd`
/// — `_khop` của `kiem_so.dart` bóc ngày, tháng, năm lại từ đó.
SoLieu soNgayThang(
  String nhan,
  DateTime ngay, {
  String? ten,
  required DateTime now,
}) {
  String hai(int x) => x.toString().padLeft(2, '0');
  final ngayThang = '${hai(ngay.day)}/${hai(ngay.month)}';
  return SoLieu(
    nhan: nhan,
    ten: ten,
    soTho: (ngay.year * 10000 + ngay.month * 100 + ngay.day).toDouble(),
    chuoi: ngay.year == now.year ? ngayThang : '$ngayThang/${ngay.year}',
    loai: LoaiSo.ngayThang,
  );
}

/// Bảng tra **nhãn → chuỗi** cho mẫu câu — định nghĩa DUY NHẤT, cả sáu gói
/// dùng. Mục **ĐẦU TIÊN** của mỗi nhãn thắng.
///
/// ⚠️ Không phải `{for (final x in soLieu) x.nhan: x.chuoi}`: map literal lấy
/// giá trị **cuối** khi trùng khoá. Từ chặng 4a một gói mang được nhiều mục
/// cùng nhãn (mỗi ngân sách một `Tỉ lệ`, mỗi ví một `Số dư`), và mẫu câu phải
/// nhận mục **tổng hợp** — thứ các gói đặt TRƯỚC danh sách. Khuôn cũ làm câu
/// nhận xét về Giáo dục in tỉ lệ của Mua sắm (bẫy **4.30**), sai **im lặng**,
/// và ca `contains('Giáo dục')` vẫn xanh. Năm gói kia khi ấy chỉ an toàn nhờ
/// đặt nhãn danh sách khác nhãn tổng hợp (`Đang âm` / `Ví đang âm`).
Map<String, String> chuoiTheoNhan(List<SoLieu> soLieu) {
  final s = <String, String>{};
  for (final x in soLieu) {
    s.putIfAbsent(x.nhan, () => x.chuoi);
  }
  return s;
}

abstract class GoiSo {
  /// Tên màn: `ngan_sach` | `phan_tich` | `trang_chu` | `muc_tieu`.
  String get man;

  List<SoLieu> get soLieu;

  bool get thieuDuLieu;

  /// Bản mẫu câu — luôn có, là thứ SLM rơi về.
  NhanXet mauCau();

  String get dauVan => dauVanCua(this);

  /// Tên các **đối tượng** gói mang theo — mặc định là mọi [SoLieu.ten].
  ///
  /// Bộ kiểm số đọc danh sách này để biết chữ số nào nằm **trong một tên**
  /// (`Tiền nhà T9`) chứ không phải một con số (`trichSoNgoaiTen`, bước 1c).
  ///
  /// ⚠️ Gói nào in vào mẫu câu một tên **không** gắn trên [SoLieu] nào thì phải
  /// cộng tên ấy ở đây. Quên thì mẫu câu nêu một tên có chữ số bị chính bộ
  /// kiểm chặn, và câu mô hình nêu đúng tên ấy cũng vậy — im lặng. Đừng gắn
  /// tên ấy lên [SoLieu] để né: làm thế là đổi luật "mục có tên đòi câu nêu
  /// tên" của `kiemNhan`.
  Iterable<String> get tenDoiTuong => [
        for (final s in soLieu)
          if (s.ten != null) s.ten!,
      ];
}
