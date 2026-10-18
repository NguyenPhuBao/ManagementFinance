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

    console.log('⏳ Applying Migration 27: 27_add_qr_url_to_payment_order.sql...');
    const sqlPath = path.join(__dirname, '../database/27_add_qr_url_to_payment_order.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 27 executed successfully!');

    // Xác minh cấu trúc cột trong CSDL thực tế
    console.log('\n🔍 Verifying Column qr_url on Supabase...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'payment_order'
        AND column_name = 'qr_url';
    `);

    if (colCheck.rows.length === 0) {
      throw new Error('Column qr_url was not created in payment_order!');
    }

    console.log(`✔ Verified column qr_url: ${JSON.stringify(colCheck.rows[0])}`);
    console.log('\n🎉 Migration 27 COMPLETED AND VERIFIED 100%!');
  } catch (err) {
    console.error('❌ Migration 27 failed:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
