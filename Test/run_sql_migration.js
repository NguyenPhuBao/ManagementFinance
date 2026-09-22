const fs = require('fs');
const path = require('path');
require('../src/Backend/node_modules/dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const { Client } = require('../src/Backend/node_modules/pg');

async function run() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  try {
    await client.connect();
    const sqlPath = path.join(__dirname, '../src/Backend/database/)2_can_lam_all_migrations.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Running SQL migration via pg Client from:', sqlPath);
    await client.query(sql);
    console.log('✅ SQL migration completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
