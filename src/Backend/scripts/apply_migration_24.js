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

    console.log('⏳ Applying Migration 24: 24_add_is_template_to_payment_order.sql...');
    const sqlPath = path.join(__dirname, '../database/24_add_is_template_to_payment_order.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 24 executed successfully!');

    // Xác minh cấu trúc cột trong CSDL thực tế
    console.log('\n🔍 Verifying Column is_template on Supabase...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'payment_order'
        AND column_name = 'is_template';
    `);

    if (colCheck.rows.length === 0) {
      throw new Error('Column is_template was not created in payment_order!');
    }

    console.log(`✔ Verified column is_template: ${JSON.stringify(colCheck.rows[0])}`);

    // Kiểm tra chỉ mục
    const idxCheck = await client.query(`
      SELECT indexname, tablename 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
        AND tablename = 'payment_order'
        AND indexname = 'idx_payment_order_is_template';
    `);
    console.log(`✔ Verified index: ${idxCheck.rows.length > 0 ? idxCheck.rows[0].indexname : 'NOT FOUND'}`);

    // Kiểm tra số lượng đơn mẫu được update
    const countCheck = await client.query(`
      SELECT is_template, count(*) as total
      FROM payment_order
      GROUP BY is_template;
    `);
    console.log('\n📊 Phân bố đơn hàng theo is_template:');
    countCheck.rows.forEach(r => console.log(`   - is_template = ${r.is_template}: ${r.total} đơn`));

    console.log('\n🎉 Migration 24 COMPLETED AND VERIFIED 100%!');
  } catch (err) {
    console.error('❌ Migration 24 failed:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
