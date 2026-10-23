const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration30() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 30...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/30_standardize_and_expand_all_features.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 30 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);
    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 30 THÀNH CÔNG!\n');

    // Thẩm tra kết quả
    const features = await client.query('SELECT count(*) FROM feature');
    const permissions = await client.query('SELECT count(*) FROM account_type_permission');
    console.log(`📊 Tổng số tính năng trong bảng feature: ${features.rows[0].count}`);
    console.log(`📊 Tổng số bản ghi trong bảng account_type_permission: ${permissions.rows[0].count}`);

    const sample = await client.query(`
      SELECT f.category_group, f.id, f.name, f.type, 
             p_b.is_enabled as b_enabled, p_b.limit_value as b_limit,
             p_p.is_enabled as p_enabled, p_p.limit_value as p_limit
      FROM feature f
      LEFT JOIN account_type_permission p_b ON f.id = p_b.feature_id AND p_b.account_type = 'Basic'
      LEFT JOIN account_type_permission p_p ON f.id = p_p.feature_id AND p_p.account_type = 'Premium'
      ORDER BY f.category_group, f.id;
    `);
    console.log('\n--- DANH MỤC 36 TÍNH NĂNG TOÀN DIỆN VÀ PHÂN QUYỀN TRÊN SUPABASE ---');
    console.table(sample.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 30:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration30();
