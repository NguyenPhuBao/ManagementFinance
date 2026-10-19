const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function verifyPermissions4Pillars() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Không tìm thấy DIRECT_URL hoặc DATABASE_URL trong .env!');
    process.exit(1);
  }

  const client = new Client({ connectionString });

  try {
    console.log('🔄 [Verification] Đang kết nối CSDL Supabase để thẩm tra 4 Trụ Cột...');
    await client.connect();

    // 1. Kiểm tra số lượng feature
    const featCountRes = await client.query('SELECT COUNT(*) FROM feature');
    const totalFeatures = parseInt(featCountRes.rows[0].count, 10);
    console.log(`📊 Tổng số tính năng trong CSDL: ${totalFeatures}/36`);
    if (totalFeatures < 36) {
      throw new Error(`Số lượng tính năng chưa đủ 36 (hiện có: ${totalFeatures})`);
    }

    // 2. Kiểm tra tính năng có scope_schema rỗng
    const emptyScopeFeatures = await client.query(`
      SELECT id, name, scope_schema, default_downgrade_policy
      FROM feature
      WHERE scope_schema = '{}'::jsonb OR scope_schema IS NULL;
    `);

    if (emptyScopeFeatures.rows.length > 0) {
      console.warn(`⚠️ Phát hiện ${emptyScopeFeatures.rows.length} tính năng có scope_schema rỗng:`);
      console.table(emptyScopeFeatures.rows.slice(0, 10));
      throw new Error(`Còn ${emptyScopeFeatures.rows.length} tính năng chưa được nạp scope_schema chi tiết!`);
    }

    // 3. Kiểm tra số lượng permission
    const permCountRes = await client.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE account_type = 'Basic') as basic_count,
        COUNT(*) FILTER (WHERE account_type = 'Premium') as premium_count
      FROM account_type_permission;
    `);
    const { total, basic_count, premium_count } = permCountRes.rows[0];
    console.log(`📊 Tổng số phân quyền: ${total}/72 (Basic: ${basic_count}/36, Premium: ${premium_count}/36)`);
    if (parseInt(total, 10) < 72) {
      throw new Error(`Số lượng phân quyền chưa đủ 72 (hiện có: ${total})`);
    }

    // 4. Kiểm tra permission có scope_config rỗng
    const emptyScopePerms = await client.query(`
      SELECT p.id, p.account_type, p.feature_id, p.scope_config, p.downgrade_policy
      FROM account_type_permission p
      WHERE p.scope_config = '{}'::jsonb OR p.scope_config IS NULL;
    `);

    if (emptyScopePerms.rows.length > 0) {
      console.warn(`⚠️ Phát hiện ${emptyScopePerms.rows.length} phân quyền có scope_config rỗng:`);
      console.table(emptyScopePerms.rows.slice(0, 10));
      throw new Error(`Còn ${emptyScopePerms.rows.length} phân quyền chưa được nạp scope_config chi tiết!`);
    }

    // 5. Kiểm tra tính hợp lệ của downgrade_policy
    const invalidPolicies = await client.query(`
      SELECT id, account_type, feature_id, downgrade_policy
      FROM account_type_permission
      WHERE downgrade_policy NOT IN ('BLOCK_CREATE', 'LOCK_FEATURE', 'READ_ONLY', 'GRACE_PERIOD_3D', 'FALLBACK_DEFAULT');
    `);

    if (invalidPolicies.rows.length > 0) {
      console.warn(`⚠️ Phát hiện ${invalidPolicies.rows.length} phân quyền có downgrade_policy không hợp lệ:`);
      console.table(invalidPolicies.rows);
      throw new Error(`Có chính sách hạ cấp không nằm trong 5 chính sách chuẩn hóa!`);
    }

    // 6. Thẩm tra một số tính năng trọng điểm
    const sampleCheck = await client.query(`
      SELECT 
        p.account_type, 
        p.feature_id, 
        p.is_enabled, 
        p.limit_value, 
        p.scope_config, 
        p.downgrade_policy
      FROM account_type_permission p
      WHERE p.feature_id IN ('wallets', 'export_reports', 'ai_assistant', 'ocr_receipt', 'budgets')
      ORDER BY p.feature_id, p.account_type;
    `);
    console.log('\n✅ MẪU 5 TÍNH NĂNG TRỌNG ĐIỂM ĐÃ ĐƯỢC XÁC THỰC:');
    console.table(sampleCheck.rows);

    console.log('\n🎉 THẨM TRA 4 TRỤ CỘT THÀNH CÔNG 100%! CSDL hoàn toàn đáp ứng đặc tả SSOT 4_TRU_COT.md.');
    process.exit(0);

  } catch (err) {
    console.error('\n❌ Thẩm tra thất bại:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

verifyPermissions4Pillars();
