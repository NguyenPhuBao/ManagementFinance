import 'wallet_status.dart';

/// "Ví này có được cộng vào tổng tài sản không" — **định nghĩa duy nhất**.
///
/// ## Vì sao là một hàm thuần, không phải một phương thức
///
/// Luật này cần chạy trên **hai kiểu dữ liệu khác nhau**: `WalletEntity` ở
/// tầng repository, và hàng Drift `Wallet` ở trang chủ và ở báo cáo. Nhận
/// tham số nguyên thuỷ nên nó dùng được cho cả hai mà không kéo Drift vào
/// tầng domain — cùng khuôn với `vi_chon_san.dart`.
///
/// ## Nó thay cái gì
///
/// Trước bản này luật tồn tại ở ba bản chép tay không khớp nhau:
/// `getTotalBalance` lọc `includeInTotal` đúng, còn `home_page.dart` và
/// `bao_cao_repository_impl.dart` cộng `fold` trần trên mọi ví — nên ví người
/// dùng đã cố ý loại khỏi tổng vẫn phình con số ở trang chủ, và "số dư cuối
/// kỳ" của báo cáo thừa đúng khoản ấy. `WalletCubit.addWallet` là bản thứ tư,
/// đã đóng ở `6fd2ce9`.
///
/// ## Vì sao lưu trữ là phép SUY RA, không ghi đè
///
/// Lưu trữ một ví **không chạm** cờ `includeInTotal`; nó chỉ thêm một vế vào
/// phép hỏi ở đây. Nhờ vậy bỏ lưu trữ là mọi con số cũ tự quay lại đúng như
/// trước, kể cả với ví vốn đã bị người dùng loại khỏi tổng từ lâu.
///
/// ## Vế thứ ba: ví đã XOÁ MỀM (thêm 2026-09-16, G42)
///
/// Phần lớn chỗ gọi đọc ví qua `walletDao.getAll`/`watchAll`, và hai hàm ấy
/// đã lọc `deletedAt` — nên vế này thường thừa. Nhưng **không phải mọi chỗ**:
/// `AnalyticsRepositoryImpl` truy vấn thẳng `db.select(db.wallets)` và **cố ý
/// giữ hàng đã xoá**, vì giao dịch cũ vẫn trỏ vào ví ấy và bảng tra tên cần
/// nó. Hàng ấy rồi được cộng `balance` qua đúng hàm này, nên "số dư cuối kỳ"
/// của khối Dòng tiền và thác nước phình lên đúng số dư của ví người dùng đã
/// xoá — im lặng, đo được 7.000.000 trên một tài khoản thử.
///
/// Đặt vế này **trong hàm** chứ không ở chỗ gọi là có chủ ý: tệp test đi kèm
/// sinh ra để chặn "bản chép tay thứ năm" của luật này, và sự cố trên đúng là
/// bản thứ năm — chỉ khác ở chỗ nó quên một vế khác. Chỗ gọi thứ sáu không
/// được phép quên lần nữa.
///
/// [isDeleted] mặc định `false` để những chỗ đã lọc sẵn ở tầng truy vấn không
/// phải sửa gì.
bool viTinhVaoTong({
  required bool includeInTotal,
  String? status,
  bool isDeleted = false,
}) =>
    !isDeleted && includeInTotal && WalletStatus.laHoatDong(status);
