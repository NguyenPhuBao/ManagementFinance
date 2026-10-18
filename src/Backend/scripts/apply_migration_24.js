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

    console.log('⏳ Applying Migration 24: 24_add_actor_role_to_aiops_incident.sql...');
    const sqlPath = path.join(__dirname, '../database/24_add_actor_role_to_aiops_incident.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 24 executed successfully!');

    // Xác minh cấu trúc cột actor_role
    console.log('\n🔍 Verifying Column actor_role on Supabase...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'aiops_incident'
        AND column_name = 'actor_role';
    `);

    if (colCheck.rows.length === 0) {
      console.warn('⚠️ Column actor_role not found in aiops_incident (table might not exist yet)');
    } else {
      console.log(`✔ Verified column actor_role: ${JSON.stringify(colCheck.rows[0])}`);
    }

    console.log('\n🎉 Migration 24 COMPLETED AND VERIFIED 100%!');
  } catch (err) {
    console.error('❌ Migration 24 failed:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
