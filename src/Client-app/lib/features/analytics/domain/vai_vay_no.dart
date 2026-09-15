/// Vai của một khoản vay/nợ — **định nghĩa duy nhất** (A8 #4 và #5, 2026-09-15).
///
/// ## Vì sao phải đoán
///
/// Bốn vai *cho vay · thu nợ · đi vay · trả nợ* **không có chỗ nào lưu**. Một
/// giao dịch chỉ giữ `type` (`thu`/`chi`) và `categoryId`; cả hai đầu — client 9
/// bảng Drift, server 14 bảng — **không đầu nào có bảng khoản vay** (đếm bằng
/// máy 2026-09-15). Chiều tiền vì thế chỉ tách được **hai** nhóm:
///
/// * tiền ra  → *cho vay* **hoặc** *trả nợ*
/// * tiền vào → *thu nợ*  **hoặc** *đi vay*
///
/// Thứ duy nhất tách được bốn là **tên danh mục**, và bốn danh mục mặc định tên
/// đúng bằng bốn vai (`Cho vay`, `Đi vay` từ khuôn server; `Trả nợ`, `Thu nợ` từ
/// `PersonalDefaultCategories`). `suggestDebtDirection` ở màn nhập liệu đã đọc
/// đúng bộ tên ấy từ trước — đây là cùng một ý tưởng, chặt hơn một bậc.
///
/// ## Vì sao KHÔNG bỏ dấu
///
/// `removeVietnameseTones` là phép so **mất thông tin** và chỉ dành cho gợi ý,
/// nơi đoán sai tốn một cú chạm để sửa (quy tắc 7 `CLAUDE.md`). Ở đây đoán sai
/// đẩy tiền sang **nhầm biểu đồ**, và người dùng không sửa được — họ thậm chí
/// không biết là có gì để sửa. Nên chỉ `normalizeCategoryName`: NFC → chữ
/// thường → gom khoảng trắng.
library;

import '../../../core/category/category_classify.dart';
import '../../../core/category/category_name.dart';
import 'khoan_vao_thong_ke.dart';
import 'pham_vi_ky.dart';
import 'phan_loai_dong_tien.dart';
import 'thong_ke_thang.dart';

enum VaiVayNo { choVay, thuNo, diVay, traNo, khac }

/// Vai của một khoản, đọc từ [tenDanhMuc] **và** chiều tiền [loai].
///
/// ⚠️ **Chiều tiền đi trước tên.** Tên nói "cho vay" mà khoản lại là tiền vào
/// thì cái tên đang nói dối — người dùng đổi tên danh mục, hoặc ghi nhầm chiều.
/// Khi ấy trả [VaiVayNo.khac] chứ **không tin tên**: tin nó là để một cột xanh
/// mọc lên giữa chuỗi lẽ ra chỉ có tiền ra, và không gì báo. Phép kiểm ấy nằm
/// sẵn trong cấu trúc hàm — mỗi chiều chỉ tra hai cụm khoá của chính nó.
///
/// Tên chứa **cả hai** cụm của cùng một chiều ("Trả nợ cho vay") thì lấy cụm
/// gặp trước; hiếm tới mức không đáng thêm luật, và cả hai đều nằm trong biểu
/// đồ của chiều ấy.
VaiVayNo vaiVayNoCua({required String? tenDanhMuc, required String loai}) {
  if (tenDanhMuc == null) return VaiVayNo.khac;
  final ten = normalizeCategoryName(tenDanhMuc);
  if (ten.isEmpty) return VaiVayNo.khac;

  switch (loai) {
    case 'chi':
      if (ten.contains('cho vay')) return VaiVayNo.choVay;
      if (ten.contains('trả nợ')) return VaiVayNo.traNo;
      return VaiVayNo.khac;
    case 'thu':
      if (ten.contains('thu nợ')) return VaiVayNo.thuNo;
      if (ten.contains('đi vay')) return VaiVayNo.diVay;
      return VaiVayNo.khac;
    default:
      // `transfer` là tiền đổi chỗ — không phải vay cũng không phải nợ.
      return VaiVayNo.khac;
  }
}

/// Một điểm trên hai biểu đồ vay/nợ: trọn một kỳ, gom theo vai.
class DiemVayNo {
  final Ky ky;

  final double choVay;
  final double thuNo;
  final double diVay;
  final double traNo;

  /// Khoản thuộc nhóm Vay/nợ mà **không đoán được vai**, tách theo chiều tiền.
  ///
  /// Giữ riêng chứ không dồn vào một vai: một khoản tiền ra không rõ tên có thể
  /// là *cho vay* hay *trả nợ*, và chọn bừa một bên là bịa một con số. Giao
  /// diện cho chúng một khối riêng, chỉ hiện khi có.
  final double khacRa;
  final double khacVao;

  const DiemVayNo({
    required this.ky,
    this.choVay = 0,
    this.thuNo = 0,
    this.diVay = 0,
    this.traNo = 0,
    this.khacRa = 0,
    this.khacVao = 0,
  });

  bool get rong =>
      choVay == 0 &&
      thuNo == 0 &&
      diVay == 0 &&
      traNo == 0 &&
      khacRa == 0 &&
      khacVao == 0;
}

/// [soKy] kỳ liên tiếp kết thúc ở [ky], **cũ nhất trước** — cùng quy ước với
/// [chuoiTheoKy], và lùi kỳ cũng mượn nguyên `lui` nên hai biểu đồ tự đi theo
/// bộ chọn phạm vi.
///
/// **Chỉ đếm khoản thuộc nhóm Vay/nợ**, và "thuộc nhóm nào" có đúng một định
/// nghĩa là `phanLoaiCua` — cùng hàm mà vòng tròn "Cơ cấu theo danh mục" dùng.
/// Nhờ vậy hai biểu đồ này và lát Vay/nợ của donut không thể nói hai con số.
///
/// Luật loại khoản chuyển ví và khoản điều chỉnh số dư mượn nguyên
/// `khoanVaoThongKe()`, như mọi phép đếm tiền khác trong tệp domain này.
List<DiemVayNo> chuoiVayNo(
  List<KhoanThuChi> ds, {
  required Ky ky,
  int soKy = kSoKyXuHuong,
}) =>
    [
      for (var i = soKy - 1; i >= 0; i--)
        () {
          final k = lui(ky, i);
          var choVay = 0.0, thuNo = 0.0, diVay = 0.0, traNo = 0.0;
          var khacRa = 0.0, khacVao = 0.0;

          for (final x in ds) {
            if (x.ngay.isBefore(k.from) || !x.ngay.isBefore(k.to)) continue;
            if (!khoanVaoThongKe(
              loai: x.loai,
              categoryId: x.categoryId,
              ghiChu: x.ghiChu,
            )) {
              continue;
            }
            if (phanLoaiCua(loai: x.loai, classifyDanhMuc: x.classify) !=
                kDebtClassify) {
              continue;
            }

            switch (vaiVayNoCua(tenDanhMuc: x.tenDanhMuc, loai: x.loai)) {
              case VaiVayNo.choVay:
                choVay += x.soTien;
              case VaiVayNo.thuNo:
                thuNo += x.soTien;
              case VaiVayNo.diVay:
                diVay += x.soTien;
              case VaiVayNo.traNo:
                traNo += x.soTien;
              case VaiVayNo.khac:
                if (x.loai == 'chi') {
                  khacRa += x.soTien;
                } else if (x.loai == 'thu') {
                  khacVao += x.soTien;
                }
            }
          }

          return DiemVayNo(
            ky: k,
            choVay: choVay,
            thuNo: thuNo,
            diVay: diVay,
            traNo: traNo,
            khacRa: khacRa,
            khacVao: khacVao,
          );
        }(),
    ];
