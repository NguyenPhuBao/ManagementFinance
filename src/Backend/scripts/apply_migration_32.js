const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration32() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 32...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/32_seed_permissions_4_pillars_data.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 32 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 32 THÀNH CÔNG!\n');

    // Thẩm tra nhanh dữ liệu đã nạp
    const stats = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM feature WHERE scope_schema != '{}'::jsonb) as features_with_scope,
        (SELECT COUNT(*) FROM account_type_permission WHERE scope_config != '{}'::jsonb) as perms_with_scope,
        (SELECT COUNT(*) FROM account_type_permission WHERE downgrade_policy IS NOT NULL) as perms_with_policy;
    `);
    console.log('📊 Thống kê dữ liệu 4 Trụ Cột sau cập nhật:');
    console.table(stats.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 32:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration32();
