const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { Client } = require('pg');
const fs = require('fs');
const { encrypt, isEncrypted } = require('../utils/crypto.util');

async function run() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL not found in .env');
    process.exit(1);
  }

  const client = new Client({ connectionString });
  try {
    await client.connect();
    console.log('✔ Connected to PostgreSQL');

    // 1. Mở rộng độ dài cột trước để chứa chuỗi mã hóa
    console.log('1. Expanding column types to VARCHAR(256)...');
    await client.query('ALTER TABLE "user" ALTER COLUMN "Phone" TYPE VARCHAR(256);');
    await client.query('ALTER TABLE "bank_account" ALTER COLUMN "Account_number" TYPE VARCHAR(256);');
    await client.query('ALTER TABLE "bank_account" ADD COLUMN IF NOT EXISTS "Account_number_hash" VARCHAR(64);');
    await client.query('CREATE INDEX IF NOT EXISTS "idx_bank_account_number_hash" ON "bank_account" ("Account_number_hash");');
    console.log('✔ Columns expanded successfully');

    // 2. Mã hóa dữ liệu người dùng cũ nếu còn ở dạng rõ (Phone & Address)
    console.log('2. Encrypting existing legacy plaintext Phone and Address in table "user"...');
    const existingUsers = await client.query('SELECT "Iduser", "Phone", "Address" FROM "user";');
    let encryptedCount = 0;
    for (const u of existingUsers.rows) {
      let needsUpdate = false;
      let newPhone = u.Phone;
      let newAddress = u.Address;

      if (u.Phone && !isEncrypted(u.Phone)) {
        newPhone = encrypt(u.Phone);
        needsUpdate = true;
      }
      if (u.Address && !isEncrypted(u.Address)) {
        newAddress = encrypt(u.Address);
        needsUpdate = true;
      }

      if (needsUpdate) {
        await client.query(
          'UPDATE "user" SET "Phone" = $1, "Address" = $2 WHERE "Iduser" = $3;',
          [newPhone, newAddress, u.Iduser]
        );
        encryptedCount++;
      }
    }
    console.log(`✔ Encrypted ${encryptedCount} existing user records`);

    // 3. Áp dụng Database Triggers từ file 11_Data_Security_Encryption_And_Masking.sql
    console.log('3. Applying Database Triggers for two-way enforcement...');
    const sqlPath = path.join(__dirname, '../database/11_Data_Security_Encryption_And_Masking.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    console.log('✔ Database triggers applied successfully!');

    console.log('🎉 Migration 11 completed 100% successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration 11 failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
