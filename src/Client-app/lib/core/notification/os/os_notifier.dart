/// Cửa duy nhất từ app ra hệ thống thông báo của hệ điều hành.
///
/// ## Vì sao file này KHÔNG có conditional import
///
/// Mẫu `lib/core/database/connection/connection.dart` gộp cả trừu tượng lẫn
/// `if (dart.library.io)` vào một file. Ở đây cố ý tách: trừu tượng nằm đây,
/// việc chọn bản cài đặt nằm ở `os_notifier_factory.dart`.
///
/// Lý do là **bẫy 7.7 trong `docs/NOTIFICATION_FEATURE.md`**: một import
/// `flutter_local_notifications` lọt ra ngoài `os_notifier_native.dart` sẽ gãy
/// `flutter build web`, mà `flutter test` **vẫn xanh** (test chạy trên VM, tức
/// nhánh `dart.library.io`). Gộp hai thứ vào một file nghĩa là mọi file muốn
/// nhắc tới kiểu `OsNotifier` — kể cả `notification_scanner.dart` và các test
/// của nó — đều kéo theo nhánh native. Tách ra thì chỉ đúng **một** file trong
/// toàn dự án chạm tới gói ấy, và điều đó kiểm được bằng mắt trong một giây.
abstract class OsNotifier {
  /// `false` trên web và trên mọi nền tảng chưa cài đặt. Nơi gọi dùng nó để
  /// quyết định có hiện giao diện xin quyền hay không — chứ **không** cần kiểm
  /// trước mỗi lần bắn: bản no-op đã tự nuốt mọi lời gọi.
  bool get isSupported;

  /// Khởi tạo plugin, khai báo kênh Android và gắn delegate iOS.
  /// Luỹ đẳng — gọi lại nhiều lần không sao.
  Future<void> init();

  /// Xin quyền thông báo. Trả `true` nếu được cấp.
  ///
  /// Gọi **có ngữ cảnh** (từ trang cài đặt, hoặc ngay sau khi người dùng bật
  /// một công tắc nhắc), không bao giờ lúc mở app lần đầu: trên iOS người dùng
  /// chỉ được hỏi **một lần duy nhất** trong cả vòng đời cài đặt, từ chối là
  /// mất vĩnh viễn và chỉ bật lại được trong Cài đặt hệ thống.
  Future<bool> requestPermission();

  /// Bắn một thông báo **ngay lập tức**.
  ///
  /// [id] phải đến từ `osScheduledId(dedupeKey)` — xem file đó để biết vì sao
  /// không được dùng `String.hashCode`.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Đặt **trước** một thông báo, nổ vào [when] theo giờ địa phương.
  ///
  /// Đây là cách duy nhất để thông báo hiện ra khi app đã đóng hoàn toàn mà
  /// không cần tác vụ nền. [when] trong quá khứ thì Android bắn ngay lập tức
  /// còn iOS lặng lẽ bỏ qua — nơi gọi phải tự lọc.
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  });

  /// Id của các lịch **đang chờ** nổ.
  ///
  /// Cần cho `ReminderScheduler.resync()` để nó luỹ đẳng: biết cái nào đã
  /// đặt rồi thì không đặt lại. Không có nó thì mỗi lần đồng bộ là một vòng
  /// huỷ-rồi-đặt-lại toàn bộ, và mỗi vòng như vậy là một cơ hội để lịch rơi.
  Future<Set<int>> pendingIds();

  /// Huỷ một thông báo/lịch theo id.
  Future<void> cancel(int id);

  /// Huỷ **tất cả**. Bắt buộc gọi khi đăng xuất — xem `NotificationScanner.stop()`.
  Future<void> cancelAll();
}

/// Bản không làm gì cả. Dùng cho web, cho nền tảng chưa hỗ trợ, và cho test.
///
/// Cố ý **nuốt lặng** mọi lời gọi thay vì ném `UnsupportedError`: nơi gọi là
/// vòng quét thông báo, và một ngoại lệ ở đó sẽ đánh sập cả phần trung tâm
/// thông báo trong app — tức là phá luôn phần vẫn chạy tốt trên web.
class NoopOsNotifier implements OsNotifier {
  const NoopOsNotifier();

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<Set<int>> pendingIds() async => const {};

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
