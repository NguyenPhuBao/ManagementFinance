const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration34() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 34...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/34_add_admin_first_login_and_created_by.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 34 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 34 THÀNH CÔNG!\n');

    // Thẩm tra nhanh
    const checkColumns = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'account' AND column_name = 'is_first_login') as has_is_first_login,
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'account' AND column_name = 'created_by_admin_id') as has_created_by_admin_id,
        (SELECT COUNT(*) FROM account WHERE is_first_login = false) as existing_admins_not_first_login;
    `);
    console.log('📊 Kết quả kiểm tra sau Migration 34:');
    console.table(checkColumns.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 34:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration34();
