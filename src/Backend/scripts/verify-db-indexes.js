/**
 * Database Health & Indexes Verification Script
 * Kiểm tra tính nguyên vẹn của Partial Indexes (Soft-delete WHERE clauses)
 * và Triggers bảo vệ dữ liệu pháp lý trên PostgreSQL Supabase.
 */
require('dotenv').config();
const { Client } = require('pg');

async function verifyDatabase() {
  const dbUrl = process.env.DATABASE_URL || process.env.DIRECT_URL;
  if (!dbUrl) {
    console.error('❌ Không tìm thấy DATABASE_URL hoặc DIRECT_URL trong .env');
    process.exit(1);
  }

  // Cấu hình client pg với SSL hỗ trợ Supabase
  const client = new Client({
    connectionString: dbUrl,
    ssl: { rejectUnauthorized: false }
  });

  console.log('🔄 Đang kết nối tới PostgreSQL để thẩm tra cấu trúc CSDL...');

  try {
    await client.connect();
    console.log('✅ Đã kết nối thành công tới CSDL.\n');

    let allPassed = true;

    // 1. Kiểm tra Partial Unique Indexes
    console.log('--- [1] KIỂM TRA PARTIAL INDEXES (SOFT-DELETE & CONDITIONAL) ---');
    const indexRes = await client.query(`
      SELECT tablename, indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = 'public'
      ORDER BY tablename, indexname;
    `);

    const indexes = indexRes.rows;
    const requiredIndexes = [
      {
        table: 'account',
        name: 'account_Email_key',
        expectedClause: 'WHERE ("Delete_at" IS NULL)'
      },
      {
        table: 'user',
        name: 'user_Email_key',
        expectedClause: 'WHERE ("Delete_at" IS NULL)'
      },
      {
        table: 'category',
        name: 'uq_category_default_name',
        expectedClause: '("Delete_at" IS NULL)'
      },
      {
        table: 'category',
        name: 'uq_category_owner_name',
        expectedClause: '("Delete_at" IS NULL)'
      },
      {
        table: 'bill',
        name: 'idx_bill_previous_bill',
        expectedClause: 'WHERE ("Previous_bill_id" IS NOT NULL)'
      },
      {
        table: 'transaction',
        name: 'idx_transaction_bill',
        expectedClause: 'WHERE ("Idbill" IS NOT NULL)'
      },
      {
        table: 'transaction',
        name: 'idx_transaction_goal',
        expectedClause: 'WHERE ("Idgoal" IS NOT NULL)'
      }
    ];

    for (const req of requiredIndexes) {
      const found = indexes.find(i => i.tablename === req.table && i.name === req.name || (i.tablename === req.table && i.indexname === req.name));
      if (!found) {
        console.error(`❌ [THIẾU INDEX] Bảng "${req.table}" thiếu index "${req.name}"!`);
        allPassed = false;
      } else if (!found.indexdef.includes(req.expectedClause)) {
        console.error(`❌ [MẤT ĐIỀU KIỆN] Index "${req.name}" trên "${req.table}" KHÔNG CÓ điều kiện: ${req.expectedClause}!`);
        console.error(`   Định nghĩa hiện tại: ${found.indexdef}`);
        allPassed = false;
      } else {
        console.log(`✅ [OK] [${req.table}] "${req.name}" -> ${found.indexdef.substring(found.indexdef.indexOf('WHERE'))}`);
      }
    }

    // 2. Kiểm tra Triggers bảo mật
    console.log('\n--- [2] KIỂM TRA TRIGGERS BẢO MẬT & TOÀN VẸN DỮ LIỆU ---');
    const triggerRes = await client.query(`
      SELECT trigger_name, event_manipulation, event_object_table
      FROM information_schema.triggers
      WHERE trigger_schema = 'public'
      ORDER BY event_object_table, trigger_name;
    `);

    const triggers = triggerRes.rows;
    const requiredTriggers = [
      { name: 'trg_protect_auditlog', table: 'audit_log' },
      { name: 'trg_protect_transaction', table: 'transaction' },
      { name: 'trg_check_phone_encrypted', table: 'user' },
      { name: 'trg_check_bank_account_encrypted', table: 'bank_account' }
    ];

    for (const req of requiredTriggers) {
      const found = triggers.some(t => t.trigger_name === req.name && t.event_object_table === req.table);
      if (!found) {
        console.error(`❌ [THIẾU TRIGGER] Thiếu trigger "${req.name}" trên bảng "${req.table}"!`);
        allPassed = false;
      } else {
        console.log(`✅ [OK] [${req.table}] Trigger "${req.name}" đang kích hoạt.`);
      }
    }

    console.log('\n--------------------------------------------------------------');
    if (allPassed) {
      console.log('🎉 TẤT CẢ CÁC ĐIỀU KIỆN PARTIAL INDEXES VÀ TRIGGERS ĐỀU AN TOÀN 100%!');
      process.exit(0);
    } else {
      console.error('🚨 CẢNH BÁO: Phát hiện cấu trúc CSDL bị mất hoặc sai lệch điều kiện!');
      process.exit(1);
    }
  } catch (err) {
    console.error('❌ Lỗi trong quá trình kiểm tra CSDL:', err.message);
    process.exit(1);
  } finally {
    await client.end().catch(() => {});
  }
}

verifyDatabase();
