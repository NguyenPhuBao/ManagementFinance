import 'os_notifier.dart';

/// Nhánh mặc định khi không có `dart.library.io` lẫn `dart.library.js_interop`.
///
/// Trả bản không làm gì thay vì ném: một nền tảng lạ không được phép làm chết
/// trung tâm thông báo trong app.
OsNotifier createOsNotifier() => const NoopOsNotifier();
