const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { pool } = require('../config/db');

async function run() {
  try {
    const sqlPath = path.join(__dirname, '../../../database/6_Drop_Category_Group_Membership.sql');
    const sql = fs.readFileSync(sqlPath, 'utf-8');
    console.log('Applying 6_Drop_Category_Group_Membership.sql to Supabase / PostgreSQL...');
    await pool.query(sql);
    console.log('✅ Migration 6 applied successfully! Table category_group_membership dropped.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err);
    process.exit(1);
  }
}

run();
