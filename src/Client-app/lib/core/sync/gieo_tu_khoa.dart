/// Gieo từ khoá phân loại backend gửi kèm danh mục — thân dời nguyên văn từ `SyncEngine` (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`); chỉ nhánh kéo về gọi.
library;

import 'package:flutter/foundation.dart' hide Category;

import '../database/app_database.dart';

/// Gieo từ khoá phân loại backend gửi kèm danh mục — **chỉ khi danh mục đó
/// chưa có từ khoá nào** ở máy này.
///
/// Vì sao không ghi đè: cột `Keyword` phía backend là **một chuỗi dùng chung
/// cho mọi tài khoản** (xem `docs/superpowers/backend/DA-XONG/CATEGORY_KEYWORD_SYNC.md`),
/// còn `CategoryKeywords` phía client là dữ liệu **riêng từng người dùng**,
/// sửa được trong màn quản lý danh mục. Ghi đè ở mỗi chu kỳ pull sẽ khiến
/// thao tác xoá từ khoá của người dùng không bao giờ dính — nó bị hồi sinh ở
/// lần pull sau, đúng cách danh mục đã xoá từng bị hồi sinh ở G7.
///
/// Đánh đổi có chủ ý: xoá **hết** từ khoá của một danh mục thì lần pull sau
/// gieo lại, vì "rỗng" không phân biệt được với "chưa từng gieo" nếu không
/// thêm cột mới.
///
/// `idaccount` dùng để ghi là **tài khoản đang đăng nhập**, không phải
/// `idaccount` của hàng danh mục — danh mục mặc định lưu với `idaccount = 0`
/// nhưng `loadKeywords` tra theo tài khoản người dùng.
Future<void> gieoTuKhoaKhiTrong(
  AppDatabase db,
  int accountId,
  Map<String, List<String>> tuKhoaTheoDanhMuc,
) async {
  if (accountId <= 0 || tuKhoaTheoDanhMuc.isEmpty) return;
  final now = DateTime.now();
  var soDanhMucDaGieo = 0;
  for (final entry in tuKhoaTheoDanhMuc.entries) {
    try {
      final daCo = await db.categoryDao.getKeywords(accountId, entry.key);
      if (daCo.isNotEmpty) continue;
      await db.categoryDao.replaceKeywords(
        accountId: accountId,
        categoryId: entry.key,
        keywords: entry.value,
        now: now,
      );
      soDanhMucDaGieo++;
    } catch (e) {
      // Một danh mục hỏng không được làm đổ cả chu kỳ pull: từ khoá là dữ
      // liệu phụ trợ cho bộ gợi ý, không phải dữ liệu tài chính.
      debugPrint('[SyncEngine] Bỏ qua từ khoá của ${entry.key}: $e');
    }
  }
  if (soDanhMucDaGieo > 0) {
    debugPrint(
        '[SyncEngine] Đã gieo từ khoá phân loại cho $soDanhMucDaGieo danh mục.');
  }
}
