const fs = require('fs');
const path = require('path');
require('dotenv').config();
const { pool } = require('../config/db');

async function run() {
  try {
    const sqlPath = path.join(__dirname, '../../../database/5_Drop_Cross_Default_Category_Trigger.sql');
    const sql = fs.readFileSync(sqlPath, 'utf-8');
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
