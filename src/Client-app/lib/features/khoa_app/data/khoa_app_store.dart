import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/cau_hinh_khoa_app.dart';

/// Kho cấu hình khoá ứng dụng theo tài khoản — cùng khuôn `SecureStorageGoiStore` (`premium/data/goi_store.dart`).
abstract class KhoaAppStore {
  /// `null` = chưa bật hoặc hàng hỏng. Không bao giờ ném.
  Future<CauHinhKhoaApp?> doc(int idaccount);

  /// NÉM khi kho hỏng — `KhoaAppService.kiemPin` phải biết lần sai đã được ghi hay chưa.
  Future<void> ghi(int idaccount, CauHinhKhoaApp cauHinh);

  Future<void> xoa(int idaccount);

  /// Xoá MỌI cấu hình khoá trên máy (đăng xuất). Không đụng khoá khác của kho (token, gói…).
  Future<void> xoaHet();
}

class SecureStorageKhoaAppStore implements KhoaAppStore {
  const SecureStorageKhoaAppStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String tienTo = 'khoa_app_';
  static String khoa(int idaccount) => '$tienTo$idaccount';

  @override
  Future<CauHinhKhoaApp?> doc(int idaccount) async {
    try {
      final raw = await _storage.read(key: khoa(idaccount));
      if (raw == null || raw.isEmpty) return null;
      return CauHinhKhoaApp.tuJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ghi(int idaccount, CauHinhKhoaApp cauHinh) =>
      _storage.write(key: khoa(idaccount), value: jsonEncode(cauHinh.toJson()));

  @override
  Future<void> xoa(int idaccount) async {
    try {
      await _storage.delete(key: khoa(idaccount));
    } catch (_) {
      // Bỏ qua — xoá hỏng thì lần mở sau vẫn đọc được cấu hình cũ, người dùng tắt lại.
    }
  }

  @override
  Future<void> xoaHet() async {
    final Map<String, String> tatCa;
    try {
      tatCa = await _storage.readAll();
    } catch (_) {
      // readAll hỏng: đăng xuất không bao giờ được ném; đường lùi (xoá thẳng theo khoá của tài khoản
      // hiện tại) nằm ở chỗ gọi.
      return;
    }
    // P3: lặp trên bản sao — mock (và có thể bản thật) trả chính map nội bộ, lặp-rồi-xoá sẽ ném
    // ConcurrentModificationError.
    for (final k in tatCa.keys.toList()) {
      if (!k.startsWith(tienTo)) continue;
      try {
        await _storage.delete(key: k);
      } catch (_) {
        // Một khoá xoá hỏng không được chặn các khoá khác (nếu không, cấu hình còn sót sẽ khoá lại
        // bằng đúng PIN đã quên sau khi đăng nhập lại).
      }
    }
  }
}

/// Kho trong RAM cho test.
class InMemoryKhoaAppStore implements KhoaAppStore {
  final Map<int, CauHinhKhoaApp> duLieu = {};
  bool hongKhiGhi = false;

  @override
  Future<CauHinhKhoaApp?> doc(int idaccount) async => duLieu[idaccount];

  @override
  Future<void> ghi(int idaccount, CauHinhKhoaApp cauHinh) async {
    if (hongKhiGhi) throw StateError('kho hỏng');
    duLieu[idaccount] = cauHinh;
  }

  @override
  Future<void> xoa(int idaccount) async => duLieu.remove(idaccount);

  @override
  Future<void> xoaHet() async => duLieu.clear();
}
