const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const { Client } = require('pg');

async function main() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  const users = await client.query('SELECT "Iduser", "Phone", "Address" FROM "user" LIMIT 10;');
  console.log('Users:', users.rows);
  const banks = await client.query('SELECT "Id_bank_account", "Account_number" FROM "bank_account" LIMIT 10;');
  console.log('Banks:', banks.rows);
  await client.end();
}

main().catch(console.error);
