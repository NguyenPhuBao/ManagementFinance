/// Nút hành động trên thông báo hệ điều hành — phần **quyết định**.
///
/// ## Vì sao file này tồn tại tách khỏi `os_notifier_native.dart`
///
/// Cùng lý do đã tách `OsNotifier` khỏi bản cài đặt của nó (bẫy 7.7): file kia
/// là nơi DUY NHẤT trong dự án được import `flutter_local_notifications`. Thêm
/// vào đó, handler của nút hành động chạy trong **isolate nền** khi app đã
/// đóng — không DI, không CSDL mở sẵn, và `flutter test` không dựng được ngữ
/// cảnh ấy. Nên mọi phép quyết định nằm ở đây, dưới dạng hàm thuần có test;
/// file kia chỉ còn là lớp vỏ gọi plugin.
///
/// ## Vì sao KHÔNG có nút "Đã trả"
///
/// Nghe thì hợp lý nhất, nhưng `payBill` **chuyển tiền thật**: nó tạo giao dịch
/// và trừ ví thanh toán. Chạy việc ấy trong isolate nền nghĩa là chuyển tiền ở
/// một nơi không có giao diện, không xác nhận ví, và không có chỗ nào báo lỗi
/// nếu ví thiếu tiền — đi ngược đúng nguyên tắc mà `GOAL_FEATURE.md` mục 3.12
/// và spec tự động thanh toán hoá đơn đã chốt cho **hai** chỗ còn lại trong app
/// tự chuyển tiền. Người muốn một chạm là trả thì đã có `bills.autoPayEnabled`.
///
/// Nút thay thế là **"Trả ngay"**, và nó không ghi gì cả: chỉ mở đúng hoá đơn
/// ấy để người dùng trả bằng luồng bình thường.
library;

/// Mã hành động, đi thẳng vào `AndroidNotificationAction.id` và
/// `DarwinNotificationAction.identifier`, rồi quay về trong
/// `NotificationResponse.actionId`.
///
/// ⚠️ Giá trị này nằm trong lịch **đã đặt** ở AlarmManager, nên một lịch do bản
/// app cũ đặt vẫn trả về mã cũ sau khi nâng cấp. Đổi chuỗi ở đây là những lịch
/// ấy bấm vào không làm gì — im lặng. Thêm mã mới thì được, đổi mã cũ thì không.
const String hanhDongTraNgay = 'bill_tra_ngay';
const String hanhDongHoan = 'bill_hoan';

/// Tiền tố khoá của những thông báo được gắn nút.
///
/// Chỉ nhắc hoá đơn. "Hoãn" chỉ có nghĩa với một lời nhắc **đặt trước**; gắn nó
/// lên cảnh báo ví âm hay lời nhắc ghi chép là hứa một hành vi không tồn tại.
const Set<String> _tienToCoNut = {'billDue', 'billOverdue'};

/// Khoảng dời của một lần "Hoãn".
///
/// Đếm từ lúc **bấm**, không phải từ giờ nhắc đã cài. Ngoài chuyện đó là điều
/// người dùng mong đợi, nó còn tránh hẳn bẫy 7.3: một khoảng thời gian tuyệt
/// đối không cần biết múi giờ, mà isolate nền thì không đọc được múi giờ của
/// máy — `tz.local` ở đó rơi về UTC.
const Duration buocHoan = Duration(days: 1);

/// Thông báo mang khoá này có được gắn nút hành động không.
bool coHanhDong(String dedupeKey) {
  if (dedupeKey.isEmpty) return false;
  return _tienToCoNut.contains(dedupeKey.split(':').first);
}

/// Payload cho nút "Trả ngay" — mở **đúng** hoá đơn ấy.
///
/// Trả về một khoá `billOpen:<billId>` chứ không phải một route, để nó đi qua
/// đúng đường cũ: `deeplinkTuDedupeKey()` là nơi duy nhất suy route từ khoá.
/// Nhờ vậy không phải nới `payloadDaCham` từ `Stream<String>` thành một cặp
/// (actionId, payload) — tức là không phải chạm vào `NotificationTapRouter` và
/// bộ test của nó.
///
/// `null` khi khoá không mang id: lịch có thể do bản app cũ đặt và vẫn nằm
/// trong AlarmManager sau khi nâng cấp. Nơi gọi rơi về cú chạm thường thay vì
/// dựng `billOpen:` rồi đẩy người dùng vào một màn trống.
String? payloadTraNgay(String dedupeKey) {
  if (!coHanhDong(dedupeKey)) return null;
  final phan = dedupeKey.split(':');
  if (phan.length < 2 || phan[1].isEmpty) return null;
  return 'billOpen:${phan[1]}';
}

/// Khoá cuối cùng dùng để suy route, **sau khi** đã tính tới nút người dùng bấm.
///
/// ## Vì sao phải là một hàm dùng chung
///
/// Có **hai** đường vào cho một cú bấm nút "Trả ngay", và chúng không đi qua
/// nhau:
///
/// * app đang sống → `onDidReceiveNotificationResponse`;
/// * app đã đóng hẳn → nền tảng mở app, rồi `payloadKhoiDong()` hỏi
///   `getNotificationAppLaunchDetails()`.
///
/// Bản đầu chỉ xử lý đường thứ nhất, và trên máy thật (2026-09-07) nút "Trả
/// ngay" ở cold start mở đúng **danh sách** hoá đơn thay vì hoá đơn ấy — vì
/// đường thứ hai đọc `payload` mà bỏ qua `actionId`. Không lỗi, không log: nó
/// chỉ đi sai chỗ. Gom phép quyết định vào một hàm là để hai đường không thể
/// lệch nhau nữa.
///
/// [hanhDongHoan] **không** đi qua đây: nó xong việc ngay tại chỗ và không mở
/// màn nào. Nhưng hàm vẫn trả về khoá gốc cho mọi mã lạ, vì lịch do một bản app
/// cũ đặt có thể mang mã không còn ai biết.
String khoaSauChamNut({required String? actionId, required String payload}) {
  if (actionId != hanhDongTraNgay) return payload;
  return payloadTraNgay(payload) ?? payload;
}

/// Một lịch nhắc lại sau khi người dùng bấm "Hoãn".
class LichHoan {
  /// **Giữ nguyên khoá cũ** — xem chú thích ở [lichHoan].
  final String khoa;
  final DateTime when;
  final String title;
  final String body;

  const LichHoan({
    required this.khoa,
    required this.when,
    required this.title,
    required this.body,
  });
}

/// Lịch đặt lại sau một lần "Hoãn", hoặc `null` nếu khoá không có nút.
///
/// ## Vì sao giữ NGUYÊN khoá
///
/// Cùng khoá nghĩa là cùng `osScheduledId`, và `ReminderScheduler.resync()`
/// nhận ra id ấy thuộc về hoá đơn nào. Nhờ vậy lịch hoãn **không cần lưu trạng
/// thái ở đâu cả** — không cột CSDL, không SharedPreferences, không gì mà
/// isolate nền phải với tới.
///
/// ⚠️ **Riêng việc giữ khoá KHÔNG đủ**, và bản đầu đã sai đúng ở đây. Lý lẽ
/// ban đầu là "resync bỏ qua id đã nằm trong hàng chờ nên lịch hoãn sống sót".
/// Sai: nhánh ấy chỉ chạy cho lịch resync **muốn**, mà một hoá đơn chỉ được
/// muốn khi mốc nhắc còn ở tương lai — trong khi người dùng chỉ bấm "Hoãn"
/// được **sau khi** thông báo đã nổ, tức mốc gốc luôn đã qua. Máy ảo bắt được
/// điều này ngày 2026-09-07: lịch hoãn đặt xong, mở app một lượt là mất.
///
/// Thứ thật sự giữ nó lại là tập `khongHuy` trong `resync()` — xem chú thích ở
/// đó. Hoá đơn được trả hoặc xoá thì id rời khỏi tập ấy và lịch hoãn bị dọn
/// như mọi lịch thừa khác.
///
/// ## Vì sao câu chữ chung chung
///
/// Isolate nền không mở CSDL, nên nó không biết hoá đơn tên gì hay còn mấy
/// ngày. Đoán rồi nói sai còn tệ hơn nói ít — một thông báo nói sai là thứ
/// người dùng tắt ngay lần đầu gặp.
LichHoan? lichHoan({
  required String dedupeKey,
  required DateTime now,
  Duration buoc = buocHoan,
}) {
  if (!coHanhDong(dedupeKey)) return null;
  return LichHoan(
    khoa: dedupeKey,
    when: now.add(buoc),
    title: 'Nhắc lại: hoá đơn đến hạn',
    body: 'Mở app để xem và thanh toán.',
  );
}
