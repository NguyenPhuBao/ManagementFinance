/// Nhắc ghi sau khi dùng app ngân hàng — mốc "đã xét đến" của từng tài khoản (spec §4.4): chỉ phiên mở SAU mốc mới được
/// xét. Đặt về *bây giờ* khi bật công tắc, khi đăng xuất, khi lượt nhập thấy thiếu quyền.
///
/// Cùng khuôn `SecureStorageViTheoNguonStore`: một khoá mỗi tài khoản (`nhac_phien:<idaccount>`), lỗi đọc → `null`,
/// lỗi ghi bị nuốt. CỤC BỘ, không đi đồng bộ.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class MocPhienStore {
  /// `null` = chưa có mốc.
  Future<DateTime?> doc(int idaccount);

  Future<void> ghi(int idaccount, DateTime moc);
}

class SecureStorageMocPhienStore implements MocPhienStore {
  const SecureStorageMocPhienStore(this._storage);

  final FlutterSecureStorage _storage;

  static String _khoa(int idaccount) => 'nhac_phien:$idaccount';

  @override
  Future<DateTime?> doc(int idaccount) async {
    try {
      final raw = await _storage.read(key: _khoa(idaccount));
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ghi(int idaccount, DateTime moc) async {
    try {
      await _storage.write(key: _khoa(idaccount), value: moc.toIso8601String());
    } catch (_) {
      // Bỏ qua — xem chú thích đầu tệp.
    }
  }
}

class InMemoryMocPhienStore implements MocPhienStore {
  final Map<int, DateTime> values = {};

  @override
  Future<DateTime?> doc(int idaccount) async => values[idaccount];

  @override
  Future<void> ghi(int idaccount, DateTime moc) async => values[idaccount] = moc;
}
