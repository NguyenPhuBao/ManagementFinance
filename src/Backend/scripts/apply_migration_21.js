const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration21() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ DIRECT_URL hoặc DATABASE_URL không tồn tại trong .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  await client.connect();
  console.log('🔗 Đã kết nối tới PostgreSQL...');

  try {
    const sqlPath = path.join(__dirname, '../database/21_fix_server_update_at_utc.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('🚀 Bắt đầu thực thi Migration 21 (Đồng nhất Server_update_at sang UTC)...');
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ Migration 21 đã áp dụng thành công 100%!');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 21:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration21();
