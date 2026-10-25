/// Id đồng bộ dùng chung giữa kéo về, thu gom và gửi lô của `core/sync` — thân dời nguyên văn từ `SyncEngine` (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`).
library;

import '../database/app_database.dart';
import 'sync_payload_normalizer.dart';

String toValidUuid(String id) {
  final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);
  if (uuidRegex.hasMatch(id)) return id;
  final hexCodes =
      id.codeUnits.map((c) => (c % 16).toRadixString(16)).join('');
  final padded = hexCodes.padRight(12, '0').substring(0, 12);
  return '00000000-0000-4000-8000-$padded';
}

bool isValidUuidFormat(String id) {
  final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);
  return uuidRegex.hasMatch(id);
}

Future<String?> resolveCategoryId(AppDatabase db, String? categoryId) async {
  if (categoryId == null) return null;

  final localCategory = await db.categoryDao.getById(categoryId);
  if (localCategory == null) return null;

  // Non-default user category: chỉ cần UUID hợp lệ
  if (!localCategory.isDefault) {
    return isValidUuidFormat(categoryId) ? categoryId : null;
  }

  // Default category đã có UUID hợp lệ (từ backend) → dùng luôn
  // KHÔNG tìm UUID khác — tránh trả về UUID sai từ account khác
  if (isValidUuidFormat(categoryId)) {
    return categoryId;
  }

  // Default category với ID dạng 'cat_food' → tìm UUID tương ứng theo tên
  final categoriesWithSameName =
      await db.categoryDao.getByName(localCategory.name);
  for (final category in categoriesWithSameName) {
    if (isValidUuidFormat(category.id) &&
        category.id != localCategory.id &&
        category.isDefault &&
        SyncPayloadNormalizer.sameCategoryClassify(
          category.classify,
          localCategory.classify,
        )) {
      return category.id;
    }
  }

  return null; // Chưa có UUID tương ứng — defer transaction
}
