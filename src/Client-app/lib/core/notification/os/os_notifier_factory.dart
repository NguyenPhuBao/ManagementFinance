import 'os_notifier.dart';

import 'os_notifier_stub.dart'
    if (dart.library.js_interop) 'os_notifier_web.dart'
    if (dart.library.html) 'os_notifier_web.dart'
    if (dart.library.io) 'os_notifier_native.dart' as impl;

/// Chọn bản cài đặt `OsNotifier` theo nền tảng.
///
/// Đây là **file duy nhất** trong dự án dẫn tới `os_notifier_native.dart`, tức
/// là gián tiếp tới `flutter_local_notifications`. Giữ nguyên như vậy: xem
/// chú thích đầu `os_notifier.dart` để biết vì sao trừu tượng và việc chọn
/// nền tảng lại nằm ở hai file khác nhau, trái với mẫu ở
/// `lib/core/database/connection/`.
///
/// Nơi gọi duy nhất là chỗ dựng phụ thuộc. Không import file này ở tầng
/// nghiệp vụ — nhận `OsNotifier` qua tham số thay vì tự đi tìm.
OsNotifier createOsNotifier() => impl.createOsNotifier();
