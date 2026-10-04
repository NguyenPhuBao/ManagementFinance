require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

async function syncToSupabase() {
  const directUrl = process.env.DIRECT_URL;
  const dbUrl = process.env.DATABASE_URL;
  const connectionString = directUrl || dbUrl;

  console.log('================================================================');
  console.log('ĐỒNG BỘ CSDL VỚI SUPABASE CLOUD (POSTGRESQL)');
  console.log('Host kết nối:', connectionString.replace(/:[^:@]+@/, ':***@'));
  console.log('================================================================\n');

  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 15000,
  });

  try {
    // 1. Kiểm tra kết nối
    const testRes = await pool.query('SELECT current_database() as db, version() as ver;');
    console.log(`✅ Kết nối Supabase thành công! Database: "${testRes.rows[0].db}"`);

    // 2. Kiểm tra trạng thái bảng aiops_incident
    const checkTable = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'aiops_incident'
      );
    `);
    const tableExists = checkTable.rows[0].exists;

    if (!tableExists) {
      console.log('\n⏳ Bảng "aiops_incident" CHƯA TỒN TẠI trên Supabase Cloud.');
      console.log('🚀 Tiến hành chạy file migration: database/15_create_aiops_incident_table.sql ...');

      const sqlPath = path.join(__dirname, 'database', '15_create_aiops_incident_table.sql');
      const sqlContent = fs.readFileSync(sqlPath, 'utf8');

      await pool.query(sqlContent);
      console.log('✅ Đã thực thi migration 15_create_aiops_incident_table.sql thành công!');
    } else {
      console.log('\n✅ Bảng "aiops_incident" đã tồn tại sẵn trên Supabase Cloud.');
    }

    // 2.1 Kiểm tra và tạo bảng aiops_setting (Lưu cứng quy mô CCU)
    console.log('🚀 Tiến hành chạy migration 16_create_aiops_setting_table.sql ...');
    const sqlPath16 = path.join(__dirname, 'database', '16_create_aiops_setting_table.sql');
    const sqlContent16 = fs.readFileSync(sqlPath16, 'utf8');
    await pool.query(sqlContent16);
    console.log('✅ Đã thực thi migration 16_create_aiops_setting_table.sql thành công!');

    // Đảm bảo target_concurrency = 1000
    await pool.query(`
      INSERT INTO "aiops_setting" ("key", "value", "updated_at")
      VALUES ('target_concurrency', '1000', NOW())
      ON CONFLICT ("key") DO UPDATE SET "value" = '1000', "updated_at" = NOW();
    `);
    const settingRes = await pool.query(`SELECT "key", "value", "updated_at" FROM "aiops_setting" WHERE "key" = 'target_concurrency';`);
    console.log(`🔒 Cài đặt lưu cứng hiện tại trên Supabase: [${settingRes.rows[0].key} = ${settingRes.rows[0].value} CCU] (Cập nhật lúc: ${settingRes.rows[0].updated_at})`);

    // 2.2 Thực thi Migration 17: Che bớt IP trong refreshtoken (Zero Raw IP theo Nghị định 13/2023/NĐ-CP)
    console.log('🚀 Tiến hành chạy migration 17_mask_refreshtoken_ip_address.sql ...');
    const sqlPath17 = path.join(__dirname, 'database', '17_mask_refreshtoken_ip_address.sql');
    const sqlContent17 = fs.readFileSync(sqlPath17, 'utf8');
    await pool.query(sqlContent17);
    console.log('✅ Đã thực thi migration 17_mask_refreshtoken_ip_address.sql thành công!');

    // 2.3 Thực thi Migration 18: Mở rộng dung lượng cột Hash và IP (256/512 ký tự)
    console.log('🚀 Tiến hành chạy migration 18_expand_hash_and_ip_columns_capacity.sql ...');
    const sqlPath18 = path.join(__dirname, 'database', '18_expand_hash_and_ip_columns_capacity.sql');
    const sqlContent18 = fs.readFileSync(sqlPath18, 'utf8');
    await pool.query(sqlContent18);
    console.log('✅ Đã thực thi migration 18_expand_hash_and_ip_columns_capacity.sql thành công!');


    // 3. Kiểm tra lại cấu trúc bảng aiops_incident
    const colRes = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'aiops_incident'
      ORDER BY ordinal_position;
    `);

    console.log(`\n📋 Cấu trúc bảng "aiops_incident" trên Supabase Cloud (${colRes.rows.length} cột):`);
    colRes.rows.forEach(col => {
      console.log(` - ${col.column_name.padEnd(24)} : ${col.data_type.padEnd(16)} (Null: ${col.is_nullable}, Default: ${col.column_default || 'none'})`);
    });

    // 4. Kiểm tra các index
    const idxRes = await pool.query(`
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = 'public' AND tablename = 'aiops_incident'
      ORDER BY indexname;
    `);

    console.log(`\n🔍 Danh sách Indexes của "aiops_incident" trên Supabase (${idxRes.rows.length} indexes):`);
    idxRes.rows.forEach(idx => {
      console.log(` - ${idx.indexname}`);
    });

    // 5. Test round-trip đọc ghi thực tế trên Supabase
    console.log('\n🧪 Kiểm thử ghi/đọc dữ liệu thực tế trên Supabase Cloud...');
    const testId = `sync_verify_${Date.now()}`;
    await pool.query(`
      INSERT INTO "aiops_incident" (
        id, code, vector, severity, message, status,
        actor_type, actor_identity, actor_hash, metric_current, metric_baseline, metric_unit,
        root_cause_diagnosis, mitigation_taken, hits, first_detected_at, last_seen_at
      ) VALUES (
        $1, 'ANOMALY_VERIFY_SYNC', 'traffic', 'LOW', 'Test xác minh đồng bộ CSDL Cloud Supabase', 'ACTIVE',
        'SYSTEM', '127.0.0.1', 'verify_hash_001', 10, 5, 'req/min',
        'Kiểm thử đồng bộ CSDL với Supabase', 'Verification Probe', 1, NOW(), NOW()
      );
    `, [testId]);

    const readRes = await pool.query(`SELECT id, code, actor_identity, status FROM "aiops_incident" WHERE id = $1;`, [testId]);
    if (readRes.rows.length === 1 && readRes.rows[0].id === testId) {
      console.log(`✅ Đọc ghi thử nghiệm thành công! Bản ghi ID: ${readRes.rows[0].id}, Code: ${readRes.rows[0].code}`);
    } else {
      throw new Error('Đọc ghi thử nghiệm thất bại!');
    }

    // Xóa bản ghi test
    await pool.query(`DELETE FROM "aiops_incident" WHERE id = $1;`, [testId]);
    console.log('🧹 Đã dọn dẹp bản ghi kiểm thử thành công.');

    console.log('\n================================================================');
    console.log('🎉 ĐỒNG BỘ CSDL SUPABASE CLOUD HOÀN TẤT 100%!');
    console.log('================================================================');
  } catch (err) {
    console.error('\n❌ Lỗi trong quá trình đồng bộ Supabase:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

syncToSupabase();
