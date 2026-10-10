import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu **mốc đồng bộ** (checkpoint) của lần pull gần nhất, bền vững giữa
/// các lần mở app.
///
/// Trước đây mốc này chỉ nằm trong RAM nên mỗi lần mở app lại phải pull toàn bộ
/// dữ liệu từ `since=1970` — càng dùng lâu càng chậm và tốn băng thông.
abstract class SyncCheckpointStore {
  Future<DateTime?> read(int idaccount);
  Future<void> write(int idaccount, DateTime value);
  Future<void> clear(int idaccount);
}

/// Cài đặt mặc định, dùng `flutter_secure_storage` (đã có sẵn trong dự án cho
/// access/refresh token nên không phải thêm phụ thuộc mới).
///
/// Mọi thao tác đều nuốt lỗi: mất checkpoint chỉ khiến lần pull kế tiếp kéo lại
/// từ đầu — chậm hơn chứ không sai dữ liệu — nên không đáng để làm hỏng cả
/// phiên đồng bộ.
class SecureStorageSyncCheckpointStore implements SyncCheckpointStore {
  const SecureStorageSyncCheckpointStore(this._storage);

  final FlutterSecureStorage _storage;

  /// ⚠️ **`_v2` là cố ý** (G67, 2026-10-08): mốc nay theo giờ-server
  /// (`Server_update_at`), mốc cũ theo giờ ghi của máy. Những hàng G67 từng bỏ
  /// sót mang giờ-server cũ (migration 20 chép `Update_at` sang), nằm DƯỚI mốc cũ
  /// — chỉ đổi luật lấy mốc thì chúng vẫn không bao giờ về. Đổi tên khoá làm mốc
  /// cũ vô hình → `since = 1970`, kéo toàn bộ **đúng một lần** cho mỗi tài khoản
  /// trên mỗi máy. Đừng đổi lại tên cũ; đổi tiếp lên `_v3` là ép thêm một lần.
  static String _keyFor(int idaccount) => 'sync_last_pull_v2_$idaccount';

  /// Khoá trước G67 — chỉ còn để dọn.
  static String _keyCuFor(int idaccount) => 'sync_last_pull_$idaccount';

  @override
  Future<DateTime?> read(int idaccount) async {
    try {
      final raw = await _storage.read(key: _keyFor(idaccount));
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(int idaccount, DateTime value) async {
    try {
      await _storage.write(
        key: _keyFor(idaccount),
        value: value.toUtc().toIso8601String(),
      );
    } catch (_) {
      // Bỏ qua — xem chú thích ở đầu lớp.
    }
  }

  @override
  Future<void> clear(int idaccount) async {
    try {
      await _storage.delete(key: _keyFor(idaccount));
      await _storage.delete(key: _keyCuFor(idaccount));
    } catch (_) {
      // Bỏ qua — xem chú thích ở đầu lớp.
    }
  }
}
