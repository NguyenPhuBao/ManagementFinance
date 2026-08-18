import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bộ lưu trữ bền vững (Persistent Registry) cho Icon và Màu sắc Danh mục.
/// 
/// Tự động bảo tồn icon và màu sắc cá nhân do người dùng chọn kể cả khi
/// CSDL SQLite local bị xóa sạch hoặc reset.
class CategoryIconRegistry {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'flowmoney_category_icon_registry_v1';
  static Map<String, Map<String, String>> _cache = {};
  static bool _isLoaded = false;

  static Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await _storage.read(key: _storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        _cache = decoded.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
      }
    } catch (_) {}
    _isLoaded = true;
  }

  /// Lưu thông tin Icon và Màu sắc theo UUID và Tên danh mục
  static Future<void> saveIcon(String id, String name, String icon, String colour) async {
    await _ensureLoaded();
    final item = {'icon': icon, 'colour': colour};
    if (id.isNotEmpty) _cache[id.toLowerCase()] = item;
    if (name.isNotEmpty) _cache[name.trim().toLowerCase()] = item;

    try {
      await _storage.write(key: _storageKey, value: json.encode(_cache));
    } catch (_) {}
  }

  /// Lấy thông tin Icon và Màu sắc đã lưu
  static Future<Map<String, String>?> getIcon(String id, String name) async {
    await _ensureLoaded();
    final lowerId = id.toLowerCase();
    final lowerName = name.trim().toLowerCase();

    if (lowerId.isNotEmpty && _cache.containsKey(lowerId)) return _cache[lowerId];
    if (lowerName.isNotEmpty && _cache.containsKey(lowerName)) return _cache[lowerName];
    return null;
  }
}
