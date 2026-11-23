// "Đặt lại mặc định" ở trang Phân quyền dịch vụ chạy nguyên văn tệp dữ liệu mẫu database/seed_permissions.sql
// trong một giao tác (tệp này tách từ migration 32 khi gộp các migration vào FlowMoney_Schema.sql).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

test('Đặt lại phân quyền mặc định chạy đúng tệp database/seed_permissions.sql trong một giao tác', async () => {
  const seedPath = path.join(__dirname, '../../database/seed_permissions.sql');
  assert.ok(fs.existsSync(seedPath), 'thiếu database/seed_permissions.sql');
  const seed = fs.readFileSync(seedPath, 'utf8');

  const db = require('../../config/db');
  const queries = [];
  const orig = db.pool.query;
  db.pool.query = async (q) => { queries.push(q); return { rows: [], rowCount: 0 }; };
  try {
    const adminService = require('../../modules/admin/admin.service');
    // Phần sau COMMIT (xoá cache, ghi nhật ký) không thuộc phạm vi ca này.
    await adminService.resetPermissionsToDefault(null).catch(() => {});
  } finally {
    db.pool.query = orig;
  }
  assert.deepEqual(queries.slice(0, 3), ['BEGIN', seed, 'COMMIT']);
});
