const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function run() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
  });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 44...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.\n');

    const sqlFile = path.join(__dirname, '../database/44_expand_household_4_pillars_permissions.sql');
    const sql = fs.readFileSync(sqlFile, 'utf8');

    console.log('🚀 Đang thực thi Migration 44...');
    await client.query(sql);
    console.log('✅ Migration 44 hoàn tất thành công!\n');

    const result = await client.query(`
      SELECT f.id, f.name, f.type, p.account_type, p.is_enabled, p.limit_value, p.downgrade_policy
      FROM feature f
      JOIN account_type_permission p ON f.id = p.feature_id
      WHERE f.category_group = 'Gia đình'
      ORDER BY f.id, p.account_type;
    `);

    console.log('📊 Danh mục phân quyền Gia đình sau Migration 44:');
    console.table(result.rows);
  } catch (err) {
    console.error('❌ Lỗi khi thực thi Migration 44:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();

