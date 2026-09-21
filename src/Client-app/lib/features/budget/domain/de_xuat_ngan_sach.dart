/// Chọn những danh mục **đáng đặt ngân sách mà chưa có** — mục ④.
///
/// App vốn chỉ gợi ý *số tiền* **sau khi** người dùng đã tự chọn danh mục; nó
/// chưa bao giờ nói *"danh mục này bạn chi đều mà chưa đặt hạn mức"*. Tệp này
/// là luật ấy, tách thành hàm thuần để test được mà không cần dựng widget.
///
/// ⚠️ **Không lọc `classify` ở đây.** Nguồn duy nhất của [danhMucChi] là
/// `BudgetRepository.getExpenseCategories`, vốn đã chỉ trả danh mục `'chi'`.
/// Thêm một bộ lọc thứ hai là dựng bản chép tay của một luật đã có chỗ đúng
/// duy nhất — và hai bản ấy sẽ lệch nhau vào ngày một bên đổi.
///
/// Spec: `docs/superpowers/specs/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach-design.md`
library;

/// Nhiều nhất ba dòng. Thẻ này là một gợi ý nhẹ, không phải một danh sách việc:
/// dài hơn thì nó đẩy phần còn lại của trang xuống và tự biến mình thành nhiễu.
const int kToiDaDeXuat = 3;

/// Một danh mục đáng đặt ngân sách.
class DeXuatNganSach {
  final String categoryId;
  final String tenDanhMuc;

  /// Mức chi trung bình mỗi tháng, đã làm tròn — chính là `suggestAmount`.
  final double mucThang;

  const DeXuatNganSach({
    required this.categoryId,
    required this.tenDanhMuc,
    required this.mucThang,
  });
}

/// Danh sách đề xuất, kèm độ dài cửa sổ đã dùng để suy ra chúng.
///
/// ⚠️ [soNgayCuaSo] nằm ở **gói**, không lặp ở từng dòng: nó là tính chất của
/// *phép suy*, không phải của danh mục. Giao diện cần nó để nói ra khi con số
/// đến từ một mẫu ngắn — hứa một mức "mỗi tháng" dựng từ hai tuần mà không nói
/// gì là bịa một lời hứa.
class GoiDeXuat {
  final List<DeXuatNganSach> ds;
  final int soNgayCuaSo;

  const GoiDeXuat({required this.ds, required this.soNgayCuaSo});
}

/// Trả `null` khi **không có gì để gợi ý** — chỗ gọi ẩn hẳn thẻ.
///
/// `null` chứ không phải danh sách rỗng: một danh sách rỗng buộc widget tự nghĩ
/// ra luật ẩn, và đó đúng là chỗ luật bị chép ra lần thứ hai.
///
/// [soNgayCuaSo] là `null` khi `cuaSoNhinLai` im (tài khoản quá trẻ). Khi ấy
/// mọi con số trong [mucThangTheoDanhMuc] cũng phải là `null`, nhưng hàm vẫn
/// kiểm tường minh: một lời gọi sai thứ tự không được phép lọt thành gợi ý.
GoiDeXuat? chonDeXuat({
  required List<({String id, String ten})> danhMucChi,
  required Set<String> daCoNganSach,
  required Map<String, double?> mucThangTheoDanhMuc,
  required int? soNgayCuaSo,
}) {
  if (soNgayCuaSo == null) return null;

  final ungVien = <DeXuatNganSach>[];
  for (final c in danhMucChi) {
    if (daCoNganSach.contains(c.id)) continue;
    final muc = mucThangTheoDanhMuc[c.id];
    if (muc == null || muc <= 0) continue;
    ungVien.add(
      DeXuatNganSach(categoryId: c.id, tenDanhMuc: c.ten, mucThang: muc),
    );
  }
  if (ungVien.isEmpty) return null;

  ungVien.sort((a, b) => b.mucThang.compareTo(a.mucThang));
  return GoiDeXuat(
    ds: ungVien.take(kToiDaDeXuat).toList(),
    soNgayCuaSo: soNgayCuaSo,
  );
}
