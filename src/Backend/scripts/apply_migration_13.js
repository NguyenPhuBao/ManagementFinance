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

    console.log('Applying Migration 13: 13_drop_budget_threshold_default.sql...');
    const sqlPath = path.join(__dirname, '../database/13_drop_budget_threshold_default.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Migration 13 executed successfully!');
  } catch (err) {
    console.error('❌ Migration 13 failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
