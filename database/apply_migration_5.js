const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const { pool } = require('../src/Backend/config/db');

async function run() {
  try {
    const sql = fs.readFileSync(path.join(__dirname, '5_Drop_Cross_Default_Category_Trigger.sql'), 'utf-8');
    console.log('Applying 5_Drop_Cross_Default_Category_Trigger.sql...');
    await pool.query(sql);
    console.log('✅ Migration 5 applied successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err);
    process.exit(1);
  }
}

run();
