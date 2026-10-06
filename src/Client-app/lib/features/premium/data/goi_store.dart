import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/trang_thai_goi.dart';

/// Kho trạng thái gói **theo tài khoản** — cùng khuôn
/// `SecureStorageNotificationPrefsStore` (spec Premium 6.1).
///
/// Không xoá khi đăng xuất: tài khoản khác dùng khoá khác, và cùng tài khoản
/// đăng nhập lại thì có sẵn trạng thái cho tới lượt làm mới. Mọi thao tác nuốt
/// lỗi: mất cache chỉ khiến lượt mở kế phải hỏi server lại.
abstract class GoiStore {
  /// `null` = chưa có / hàng hỏng. Không bao giờ ném.
  Future<TrangThaiGoi?> doc(int idaccount);
  Future<void> ghi(int idaccount, TrangThaiGoi trangThai);
  Future<void> xoa(int idaccount);
}

class SecureStorageGoiStore implements GoiStore {
  const SecureStorageGoiStore(this._storage);

  final FlutterSecureStorage _storage;

  static String khoa(int idaccount) => 'goi_tai_khoan_$idaccount';

  @override
  Future<TrangThaiGoi?> doc(int idaccount) async {
    try {
      final raw = await _storage.read(key: khoa(idaccount));
      if (raw == null || raw.isEmpty) return null;
      return TrangThaiGoi.tuJsonKho(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ghi(int idaccount, TrangThaiGoi trangThai) async {
    try {
      await _storage.write(
        key: khoa(idaccount),
        value: jsonEncode(trangThai.toJson()),
      );
    } catch (_) {
      // Bỏ qua — xem chú thích đầu tệp.
    }
  }

  @override
  Future<void> xoa(int idaccount) async {
    try {
      await _storage.delete(key: khoa(idaccount));
    } catch (_) {
      // Bỏ qua — xem chú thích đầu tệp.
    }
  }
}

/// Kho trong RAM cho test và cho mọi nơi cần một kho không bền vững.
class InMemoryGoiStore implements GoiStore {
  final Map<int, TrangThaiGoi> values = {};

  @override
  Future<TrangThaiGoi?> doc(int idaccount) async => values[idaccount];

  @override
  Future<void> ghi(int idaccount, TrangThaiGoi trangThai) async =>
      values[idaccount] = trangThai;

  @override
  Future<void> xoa(int idaccount) async => values.remove(idaccount);
}
