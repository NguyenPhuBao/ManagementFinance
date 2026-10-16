/// Dung sai khi so số tiền: **nửa đồng**.
///
/// `amount` là `double`, và khoản **điều chỉnh số dư** mang đuôi lẻ có thật. Một
/// khoản đúng `500.000` mà máy giữ là `499999.99999994` sẽ rơi khỏi bộ lọc
/// "từ 500.000" — không exception, không log, chỉ một dòng biến mất khỏi danh
/// sách. Cùng ngưỡng mà `dieu_chinh_so_du_service.dart` và `ranhVuotTrungBinh`
/// đã dùng cho đúng loại đuôi lẻ này.
///
/// Ở `core/utils/` từ 2026-10-16 (trước ở `transaction/domain/khoang_tien.dart`): ngưỡng của tiền dạng `double`, không
/// của mảng nào — `category/domain/phan_loai_so_tien.dart` cần nó mà không được đọc transaction (quét 29).
const double kDungSaiTien = 0.5;
