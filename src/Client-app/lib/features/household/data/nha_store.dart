import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/nha_cua_toi.dart';

/// Kho trạng thái nhà **theo tài khoản** (spec gia đình 2026-10-23 mục 5.8) — cùng khuôn `GoiStore`. Không xoá khi đăng
/// xuất: tài khoản khác dùng khoá khác; phép dọn lúc đổi tài khoản (`purgeDataForOtherAccounts`) đọc kho của tài khoản MỚI
/// để biết giữ hàng của nhà nào. Mọi thao tác nuốt lỗi: mất kho chỉ khiến lượt làm mới đầu thấy "vào nhà" và kéo lại toàn bộ.
abstract class NhaStore {
  /// `null` = chưa có / hàng hỏng. Không bao giờ ném.
  Future<NhaCuaToi?> doc(int idaccount);
  Future<void> ghi(int idaccount, NhaCuaToi trangThai);
}

class SecureStorageNhaStore implements NhaStore {
  const SecureStorageNhaStore(this._storage);

  final FlutterSecureStorage _storage;

  static String khoa(int idaccount) => 'nha_tai_khoan_$idaccount';

  @override
  Future<NhaCuaToi?> doc(int idaccount) async {
    try {
      final raw = await _storage.read(key: khoa(idaccount));
      if (raw == null || raw.isEmpty) return null;
      return NhaCuaToi.tuJsonKho(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ghi(int idaccount, NhaCuaToi trangThai) async {
    try {
      await _storage.write(key: khoa(idaccount), value: jsonEncode(trangThai.toJson()));
    } catch (_) {
      // Bỏ qua — xem chú thích đầu lớp.
    }
  }
}

/// Kho trong RAM cho test.
class InMemoryNhaStore implements NhaStore {
  final Map<int, NhaCuaToi> values = {};

  @override
  Future<NhaCuaToi?> doc(int idaccount) async => values[idaccount];

  @override
  Future<void> ghi(int idaccount, NhaCuaToi trangThai) async => values[idaccount] = trangThai;
}
