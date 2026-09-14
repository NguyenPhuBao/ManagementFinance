/// "Khoản này thuộc phân loại nào" — **định nghĩa duy nhất** — và phép gom ba
/// lát của vòng tròn "Cơ cấu dòng tiền".
///
/// ## Hai thứ dễ nhầm là một
///
/// - `transaction.type`: `'thu'` · `'chi'` · `'transfer'` — **chiều tiền**.
/// - `category.classify`: `'thu'` · `'chi'` · `'vay_no'` — **phân loại danh
///   mục**.
///
/// Một khoản *Trả nợ* mang `type = 'chi'` nhưng `classify = 'vay_no'`. Bảng A8
/// mục 2 hỏi theo **classify**.
///
/// ⚠️ Đừng gộp với `chiTheoDanhMuc()` ở `thong_ke_thang.dart`: hàm kia gom theo
/// **chiều tiền** để phục vụ trang Xuất báo cáo (bảng "Thu theo danh mục" và
/// "Chi theo danh mục"), còn ở đây gom theo **phân loại danh mục**. Hai câu hỏi
/// khác nhau; gộp lại "cho gọn" sẽ làm bảng của báo cáo đổi nghĩa mà không test
/// nào ở đó đỏ.
library;

import '../../../core/category/category_classify.dart';
import 'khoan_vao_thong_ke.dart';
import 'thong_ke_thang.dart';

/// Phân loại của một khoản: `classify` của danh mục nó gắn, rơi về [loai] khi
/// không tra được danh mục.
///
/// Nhánh rơi về là **bắt buộc**, không phải phòng hờ: đo trên CSDL ngày
/// 2026-09-10 có 17 hàng giao dịch trống danh mục thật trên server, và giao
/// dịch kéo về có thể trỏ vào một danh mục chưa đồng bộ tới máy này. Loại chúng
/// khỏi thống kê là giấu mất chi tiêu thật — cùng lý lẽ với
/// `khoan_vao_thong_ke.dart`.
///
/// Giá trị `classify` lạ cũng rơi về [loai]: một lát thứ tư mang tên vô nghĩa
/// tệ hơn là xếp nhầm vào lát đúng chiều tiền.
String phanLoaiCua({required String loai, String? classifyDanhMuc}) {
  if (classifyDanhMuc != null &&
      kCategoryClassifies.contains(classifyDanhMuc)) {
    return classifyDanhMuc;
  }
  return loai;
}

/// Một lát của vòng tròn "Cơ cấu dòng tiền".
class LatPhanLoai {
  /// Một trong `kCategoryClassifies`.
  final String phanLoai;
  final double soTien;

  /// Tỉ lệ trên tổng của **cả ba lát**, trong `[0, 1]`.
  final double tiLe;

  const LatPhanLoai({
    required this.phanLoai,
    required this.soTien,
    required this.tiLe,
  });
}

/// Ba lát rời nhau, **sắp giảm dần** theo số tiền.
///
/// Lát có số tiền 0 **bị bỏ** chứ không trả về với `tiLe = 0`: donut không vẽ
/// được lát rỗng, và giao diện không cho chạm vào một lát không tồn tại.
///
/// Hoà thì sắp theo thứ tự `kCategoryClassifies` để hai lần dựng không đảo chỗ
/// nhau — cùng lý do với `chiTheoDanhMuc`.
List<LatPhanLoai> theoPhanLoai(
  List<KhoanThuChi> ds, {
  required DateTime from,
  required DateTime to,
}) {
  final gom = <String, double>{};
  var tong = 0.0;
  for (final k in ds) {
    if (k.ngay.isBefore(from) || !k.ngay.isBefore(to)) continue;
    // Một định nghĩa duy nhất cho "hàng này có được tính không" — nó loại cả
    // khoản chuyển, khoản điều chỉnh số dư lẫn khoản mở sổ.
    if (!khoanVaoThongKe(
      loai: k.loai,
      categoryId: k.categoryId,
      ghiChu: k.ghiChu,
    )) {
      continue;
    }
    final pl = phanLoaiCua(loai: k.loai, classifyDanhMuc: k.classify);
    gom[pl] = (gom[pl] ?? 0) + k.soTien;
    tong += k.soTien;
  }
  if (tong <= 0) return const [];

  return [
    for (final e in gom.entries)
      if (e.value > 0)
        LatPhanLoai(phanLoai: e.key, soTien: e.value, tiLe: e.value / tong),
  ]..sort((a, b) {
      final c = b.soTien.compareTo(a.soTien);
      if (c != 0) return c;
      return kCategoryClassifies
          .indexOf(a.phanLoai)
          .compareTo(kCategoryClassifies.indexOf(b.phanLoai));
    });
}

/// Danh mục **bên trong** một lát, sắp giảm dần theo số tiền.
///
/// Tỉ lệ tính trên tổng **của lát**, không phải trên tổng cả ba lát: người dùng
/// đã chạm vào lát rồi, câu hỏi lúc này là "trong nhóm này, cái nào lớn".
///
/// Tổng các dòng trả về **bằng đúng** [LatPhanLoai.soTien] của cùng lát — đó là
/// điều giữ cho donut và danh sách cuối trang nói cùng một con số.
///
/// Lát `vay_no` là phân loại **duy nhất** gom cả hai chiều tiền (Đi vay và Thu
/// nợ là tiền vào; Cho vay và Trả nợ là tiền ra), nên số tiền ở đây là **tổng
/// tuyệt đối tiền đi qua** nhóm ấy, không phải số ròng.
List<ChiTheoDanhMuc> danhMucTheoPhanLoai(
  List<KhoanThuChi> ds, {
  required DateTime from,
  required DateTime to,
  required String phanLoai,
}) {
  final gom = <String?, double>{};
  var tong = 0.0;
  for (final k in ds) {
    if (k.ngay.isBefore(from) || !k.ngay.isBefore(to)) continue;
    if (!khoanVaoThongKe(
      loai: k.loai,
      categoryId: k.categoryId,
      ghiChu: k.ghiChu,
    )) {
      continue;
    }
    if (phanLoaiCua(loai: k.loai, classifyDanhMuc: k.classify) != phanLoai) {
      continue;
    }
    gom[k.categoryId] = (gom[k.categoryId] ?? 0) + k.soTien;
    tong += k.soTien;
  }
  if (tong <= 0) return const [];

  return [
    for (final e in gom.entries)
      ChiTheoDanhMuc(categoryId: e.key, soTien: e.value, tiLe: e.value / tong),
  ]..sort((a, b) {
      final c = b.soTien.compareTo(a.soTien);
      if (c != 0) return c;
      if (a.categoryId == null) return 1;
      if (b.categoryId == null) return -1;
      return a.categoryId!.compareTo(b.categoryId!);
    });
}

/// Nhãn của mẫu số khi hiện "% của lát" — "32% tổng chi", "8% vay/nợ".
String nhanTongCua(String phanLoai) => switch (phanLoai) {
      'thu' => 'tổng thu',
      kDebtClassify => 'vay/nợ',
      _ => 'tổng chi',
    };

/// Nhãn **ngắn** của một lát, cho chú giải donut: `Thu` · `Chi` · `Vay / nợ`.
///
/// ⚠️ Cố ý **không** dùng `categoryClassifyLabel` của `category_classify.dart`:
/// hàm ấy trả `'Khoản chi'`/`'Khoản thu'` — nhãn cho **tab chọn danh mục**, nơi
/// có cả chiều ngang màn hình. Chú giải donut nằm trong một cột rộng 180px
/// cạnh vòng tròn, và màn Stitch `c2a2b615…` ghi `Thu`/`Chi`. Hai nhãn cho hai
/// chỗ; nếu sau này cần đổi chữ thì đổi ở đúng chỗ dùng nó.
String tenLat(String phanLoai) => switch (phanLoai) {
      'thu' => 'Thu',
      kDebtClassify => 'Vay / nợ',
      _ => 'Chi',
    };
