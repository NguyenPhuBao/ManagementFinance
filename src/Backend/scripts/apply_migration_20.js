const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { Client } = require('pg');
const fs = require('fs');

async function run() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ DATABASE_URL or DIRECT_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('✔ Connected to PostgreSQL Supabase database');

    console.log('⏳ Applying Migration 20: 20_add_payment_reconciliation_and_refund_fields.sql...');
    const sqlPath = path.join(__dirname, '../database/20_add_payment_reconciliation_and_refund_fields.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 20 executed successfully!');

    // Xác minh cấu trúc cột trong CSDL thực tế
    console.log('\n🔍 Verifying Column Additions on Supabase...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'payment_order'
        AND column_name IN (
          'recognition_code',
          'amount_received',
          'fee',
          'transfer_content',
          'refunded_at',
          'refunded_amount',
          'refund_reason',
          'refund_proof'
        )
      ORDER BY column_name;
    `);

    console.log(`✔ Verified: Found ${colCheck.rows.length}/8 new columns in payment_order:`);
    colCheck.rows.forEach(col => console.log(`   - ${col.column_name} (${col.data_type})`));

    if (colCheck.rows.length < 8) {
      throw new Error(`Only found ${colCheck.rows.length} columns, expected 8!`);
    }

    // Kiểm tra chỉ mục
    const idxCheck = await client.query(`
      SELECT indexname, tablename 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
        AND tablename = 'payment_order'
        AND indexname IN ('idx_payment_order_recognition_code', 'idx_payment_order_status');
    `);
    console.log(`✔ Verified: Found ${idxCheck.rows.length} performance indexes:`);
    idxCheck.rows.forEach(idx => console.log(`   - [${idx.tablename}] ${idx.indexname}`));

    console.log('\n🎉 ALL REAL DATABASE UPDATES COMPLETED & VERIFIED 100% SUCCESSFUL!\n');
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
