/// Nhắc ghi sau khi dùng app ngân hàng — mốc "đã xét đến" của từng tài khoản (spec §4.4): chỉ phiên mở SAU mốc mới được
/// xét. Đặt về *bây giờ* khi bật công tắc, khi đăng xuất, khi lượt nhập thấy thiếu quyền, và ở lượt nhập ĐẦU sau một lần
/// đăng xuất (cờ máy [danhDauDangXuat]).
///
/// Cùng khuôn `SecureStorageViTheoNguonStore`: một khoá mỗi tài khoản (`nhac_phien:<idaccount>`), lỗi đọc → `null`,
/// lỗi ghi bị nuốt. CỤC BỘ, không đi đồng bộ.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class MocPhienStore {
  /// `null` = chưa có mốc.
  Future<DateTime?> doc(int idaccount);

  Future<void> ghi(int idaccount, DateTime moc);

  /// Cờ theo MÁY: vừa có người đăng xuất, chưa ai đăng nhập lại. Sự kiện dùng app là của máy, không của tài khoản —
  /// phiên giữa lúc đăng xuất và lần đăng nhập kế không thuộc ai, nên lượt nhập đầu sau đó phải bỏ chúng (nghiệm thu
  /// Realme 2026-10-03: chỉ đặt mốc = giờ đăng xuất thì phiên ấy thành dòng nhắc khi đăng nhập lại).
  Future<void> danhDauDangXuat();

  /// Đọc rồi xoá cờ [danhDauDangXuat]: `true` đúng một lần sau mỗi lần đánh dấu.
  Future<bool> layVaXoaDangXuat();
}

class SecureStorageMocPhienStore implements MocPhienStore {
  const SecureStorageMocPhienStore(this._storage);

  final FlutterSecureStorage _storage;

  static String _khoa(int idaccount) => 'nhac_phien:$idaccount';
  static const _khoaDangXuat = 'nhac_phien_dang_xuat';

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

  @override
  Future<void> danhDauDangXuat() async {
    try {
      await _storage.write(key: _khoaDangXuat, value: '1');
    } catch (_) {
      // Bỏ qua — xem chú thích đầu tệp.
    }
  }

  @override
  Future<bool> layVaXoaDangXuat() async {
    try {
      if (await _storage.read(key: _khoaDangXuat) == null) return false;
      await _storage.delete(key: _khoaDangXuat);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class InMemoryMocPhienStore implements MocPhienStore {
  final Map<int, DateTime> values = {};
  bool daDangXuat = false;

  @override
  Future<DateTime?> doc(int idaccount) async => values[idaccount];

  @override
  Future<void> ghi(int idaccount, DateTime moc) async => values[idaccount] = moc;

  @override
  Future<void> danhDauDangXuat() async => daDangXuat = true;

  @override
  Future<bool> layVaXoaDangXuat() async {
    final co = daDangXuat;
    daDangXuat = false;
    return co;
  }
}
