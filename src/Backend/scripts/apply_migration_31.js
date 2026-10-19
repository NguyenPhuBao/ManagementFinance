const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration31() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 31...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/31_redesign_permissions_4_pillars.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 31 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 31 THÀNH CÔNG!\n');

    // Thẩm tra các cột mới trong bảng feature
    const featureCols = await client.query(`
      SELECT column_name, data_type, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'feature' AND column_name IN ('scope_schema', 'default_downgrade_policy');
    `);
    console.log('📊 Các cột mới trong bảng feature:');
    console.table(featureCols.rows);

    // Thẩm tra các cột mới trong bảng account_type_permission
    const permCols = await client.query(`
      SELECT column_name, data_type, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'account_type_permission' AND column_name IN ('scope_config', 'downgrade_policy');
    `);
    console.log('\n📊 Các cột mới trong bảng account_type_permission:');
    console.table(permCols.rows);

    // Kiểm tra mẫu dữ liệu đã đồng bộ
    const sample = await client.query(`
      SELECT p.account_type, p.feature_id, f.type, p.is_enabled, p.limit_value, p.downgrade_policy
      FROM account_type_permission p
      JOIN feature f ON p.feature_id = f.id
      WHERE p.feature_id IN ('wallets', 'budgets', 'transaction_management', 'export_reports', 'ai_assistant')
      ORDER BY p.feature_id, p.account_type;
    `);
    console.log('\n📊 Mẫu dữ liệu sau khi đồng bộ Trụ 4 (downgrade_policy):');
    console.table(sample.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 25:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration31();
