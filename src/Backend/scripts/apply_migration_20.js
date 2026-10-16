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

    console.log('⏳ Applying Migration 20: 20_add_server_update_at_sync_tables.sql...');
    const sqlPath = path.join(__dirname, '../database/20_add_server_update_at_sync_tables.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 20 executed successfully!');

    // Xác minh cấu trúc cột Server_update_at trong 6 bảng
    console.log('\n🔍 Verifying Server_update_at columns on Supabase...');
    const tables = ['category', 'wallet', 'budget', 'bill', 'goal', 'transaction'];
    for (const tbl of tables) {
      const colCheck = await client.query(`
        SELECT column_name, data_type, column_default 
        FROM information_schema.columns 
        WHERE table_name = $1 AND column_name = 'Server_update_at'
      `, [tbl]);
      if (colCheck.rows.length > 0) {
        console.log(`   ✔ [${tbl}] Server_update_at: ${colCheck.rows[0].data_type}`);
      } else {
        console.warn(`   ⚠️ [${tbl}] Server_update_at column missing!`);
      }
    }

    console.log('\n🎉 MIGRATION 20 COMPLETED & VERIFIED!\n');
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
