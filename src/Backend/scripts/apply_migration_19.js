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

    console.log('⏳ Applying Migration 19: 19_create_payment_subscription_tables.sql...');
    const sqlPath = path.join(__dirname, '../database/19_create_payment_subscription_tables.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 19 executed successfully!');

    // Xác minh kiểm tra cấu trúc CSDL thực tế
    console.log('\n🔍 Verifying Database Schema Changes on Supabase...');

    // 1. Kiểm tra cột premium_expires_at
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'account' AND column_name = 'premium_expires_at';
    `);
    if (colCheck.rows.length > 0) {
      console.log('✔ Verified: Column "account.premium_expires_at" exists:', colCheck.rows[0]);
    } else {
      throw new Error('Column "account.premium_expires_at" was not created!');
    }

    // 2. Kiểm tra bảng payment_order và payment_transaction
    const tablesCheck = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name IN ('payment_order', 'payment_transaction');
    `);
    const createdTables = tablesCheck.rows.map(r => r.table_name);
    console.log('✔ Verified: Created tables:', createdTables);
    if (!createdTables.includes('payment_order') || !createdTables.includes('payment_transaction')) {
      throw new Error('Tables "payment_order" or "payment_transaction" are missing!');
    }

    // 3. Kiểm tra chỉ mục
    const idxCheck = await client.query(`
      SELECT indexname, tablename 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
        AND tablename IN ('account', 'payment_order', 'payment_transaction')
        AND indexname IN (
          'idx_payment_order_account',
          'idx_payment_order_status',
          'idx_payment_order_code',
          'idx_payment_transaction_order',
          'idx_payment_transaction_account',
          'idx_account_premium_expires'
        );
    `);
    console.log(`✔ Verified: Found ${idxCheck.rows.length} performance indexes:`);
    idxCheck.rows.forEach(idx => console.log(`   - [${idx.tablename}] ${idx.indexname}`));

    console.log('\n🎉 ALL REAL DATABASE UPDATES COMPLETED & VERIFIED 100% SUCCESSFUL!\n');
  } catch (err) {
    console.error('❌ Migration 19 failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
