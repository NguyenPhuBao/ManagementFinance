/// Đọc `priority` của mục tiêu cho đúng nghĩa — G32.
///
/// `priority` là thứ tự người dùng kéo thả; `null` nghĩa là **chưa sắp** và xếp
/// cuối. Client chỉ sinh số **dương**: mọi nhánh của `uuTienSauKhiKeo`
/// (`goal_priority.dart`) cho ra số `>= 1`.
///
/// Nhưng giá trị `0` đã có thật trên server: trước `7675b35` backend ép `null`
/// thành `0` trên đường đồng bộ — `mapEntityFields('goal')` gọi `Number(null)` —
/// nên mục tiêu chưa sắp quay về máy mang `0`, và `0` đứng trước mọi số đã sắp.
/// Tái hiện đầu-cuối trên máy ảo ngày 2026-09-10. Tài liệu xin sửa (đã đóng):
/// `docs/superpowers/backend/DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md`.
///
/// Backend nay giữ `null` khi đẩy, và `database/12` đưa các hàng `<= 0` về
/// `NULL` (đo trên CSDL dev 2026-09-11). Hàm này **vẫn giữ** làm lớp phòng thủ:
/// server chưa áp tệp 12 vẫn còn `0`, và bản client cũ đang giữ `0` cục bộ vẫn
/// có thể đẩy nó lên lại.
///
/// Hàm này là **một định nghĩa** cho ba ranh giới: đọc hàng SQLite thành
/// `GoalEntity`, lưu hàng kéo về, và dựng payload đẩy lên. Áp ở một chỗ mà quên
/// chỗ kia là sắp xếp và kéo thả thấy hai giá trị khác nhau cho cùng một mục
/// tiêu — kéo thả sẽ tính khe từ một số `0` mà danh sách lại xếp như chưa sắp.
///
/// Thuần Dart, không import gì, để `core/sync` dùng được mà không kéo theo tầng
/// dữ liệu của mục tiêu.
library;

/// [giaTri] nếu đó là thứ client có thể đã sinh ra; ngược lại `null` — chưa sắp.
int? uuTienHopLe(int? giaTri) => giaTri != null && giaTri > 0 ? giaTri : null;
