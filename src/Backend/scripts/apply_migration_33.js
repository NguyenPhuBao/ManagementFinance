const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const bcrypt = require('bcryptjs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyMigration33() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng Migration 33...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.');

    const sqlPath = path.join(__dirname, '../database/33_add_admin_pin_and_audit_action_and_cleanup_test_data.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');

    console.log('🔄 Đang thực thi Migration 33 trong giao tác (Transaction)...');
    await client.query('BEGIN');
    await client.query(sqlContent);

    // Băm mã PIN mặc định 123456 cho tài khoản Admin
    const defaultPin = process.env.ADMIN_SECURITY_PIN || '123456';
    const saltRounds = 10;
    const pinHash = await bcrypt.hash(defaultPin.trim(), saltRounds);

    // Cập nhật pin_hash cho tất cả tài khoản Admin chưa có mã PIN
    const updatePinResult = await client.query(
      `UPDATE account 
       SET pin_hash = $1 
       WHERE "Idrole" = (SELECT "Idrole" FROM role WHERE "Rolename" = 'Admin' LIMIT 1) 
          OR "Email" = 'phubaonguyen1802@gmail.com' 
          OR "Username" = 'admin'`,
      [pinHash]
    );
    console.log(`🔒 Đã khởi tạo mã PIN bảo mật cho ${updatePinResult.rowCount} tài khoản Admin.`);

    await client.query('COMMIT');
    console.log('🎉 Áp dụng Migration 33 THÀNH CÔNG!\n');

    // Thẩm tra nhanh
    const checkColumns = await client.query(`
      SELECT 
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'account' AND column_name = 'pin_hash') as has_pin_hash,
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'audit_log' AND column_name = 'Action') as has_action_col,
        (SELECT COUNT(*) FROM account WHERE "Username" LIKE 'user_ret_%' OR "Email" LIKE '%anonymized.local%') as remaining_test_users,
        (SELECT COUNT(*) FROM account WHERE pin_hash IS NOT NULL) as admins_with_pin;
    `);
    console.log('📊 Kết quả kiểm tra sau Migration 33:');
    console.table(checkColumns.rows);

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Thất bại khi áp dụng Migration 33:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigration33();
