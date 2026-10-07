const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration22() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ DIRECT_URL hoặc DATABASE_URL không tồn tại trong .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  await client.connect();
  console.log('🔗 Đã kết nối tới PostgreSQL Supabase Cloud...');

  try {
    const sqlPath = path.join(__dirname, '../database/22_create_feature_permission_tables.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('🚀 Bắt đầu thực thi Migration 22 (Tạo bảng feature & account_type_permission)...');
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ Migration 22 đã áp dụng thành công 100%!');

    // Thẩm tra dữ liệu vừa nạp
    const featRes = await client.query('SELECT id, name, type FROM feature ORDER BY id;');
    console.log(`📌 Danh mục tính năng (feature): ${featRes.rows.length} hàng`);
    featRes.rows.forEach(r => console.log(`   - [${r.id}] ${r.name} (${r.type})`));

    const permRes = await client.query('SELECT account_type, feature_id, is_enabled, limit_value FROM account_type_permission ORDER BY account_type, feature_id;');
    console.log(`📌 Bảng phân quyền (account_type_permission): ${permRes.rows.length} hàng`);
    permRes.rows.forEach(r => console.log(`   - [${r.account_type}] ${r.feature_id}: enabled=${r.is_enabled}, limit=${r.limit_value}`));

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 22:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration22();
