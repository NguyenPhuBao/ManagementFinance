import 'os_notifier.dart';

/// Web không có thông báo cấp hệ điều hành trong phạm vi dự án này.
///
/// Trình duyệt *có* Notification API, nhưng nó đòi Service Worker và một luồng
/// xin quyền riêng, còn FlowMoney trên web chỉ dùng để trình bày và kiểm thử.
/// Trung tâm thông báo trong app vẫn chạy đầy đủ ở đây — phần này chỉ tắt lối
/// ra hệ điều hành.
OsNotifier createOsNotifier() => const NoopOsNotifier();
