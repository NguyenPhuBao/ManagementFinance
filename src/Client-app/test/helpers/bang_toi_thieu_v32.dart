/// Schema v32 (gia đình, 2026-10-28) thêm cột `idhousehold` vào năm bảng đồng bộ bằng `ALTER TABLE`, nên MỌI fixture di
/// trú khai `user_version` < 32 phải CÓ đủ năm bảng — kể cả bảng tệp ấy không đọc (cùng lý do bảng `categories` phải có
/// cho bước v24). Dựng bảng tối thiểu (chỉ khoá chính) cho bảng nào fixture chưa dựng; bảng đã có giữ nguyên
/// (`IF NOT EXISTS`). Gọi NGAY TRƯỚC `PRAGMA user_version`.
library;

/// [database] là `sqlite3.Database` do `NativeDatabase.memory(setup:)` truyền vào — `dynamic` như các fixture khác, khỏi
/// thêm `sqlite3` làm phụ thuộc trực tiếp.
void dungBangThieuChoV32(dynamic database) {
  for (final bang in const ['wallets', 'transactions', 'goals', 'budgets', 'categories']) {
    database.execute('CREATE TABLE IF NOT EXISTS $bang (id TEXT NOT NULL PRIMARY KEY)');
  }
}
