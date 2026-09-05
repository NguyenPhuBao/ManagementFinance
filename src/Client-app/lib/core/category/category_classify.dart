import 'category_name.dart';

/// Ba phân loại danh mục, theo đúng thứ tự tab ở mọi màn hình: trang quản lý
/// danh mục, bảng chọn danh mục khi tạo giao dịch, form tạo danh mục/nhóm.
///
/// Đây là **danh sách duy nhất**. Trước đây nó bị chép tay ở năm chỗ, nên khi
/// bảng chọn danh mục lúc tạo giao dịch quên tab thứ ba thì bốn danh mục
/// vay/nợ mặc định tạo được mà không gán được vào giao dịch nào — và không có
/// gì báo lỗi.
///
/// Giá trị lưu ở SQLite là dạng chữ thường này; backend dùng `Thu`/`Chi`/
/// `Vay/no` và `SyncPayloadNormalizer` quy đổi hai chiều.
const List<String> kCategoryClassifies = ['chi', 'thu', 'vay_no'];

/// Phân loại vay/nợ — phân loại duy nhất gom **cả hai chiều tiền**.
const String kDebtClassify = 'vay_no';

String categoryClassifyLabel(String classify) => switch (classify) {
      'chi' => 'Khoản chi',
      'thu' => 'Khoản thu',
      kDebtClassify => 'Vay / nợ',
      _ => classify,
    };

bool isDebtClassify(String classify) => classify == kDebtClassify;

/// Đoán chiều tiền cho một danh mục vay/nợ theo tên: trả về `'chi'` (tiền ra)
/// hoặc `'thu'` (tiền vào) — đúng bộ giá trị `transactions.type` đang dùng.
///
/// Vì sao phải đoán: `chi` và `thu` tự nói lên chiều tiền, còn `vay_no` thì
/// không — *Cho vay* và *Trả nợ* là tiền ra, *Đi vay* và *Thu nợ* là tiền vào,
/// và không có cột nào ở client lẫn backend ghi chiều. Form tạo giao dịch gợi
/// sẵn theo hàm này rồi để người dùng đổi, nên đoán sai chỉ tốn một cú chạm.
/// **Đừng** dùng kết quả này ở nơi không có người dùng sửa lại.
///
/// So khớp bằng `normalizeCategoryName` (giữ dấu), không bỏ dấu: bốn tên mặc
/// định luôn có dấu, và bỏ dấu chỉ mở thêm đường đoán nhầm.
String suggestDebtDirection(String categoryName) {
  final name = normalizeCategoryName(categoryName);
  const tienVao = ['đi vay', 'thu nợ'];
  const tienRa = ['cho vay', 'trả nợ'];
  if (tienVao.any(name.contains)) return 'thu';
  if (tienRa.any(name.contains)) return 'chi';
  // Không nhận ra thì coi là tiền ra: phần lớn khoản vay/nợ người dùng tự đặt
  // tên là tiền họ đưa đi, và chọn sai thì đổi được ngay trên form.
  return 'chi';
}
