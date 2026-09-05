import 'package:flutter/material.dart';

/// Màu dùng khi cột `colour` không đọc được.
///
/// Trùng với mặc định của `GoalsCompanion` (`#4CAF50`) để một mục tiêu hỏng dữ
/// liệu nhìn giống mục tiêu bình thường chứ không nhảy ra một màu lạ.
const Color kMauMucTieuMacDinh = Color(0xFF4CAF50);

/// Bộ màu cho bảng chọn ở trang tạo/sửa mục tiêu.
///
/// Lưu xuống CSDL dưới dạng chuỗi `#RRGGBB` — cùng khuôn với cột `colour` của
/// danh mục, để hai nơi đọc được của nhau nếu sau này gộp lại.
const List<String> kMauMucTieu = <String>[
  '#4CAF50',
  '#2196F3',
  '#9C27B0',
  '#FF9800',
  '#F44336',
  '#009688',
  '#795548',
  '#607D8B',
];

/// Bộ biểu tượng cho bảng chọn.
///
/// **Cố ý không chứa `'flag'`** — lá cờ là giá trị dự phòng của
/// [bieuTuongMucTieu], nên nếu nó có mặt ở đây thì phép kiểm "mọi lựa chọn đều
/// tra được" mất hết ý nghĩa: một tên gõ sai vẫn ra lá cờ và trông như đúng.
const List<String> kBieuTuongMucTieu = <String>[
  'savings',
  'directions_car',
  'home',
  'school',
  'flight',
  'phone_iphone',
  'laptop_mac',
  'favorite',
  'card_giftcard',
  'celebration',
];

/// Bảng chọn biểu tượng cho một mục tiêu đang mang [hienTai].
///
/// Nếu giá trị đang lưu không nằm trong [kBieuTuongMucTieu] — chuyện thường
/// gặp với mục tiêu do bản app trước tạo, chúng mang `'flag'` — thì nó được
/// **chèn vào đầu** danh sách.
///
/// Hai phương án đã loại:
/// - *Không chèn gì*: trang sửa mở ra với không ô nào được tô, người dùng
///   tưởng mình chưa chọn biểu tượng bao giờ.
/// - *Tự nhảy sang ô đầu bảng*: đổi biểu tượng sau lưng người dùng chỉ vì họ
///   vào sửa cái tên — đúng loại thay đổi lặng lẽ mà không ai yêu cầu.
List<String> danhSachBieuTuong(String hienTai) {
  if (kBieuTuongMucTieu.contains(hienTai)) return kBieuTuongMucTieu;
  return <String>[hienTai, ...kBieuTuongMucTieu];
}

/// Đọc cột `colour` của mục tiêu thành [Color].
///
/// Chấp nhận cả `#RRGGBB` lẫn `RRGGBB`: cột này đi qua đồng bộ và Admin-web,
/// không có gì bảo đảm mọi hàng đều mang dấu thăng.
///
/// **Không bao giờ ném.** Hàm chạy trong `build()`, nên một ngoại lệ ở đây là
/// màn đỏ trên cả trang danh sách — một hàng dữ liệu hỏng sẽ kéo sập mọi mục
/// tiêu khác chứ không chỉ thẻ của nó.
Color mauMucTieu(String colour) {
  final rutGon = colour.replaceAll('#', '').trim();
  if (rutGon.length != 6) return kMauMucTieuMacDinh;
  final giaTri = int.tryParse('FF$rutGon', radix: 16);
  return giaTri == null ? kMauMucTieuMacDinh : Color(giaTri);
}

/// Đọc cột `icon` của mục tiêu thành [IconData].
///
/// Cột này là chuỗi tự do ở cả hai đầu đồng bộ, nên tên lạ phải hiện được thành
/// một thứ gì đó thay vì làm hỏng thẻ. `'flag'` vừa là mặc định của CSDL vừa là
/// giá trị dự phòng ở đây.
IconData bieuTuongMucTieu(String icon) => switch (icon) {
      'savings' => Icons.savings,
      'directions_car' => Icons.directions_car,
      'home' => Icons.home,
      'school' => Icons.school,
      'flight' => Icons.flight,
      'phone_iphone' => Icons.phone_iphone,
      'laptop_mac' => Icons.laptop_mac,
      'favorite' => Icons.favorite,
      'card_giftcard' => Icons.card_giftcard,
      'celebration' => Icons.celebration,
      _ => Icons.flag,
    };
