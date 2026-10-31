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

  /// Nhà mà `DieuPhoiDoiNha` đã xử lý xong (G113 lỗ hổng 1). Vắng = `null` = chưa xử lý nhà nào.
  Future<int?> docDauXuLy(int idaccount);

  /// [idNha] `null` là xoá dấu.
  Future<void> ghiDauXuLy(int idaccount, int? idNha);
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

  static String khoaDau(int idaccount) => 'nha_da_xu_ly_$idaccount';

  @override
  Future<int?> docDauXuLy(int idaccount) async {
    try {
      return int.tryParse(await _storage.read(key: khoaDau(idaccount)) ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ghiDauXuLy(int idaccount, int? idNha) async {
    try {
      if (idNha == null) {
        await _storage.delete(key: khoaDau(idaccount));
      } else {
        await _storage.write(key: khoaDau(idaccount), value: '$idNha');
      }
    } catch (_) {
      // Bỏ qua: mất dấu chỉ làm lần mở sau kéo toàn bộ một lần.
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

  final Map<int, int> dau = {};

  @override
  Future<int?> docDauXuLy(int idaccount) async => dau[idaccount];

  @override
  Future<void> ghiDauXuLy(int idaccount, int? idNha) async {
    if (idNha == null) {
      dau.remove(idaccount);
    } else {
      dau[idaccount] = idNha;
    }
  }
}
