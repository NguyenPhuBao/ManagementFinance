import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Chuẩn hoá tên danh mục để **SO SÁNH**. Tuyệt đối không dùng giá trị trả về
/// để lưu xuống CSDL — tên phải được lưu đúng như người dùng gõ.
///
/// Đây là **định nghĩa duy nhất** của phép so tên danh mục trong toàn dự án.
/// Mọi nơi cần đối chiếu tên — kiểm tra trùng khi tạo/sửa, khử trùng lặp khi
/// hiển thị, dò danh mục mặc định theo tên lúc đồng bộ — đều phải gọi hàm này.
/// Trước đây mỗi nơi tự viết một biến thể, và `CategoryDao.getByName` thì so
/// khớp thẳng bằng `=` nên phân biệt cả hoa/thường.
///
/// Bốn bước, theo đúng thứ tự:
///
/// 1. **NFC** — "Cà phê" gõ từ hai bàn phím khác nhau có thể ra hai chuỗi khác
///    byte (6 ký tự với dạng dựng sẵn, 8 ký tự với dạng tách dấu) mà mắt
///    thường không phân biệt được. Không gộp thì hai danh mục nhìn y hệt nhau
///    vẫn tạo trùng được.
/// 2. **Chữ thường** — "Ăn Uống" và "ăn uống" là một.
/// 3. **Cắt khoảng trắng hai đầu**.
/// 4. **Gom khoảng trắng giữa** — "Cà   phê" và "Cà phê" là một.
///
/// > Vì sao chốt đủ bốn bước ngay từ đầu: **nới lỏng về sau là miễn phí, siết
/// > chặt về sau thì phải dọn dữ liệu.** Bỏ bớt một bước bây giờ nghĩa là mai
/// > kia muốn thêm lại sẽ có sẵn những cặp tên đang tồn tại bỗng trở thành vi
/// > phạm, và `CREATE UNIQUE INDEX` phía PostgreSQL sẽ thất bại cho tới khi có
/// > người đi sửa dữ liệu của người dùng thật.
///
/// Phía backend phải chuẩn hoá **y hệt**:
/// `lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g'))`
/// Lệch một bước là quy tắc thủng, và thủng **âm thầm**.
String normalizeCategoryName(String value) => unorm
    .nfc(value)
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
