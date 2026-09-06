import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'notification_prefs.dart';

/// Nơi lưu tuỳ chọn thông báo, tách riêng **theo từng tài khoản**.
///
/// Bọc sau interface theo đúng mẫu `SyncCheckpointStore`: nhờ vậy test chạy
/// không cần nền tảng thật, và bản in-memory dưới đây dùng được ở mọi nơi cần
/// một kho không bền vững.
abstract class NotificationPrefsStore {
  /// **Không bao giờ trả null.** Chưa lưu gì thì trả `NotificationPrefs.macDinh`
  /// — đó là đường đi của mọi tài khoản đã tồn tại trước bản này.
  Future<NotificationPrefs> read(int idaccount);

  Future<void> write(int idaccount, NotificationPrefs value);

  /// Đưa một tài khoản về mặc định. Gọi khi xoá dữ liệu cục bộ của tài khoản đó.
  Future<void> clear(int idaccount);
}

/// Cài đặt mặc định, dùng `flutter_secure_storage` — gói đã có sẵn trong dự án
/// cho access/refresh token, chạy cả trên web, nên không phải thêm phụ thuộc.
///
/// Mọi thao tác **nuốt lỗi**: mất tuỳ chọn chỉ khiến người dùng quay về mặc
/// định, còn ném ra ngoài thì làm chết cả vòng quét thông báo — nơi gọi chính
/// của lớp này.
class SecureStorageNotificationPrefsStore implements NotificationPrefsStore {
  const SecureStorageNotificationPrefsStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Một khoá cho mỗi tài khoản. Máy dùng chung là chuyện thật ở dự án này
  /// (xem `purgeDataForOtherAccounts`): gộp chung một khoá là người đăng nhập
  /// sau thừa hưởng công tắc của người trước.
  static String _keyFor(int idaccount) => 'notification_prefs_$idaccount';

  @override
  Future<NotificationPrefs> read(int idaccount) async {
    try {
      final raw = await _storage.read(key: _keyFor(idaccount));
      if (raw == null || raw.isEmpty) return NotificationPrefs.macDinh;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return NotificationPrefs.macDinh;

      return NotificationPrefs.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // JSON hỏng, đĩa lỗi, khoá bị sửa tay — tất cả về mặc định.
      return NotificationPrefs.macDinh;
    }
  }

  @override
  Future<void> write(int idaccount, NotificationPrefs value) async {
    try {
      await _storage.write(
        key: _keyFor(idaccount),
        value: jsonEncode(value.toJson()),
      );
    } catch (_) {
      // Bỏ qua — xem chú thích ở đầu lớp.
    }
  }

  @override
  Future<void> clear(int idaccount) async {
    try {
      await _storage.delete(key: _keyFor(idaccount));
    } catch (_) {
      // Bỏ qua — xem chú thích ở đầu lớp.
    }
  }
}

/// Kho trong RAM. Dùng cho test, và cho mọi nơi cần một kho không bền vững.
class InMemoryNotificationPrefsStore implements NotificationPrefsStore {
  final Map<int, NotificationPrefs> values = {};

  @override
  Future<NotificationPrefs> read(int idaccount) async =>
      values[idaccount] ?? NotificationPrefs.macDinh;

  @override
  Future<void> write(int idaccount, NotificationPrefs value) async =>
      values[idaccount] = value;

  @override
  Future<void> clear(int idaccount) async => values.remove(idaccount);
}
