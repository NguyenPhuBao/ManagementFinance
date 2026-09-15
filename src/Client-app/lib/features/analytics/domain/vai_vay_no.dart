/// Vai của một khoản vay/nợ — **định nghĩa duy nhất** (A8 #4 và #5, 2026-09-15).
///
/// ## Tên là QUAN HỆ, chiều tiền là VAI
///
/// Bốn vai *cho vay · thu nợ · đi vay · trả nợ* **không có cột nào lưu**, và cả
/// hai đầu — client 9 bảng Drift, server 14 bảng — **không đầu nào có bảng khoản
/// vay** (đếm bằng máy 2026-09-15). Nhưng chúng **suy ra được**, và không phải
/// bằng cách đoán mò:
///
/// Màn Thêm giao dịch, khi danh mục thuộc nhóm Vay/nợ, hiện thêm một ô **"Chiều
/// tiền"** (Tiền ra / Tiền vào) — `suggestDebtDirection` chỉ **chọn sẵn** một
/// bên, người dùng đổi được. Nghĩa là tên danh mục nói **quan hệ nợ nào**, còn
/// `type` nói **lần này tiền chạy chiều nào**:
///
/// | Danh mục | Tiền ra | Tiền vào |
/// |---|---|---|
/// | `Cho vay` | cho vay | **thu nợ** |
/// | `Đi vay`  | **trả nợ** | đi vay |
///
/// Nhờ vậy **hai** danh mục mặc định đủ để ghi cả **bốn** vai — đúng cách app đã
/// thiết kế từ trước, và tài khoản thật trên máy ảo chỉ có đúng hai danh mục ấy
/// (`Cho vay`, `Đi vay`; `Trả nợ`/`Thu nợ` đã bị xoá mềm trên server).
///
/// ⚠️ Bản đầu của tệp này hiểu ngược — coi "Cho vay + tiền vào" là **tên nói
/// dối** và xếp vào `khac`. Chạy thử trên máy ảo mới thấy ô "Chiều tiền" và biết
/// là sai: luật ấy làm hai cột *Thu nợ* và *Trả nợ* **không bao giờ có số**.
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

/// Vai của một khoản: **tên** cho biết quan hệ nợ, **chiều tiền** cho biết vai.
///
/// Tên chứa cả cụm của hai quan hệ ("Cho vay & trả nợ") thì lấy quan hệ *cho
/// vay* — hiếm tới mức không đáng một luật thứ hai, và thứ tự phải **cố định**
/// để hai lần đọc cùng một hàng không ra hai kết quả.
VaiVayNo vaiVayNoCua({required String? tenDanhMuc, required String loai}) {
  // `transfer` là tiền đổi chỗ — không phải vay cũng không phải nợ.
  if (loai != 'chi' && loai != 'thu') return VaiVayNo.khac;
  if (tenDanhMuc == null) return VaiVayNo.khac;

  final ten = normalizeCategoryName(tenDanhMuc);
  if (ten.isEmpty) return VaiVayNo.khac;
  final tienRa = loai == 'chi';

  // Quan hệ "tôi cho người khác vay": tiền ra là cho vay, tiền về là thu nợ.
  if (ten.contains('cho vay') || ten.contains('thu nợ')) {
    return tienRa ? VaiVayNo.choVay : VaiVayNo.thuNo;
  }
  // Quan hệ "tôi vay của người khác": tiền vào là đi vay, tiền ra là trả nợ.
  if (ten.contains('đi vay') || ten.contains('trả nợ')) {
    return tienRa ? VaiVayNo.traNo : VaiVayNo.diVay;
  }
  return VaiVayNo.khac;
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
