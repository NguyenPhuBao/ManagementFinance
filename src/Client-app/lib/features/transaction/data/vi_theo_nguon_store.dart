/// D1 — ví chọn sẵn cho form điền từ tin biến động số dư (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.3):
/// bảng *"nguồn + đuôi tài khoản → walletId"* của từng tài khoản. Ghi ở lần Lưu đầu của mỗi cặp; lần sau chọn sẵn.
///
/// Cùng khuôn `SecureStorageNotificationPrefsStore`: một khoá mỗi tài khoản (`bien_dong_vi:<idaccount>`), mọi lỗi đọc
/// thành "chưa biết" và mọi lỗi ghi bị nuốt — ví chọn sẵn là tiện ích, không được chặn việc ghi giao dịch.
/// Bảng CỤC BỘ, không đi đồng bộ (gắn với tin hiện trên chính máy này).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String _cap(String nguon, String? duoi) => '$nguon|${duoi ?? ''}';

/// Ví của cả NGUỒN (xem [ViTheoNguonStore.docTheoNguon]) — một phép cho hai bản cài đặt.
String? _viTheoNguon(Map<String, String> bang, String nguon) {
  final rieng = bang[_cap(nguon, null)];
  if (rieng != null) return rieng;
  final ds = {
    for (final e in bang.entries)
      if (e.key.startsWith('$nguon|')) e.value,
  };
  return ds.length == 1 ? ds.single : null;
}

abstract class ViTheoNguonStore {
  /// `null` = chưa biết.
  Future<String?> doc(int idaccount, String nguon, String? duoi);

  Future<void> ghi(int idaccount, String nguon, String? duoi, String walletId);

  /// Ví của cả NGUỒN, không kèm đuôi — dòng nhắc sau khi dùng app ngân hàng (2026-10-03) không có số tài khoản. Cặp
  /// `<nguồn>|` (đuôi trống) đã nhớ → ví ấy; không có thì mọi cặp `<nguồn>|*` trỏ về MỘT ví → ví ấy; còn lại `null`.
  Future<String?> docTheoNguon(int idaccount, String nguon);
}

class SecureStorageViTheoNguonStore implements ViTheoNguonStore {
  const SecureStorageViTheoNguonStore(this._storage);

  final FlutterSecureStorage _storage;

  static String _khoa(int idaccount) => 'bien_dong_vi:$idaccount';

  Future<Map<String, String>> _bang(int idaccount) async {
    try {
      final raw = await _storage.read(key: _khoa(idaccount));
      if (raw == null || raw.isEmpty) return {};
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String?> doc(int idaccount, String nguon, String? duoi) async =>
      (await _bang(idaccount))[_cap(nguon, duoi)];

  @override
  Future<String?> docTheoNguon(int idaccount, String nguon) async => _viTheoNguon(await _bang(idaccount), nguon);

  @override
  Future<void> ghi(int idaccount, String nguon, String? duoi, String walletId) async {
    try {
      final bang = await _bang(idaccount)
        ..[_cap(nguon, duoi)] = walletId;
      await _storage.write(key: _khoa(idaccount), value: jsonEncode(bang));
    } catch (_) {
      // Bỏ qua — xem chú thích đầu tệp.
    }
  }
}

class InMemoryViTheoNguonStore implements ViTheoNguonStore {
  final Map<int, Map<String, String>> values = {};

  @override
  Future<String?> doc(int idaccount, String nguon, String? duoi) async => values[idaccount]?[_cap(nguon, duoi)];

  @override
  Future<String?> docTheoNguon(int idaccount, String nguon) async =>
      _viTheoNguon(values[idaccount] ?? const {}, nguon);

  @override
  Future<void> ghi(int idaccount, String nguon, String? duoi, String walletId) async =>
      (values[idaccount] ??= {})[_cap(nguon, duoi)] = walletId;
}
