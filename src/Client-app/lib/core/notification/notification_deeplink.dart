// `goalDeeplink()` là định nghĩa DUY NHẤT của đường dẫn tới một mục tiêu; dùng
// lại nó thay vì ghép '/goals/$id' ở đây, để hai nơi không thể lệch nhau.
import 'notification_rules.dart' show goalDeeplink;

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

/// Nơi rơi về khi không suy ra được gì. Trung tâm thông báo luôn mở được, và
/// từ đó người dùng vẫn thấy đúng thông báo mình vừa bấm.
const String routeThongBao = '/notifications';

/// Suy route từ `dedupeKey` — dùng khi người dùng **chạm vào thông báo cấp hệ
/// điều hành**.
///
/// ## Vì sao không tra cột `deeplink` trong CSDL
///
/// Cú chạm chỉ mang theo `payload = dedupeKey`. Ở **cold start** — lịch nhắc
/// nổ khi app đã đóng hẳn, tức là ca **chính** của loại lịch đặt trước — hàng
/// tương ứng còn chưa tồn tại: vòng quét mới sinh ra nó *sau khi* app khởi
/// động xong. Tra CSDL ở đó là một cuộc đua, và thua cuộc đua ấy nghĩa là cú
/// chạm không đi đâu cả.
///
/// ## Đây là một bản SAO, và nó được canh
///
/// Thông tin này đã có sẵn ở `NotificationCandidate.deeplink`. Nhân bản là
/// điều dự án này vốn tránh, nên đi kèm một phép canh trong
/// `notification_deeplink_test.dart`: nó dựng ứng viên thật cho **cả 14 loại**
/// rồi khẳng định hàm này trả về đúng cột `deeplink` bộ luật đã đặt. Thêm loại
/// thứ 15 mà quên ánh xạ là test đỏ ngay.
///
/// ⚠️ **Hai nhánh KHÔNG nằm trong phép canh ấy**, vì chúng không ứng với
/// `NotificationKind` nào: `ghiChep` (lời nhắc ghi chép hằng ngày, mục 4.7 —
/// chỉ sống ở tầng hệ điều hành, không có hàng trong `AppNotifications`) và
/// `billOpen` (payload của nút "Trả ngay", xem `notification_actions.dart`).
/// Cả hai có test riêng. Sửa chúng thì phép canh 14 loại **không** đỏ.
///
/// **Không bao giờ ném và không bao giờ trả `null`.** Khoá đến từ payload của
/// hệ điều hành: nó có thể là lịch do một bản app cũ đặt và vẫn còn nằm trong
/// AlarmManager sau khi nâng cấp.
String deeplinkTuDedupeKey(String key) {
  final phan = key.split(':');

  switch (phan.first) {
    case 'budgetNear':
    case 'budgetOver':
      return '/budget';

    case 'billDue':
    case 'billOverdue':
    case 'billAuto':
    case 'billAutoFail':
      return '/bills';

    case 'goalDone':
    case 'goalCycle':
    case 'goalBehind':
    case 'goalMilestone':
    case 'goalAuto':
    case 'goalAutoFail':
      // Id nằm ở đoạn THỨ HAI, không phải đoạn cuối: `khoaKyTrich` sinh
      // "<goalId>:<yyyy-MM-dd>T<HH>:<mm>", nên khoá đầy đủ có bốn đoạn và
      // `split(':').last` sẽ ra "00".
      if (phan.length < 2 || phan[1].isEmpty) return routeThongBao;
      return goalDeeplink(phan[1]);

    // Payload của nút "Trả ngay" — xem `notification_actions.dart`. Khác nhánh
    // `billDue` ở trên đúng một điểm: cú **chạm** thường mở danh sách hoá đơn
    // (đúng cột `deeplink` mà bộ luật đặt, và có phép canh cả 14 loại), còn cái
    // nút thì đã biết chính xác hoá đơn nào — đổ người dùng về danh sách là vứt
    // đi thông tin mình đang cầm.
    //
    // `/bills/<id>` nằm NGOÀI `StatefulShellRoute` y như `/bills`, nên `push`
    // chạy tốt. Kéo nó vào một nhánh tab thì phải cập nhật `nhanhThanhTab` cùng
    // lúc, nếu không bấm nút sẽ làm app chết màn đỏ (bẫy 7.8).
    case 'billOpen':
      if (phan.length < 2 || phan[1].isEmpty) return '/bills';
      return '/bills/${phan[1]}';

    case 'walletNeg':
    case 'walletLow':
      return '/wallets';

    // Lời nhắc ghi chép hằng ngày — khoá do `ghiChepDedupeKey()` sinh. Khác
    // mọi nhánh còn lại: nó **không** ứng với hàng nào trong
    // `AppNotifications`, nên phép canh 14 loại ở test không chạm tới nó và
    // nhánh này có test riêng.
    //
    // Đây là loại nhắc duy nhất bảo người dùng đi làm một việc cụ thể, nên nó
    // đổ thẳng vào trang ghi chứ không về trung tâm thông báo. `/add` nằm
    // NGOÀI `StatefulShellRoute` nên `push` chạy tốt — kéo nó vào một nhánh
    // tab thì phải cập nhật `nhanhThanhTab` cùng lúc (bẫy 7.8).
    case 'ghiChep':
      return '/add';

    // `syncFailed` và mọi khoá lạ: không có màn nào để mở.
    default:
      return routeThongBao;
  }
}
