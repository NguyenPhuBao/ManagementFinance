/// Các route nằm **bên trong** `StatefulShellRoute.indexedStack` — tức là bốn
/// nhánh của thanh tab dưới cùng.
///
/// Giữ đồng bộ tay với `app_router.dart`. Đáng lẽ suy ra được từ cây route,
/// nhưng go_router không phơi ra danh sách ấy, và một hằng số có test canh thì
/// đọc rõ hơn hẳn một phép dò cây.
const Set<String> nhanhThanhTab = {
  '/home',
  '/analytics',
  '/budget',
  '/profile',
};

/// Route này có kéo theo thanh tab không.
///
/// ## Vì sao câu hỏi này quan trọng
///
/// `context.push()` một route nằm trong shell, khi đang đứng ở một route ngoài
/// shell, bắt go_router dựng **thêm một bản shell thứ hai** chồng lên bản đang
/// có. Hai bản mang cùng page key và Navigator từ chối:
///
/// ```
/// navigator.dart: Failed assertion: '!keyReservation.contains(key)'
/// ```
///
/// App chết màn đỏ. Đúng chuyện đã xảy ra khi bấm vào thông báo ngân sách từ
/// trung tâm thông báo: `/notifications` ngoài shell, `/budget` trong shell.
///
/// Nơi gọi dùng kết quả này để chọn `go` (thay cả stack, chuyển sang đúng tab)
/// thay vì `push`.
bool thuocThanhTab(String route) {
  if (route.isEmpty) return false;
  if (nhanhThanhTab.contains(route)) return true;

  // Route con của một nhánh cũng kéo theo shell — `/analytics/export` là con
  // của `/analytics`. So khớp phải có dấu `/` phía sau, nếu không `startsWith`
  // trần sẽ nuốt luôn `/budgets` vì nó bắt đầu bằng `/budget`.
  return nhanhThanhTab.any((nhanh) => route.startsWith('$nhanh/'));
}
