const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { Client } = require('pg');
const fs = require('fs');

async function run() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL or DIRECT_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('✔ Connected to PostgreSQL database');

    console.log('Applying Migration 12: 12_Can_Lam_Align_Schema_Fixes.sql...');
    const sqlPath = path.join(__dirname, '../database/12_Can_Lam_Align_Schema_Fixes.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 12 executed successfully!');
  } catch (err) {
    console.error('❌ Migration 12 failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
