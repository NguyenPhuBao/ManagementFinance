const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration40() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 40...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/40_create_household_foundation.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 40 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 40 THÀNH CÔNG!\n');

    // Thẩm tra các bảng mới
    const checkTables = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_name IN ('household', 'household_member', 'household_invite')
      ORDER BY table_name;
    `);
    console.log('📊 Danh sách bảng gia đình vừa tạo:');
    console.table(checkTables.rows);

    // Thẩm tra cột Idhousehold trên 5 bảng
    const checkColumns = await client.query(`
      SELECT table_name, column_name, data_type
      FROM information_schema.columns
      WHERE column_name = 'Idhousehold'
      ORDER BY table_name;
    `);
    console.log('📊 Cột Idhousehold trên các bảng đồng bộ:');
    console.table(checkColumns.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 40:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration40();
