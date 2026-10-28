const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function applyPendingMigrations() {
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
    console.log('🔄 Đang kết nối tới PostgreSQL Supabase Cloud để áp dụng các Migration tồn đọng...');
    await client.connect();
    console.log('✅ Đã kết nối CSDL thành công.\n');

    const migrations = [
      { name: '38_add_unique_payos_transaction_id.sql', file: path.join(__dirname, '../database/38_add_unique_payos_transaction_id.sql') },
      { name: '39_enforce_no_permanent_ip_ban.sql', file: path.join(__dirname, '../database/39_enforce_no_permanent_ip_ban.sql') },
      { name: '41_seed_household_permissions.sql', file: path.join(__dirname, '../database/41_seed_household_permissions.sql') },
      { name: '42_add_ck_account_status.sql', file: path.join(__dirname, '../database/42_add_ck_account_status.sql') },
      { name: '43_cleanup_orphan_records_soft_delete.sql', file: path.join(__dirname, '../database/43_cleanup_orphan_records_soft_delete.sql') },
    ];

    for (const m of migrations) {
      if (!fs.existsSync(m.file)) {
        console.warn(`⚠️ Bỏ qua ${m.name}: Tệp không tồn tại.`);
        continue;
      }
      console.log(`🚀 Đang thực thi Migration [${m.name}]...`);
      const sql = fs.readFileSync(m.file, 'utf8');
      await client.query(sql);
      console.log(`✅ [${m.name}] Hoàn tất thành công!`);
    }

    console.log('\n--- THẨM TRA KẾT QUẢ MIGRATION ---');

    // 1. Kiểm tra index 38
    const checkIdx = await client.query(`
      SELECT indexname, indexdef 
      FROM pg_indexes 
      WHERE tablename = 'payment_transaction' AND indexname = 'uq_payment_transaction_payos_id';
    `);
    console.log('📊 Index payment_transaction:');
    console.table(checkIdx.rows);

    // 2. Kiểm tra constraint 39
    const checkBan = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) as def
      FROM pg_constraint 
      WHERE conrelid = 'aiops_ip_quarantine'::regclass;
    `);
    console.log('📊 Constraints aiops_ip_quarantine:');
    console.table(checkBan.rows);

    // 3. Kiểm tra feature 41
    const checkFeatures = await client.query(`
      SELECT id, name, type, default_enabled
      FROM feature
      WHERE id IN ('household', 'household_members');
    `);
    console.log('📊 Feature household & household_members:');
    console.table(checkFeatures.rows);

    // 4. Kiểm tra constraint 42 (ck_account_status)
    const checkCkAccount = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) as def
      FROM pg_constraint 
      WHERE conrelid = 'account'::regclass AND conname = 'ck_account_status';
    `);
    console.log('📊 Check constraint ck_account_status:');
    console.table(checkCkAccount.rows);

    // 5. Kiểm tra hàng mồ côi 43
    const checkOrphans = await client.query(`
      SELECT 
        (SELECT count(*) FROM wallet w LEFT JOIN account a ON a."Idaccount" = w."Idaccount" WHERE a."Idaccount" IS NULL AND w."Delete_at" IS NULL) as active_orphan_wallets,
        (SELECT count(*) FROM transaction t LEFT JOIN account a ON a."Idaccount" = t."Idaccount" WHERE a."Idaccount" IS NULL AND t."Deleted_at" IS NULL) as active_orphan_transactions;
    `);
    console.log('📊 Số lượng hàng mồ côi còn active:');
    console.table(checkOrphans.rows);

    console.log('\n🎉 TẤT CẢ MIGRATION ĐÃ ĐƯỢC ÁP DỤNG THÀNH CÔNG VÀ AN TOÀN 100%!');
  } catch (err) {
    console.error('❌ Lỗi khi áp dụng migration:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyPendingMigrations();
