const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration35() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 35...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/35_create_account_device_history_table.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 35 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 35 THÀNH CÔNG!\n');

    // Thẩm tra nhanh bảng account_device_history
    const checkTable = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'account_device_history'
      ORDER BY ordinal_position;
    `);
    console.log('📊 Cấu trúc bảng account_device_history:');
    console.table(checkTable.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 35:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration35();
