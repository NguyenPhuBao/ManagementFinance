const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function checkPermissionsSchema() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase để kiểm tra CSDL...');
    await client.connect();
    console.log('✅ Đã kết nối thành công!\n');

    // 1. Kiểm tra sự tồn tại của 2 bảng
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name IN ('feature', 'account_type_permission');
    `);
    console.log('📋 1. DANH SÁCH BẢNG HIỆN HỮU:');
    console.table(tablesRes.rows);

    // 2. Chi tiết cột bảng feature
    const featureCols = await client.query(`
      SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'feature'
      ORDER BY ordinal_position;
    `);
    console.log('\n📋 2. CẤU TRÚC CỘT BẢNG [feature]:');
    console.table(featureCols.rows);

    // 3. Chi tiết cột bảng account_type_permission
    const permCols = await client.query(`
      SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'account_type_permission'
      ORDER BY ordinal_position;
    `);
    console.log('\n📋 3. CẤU TRÚC CỘT BẢNG [account_type_permission]:');
    console.table(permCols.rows);

    // 4. Kiểm tra Indexes và Constraints
    const constraintsRes = await client.query(`
      SELECT 
        conname AS constraint_name,
        contype AS constraint_type,
        conrelid::regclass AS table_name,
        pg_get_constraintdef(c.oid) AS definition
      FROM pg_constraint c
      JOIN pg_namespace n ON n.oid = c.connamespace
      WHERE n.nspname = 'public'
        AND conrelid::regclass::text IN ('feature', 'account_type_permission');
    `);
    console.log('\n📋 4. RÀNG BUỘC (CONSTRAINTS):');
    console.table(constraintsRes.rows);

    // 5. Đếm số lượng bản ghi
    const countRes = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM feature) as total_features,
        (SELECT COUNT(*) FROM account_type_permission) as total_permissions,
        (SELECT COUNT(*) FROM account_type_permission WHERE account_type = 'Basic') as basic_permissions,
        (SELECT COUNT(*) FROM account_type_permission WHERE account_type = 'Premium') as premium_permissions;
    `);
    console.log('\n📋 5. SỐ LƯỢNG BẢN GHI:');
    console.table(countRes.rows);

    // 6. Nhóm danh mục (category_group) và loại (type)
    const groupRes = await client.query(`
      SELECT category_group, type, COUNT(*) as count
      FROM feature
      GROUP BY category_group, type
      ORDER BY category_group, type;
    `);
    console.log('\n📋 6. PHÂN BỐ TÍNH NĂNG THEO NHÓM VÀ LOẠI:');
    console.table(groupRes.rows);

    // 7. Mẫu dữ liệu feature (5 dòng đầu)
    const sampleFeatures = await client.query(`
      SELECT id, name, type, category_group, default_limit, default_enabled, 
             scope_schema, default_downgrade_policy
      FROM feature
      LIMIT 5;
    `);
    console.log('\n📋 7. MẪU DỮ LIỆU BẢNG feature (5 dòng đầu):');
    console.log(JSON.stringify(sampleFeatures.rows, null, 2));

    // 8. Mẫu dữ liệu account_type_permission (5 dòng đầu)
    const samplePerms = await client.query(`
      SELECT id, account_type, feature_id, is_enabled, limit_value, 
             scope_config, downgrade_policy
      FROM account_type_permission
      LIMIT 10;
    `);
    console.log('\n📋 8. MẪU DỮ LIỆU BẢNG account_type_permission (10 dòng đầu):');
    console.log(JSON.stringify(samplePerms.rows, null, 2));

  } catch (err) {
    console.error('❌ Lỗi kiểm tra CSDL:', err);
  } finally {
    await client.end();
  }
}

checkPermissionsSchema();
