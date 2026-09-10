const path = require('path');
require('../src/Backend/node_modules/dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const { Client } = require('../src/Backend/node_modules/pg');
const { encrypt } = require('../src/Backend/utils/crypto.util');
const assert = require('assert');

async function main() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  console.log('✔ Connected to DB for Trigger Verification');

  // Test 1: Insert user with plain phone
  console.log('--- TEST 1: Plaintext Phone Rejection ---');
  let phoneBlocked = false;
  try {
    await client.query(`
      INSERT INTO "user" ("Idaccount", "Fullname", "Email", "Phone")
      VALUES (999991, 'Test Plain Phone', 'test_plain_phone@gmail.com', '0987654321');
    `);
  } catch (err) {
    if (err.message.includes('BẢO MẬT: Nghiêm cấm lưu trữ số điện thoại người dùng dạng rõ')) {
      phoneBlocked = true;
      console.log('✔ Plaintext Phone blocked successfully:', err.message);
    } else {
      console.error('Unexpected error:', err.message);
    }
  }
  assert(phoneBlocked, 'Trigger phải chặn lưu SĐT dạng rõ!');

  // Test 2: Insert user with encrypted phone
  console.log('--- TEST 2: Encrypted Phone Acceptance ---');
  const encPhone = encrypt('0987654321');
  // First ensure account exists or mock rollback
  await client.query('BEGIN;');
  try {
    // Tạo account tạm
    const accRes = await client.query(`
      INSERT INTO "account" ("Idrole", "Email", "Username", "Password", "Status")
      VALUES (2, 'temp_acc_test_trigger@gmail.com', 'temp_acc_test_trigger', 'hash', 'Active')
      RETURNING "Idaccount";
    `);
    const tempId = accRes.rows[0].Idaccount;

    await client.query(`
      INSERT INTO "user" ("Idaccount", "Fullname", "Email", "Phone")
      VALUES ($1, 'Test Enc Phone', 'temp_acc_test_trigger@gmail.com', $2);
    `, [tempId, encPhone]);
    console.log('✔ Encrypted Phone inserted successfully!');
  } finally {
    await client.query('ROLLBACK;');
  }

  // Test 3: Insert bank_account with plain account_number
  console.log('--- TEST 3: Plaintext Bank Account Rejection ---');
  let bankBlocked = false;
  try {
    await client.query(`
      INSERT INTO "bank_account" ("Id_bank_account", "Idaccount", "Id_casso_account", "Account_number", "Account_name", "Bank_name")
      VALUES ('temp-uuid-1', 1, 'casso_test_plain', '1234567890', 'Test Holder', 'Vietcombank');
    `);
  } catch (err) {
    if (err.message.includes('BẢO MẬT: Nghiêm cấm lưu trữ số tài khoản ngân hàng dạng rõ')) {
      bankBlocked = true;
      console.log('✔ Plaintext Bank Account blocked successfully:', err.message);
    } else {
      console.error('Unexpected error:', err.message);
    }
  }
  assert(bankBlocked, 'Trigger phải chặn lưu STK dạng rõ!');

  // Test 4: Insert bank_account with encrypted account_number
  console.log('--- TEST 4: Encrypted Bank Account Acceptance ---');
  const encAccNum = encrypt('1234567890');
  await client.query('BEGIN;');
  try {
    await client.query(`
      INSERT INTO "bank_account" ("Id_bank_account", "Idaccount", "Id_casso_account", "Account_number", "Account_name", "Bank_name")
      VALUES ('temp-uuid-enc', 1, 'casso_test_enc', $1, 'Test Holder', 'Vietcombank');
    `, [encAccNum]);
    console.log('✔ Encrypted Bank Account inserted successfully!');
  } finally {
    await client.query('ROLLBACK;');
  }

  await client.end();
  console.log('🎉 TẤT CẢ TEST DATABASE TRIGGER XÁC THỰC 2 ĐẦU ĐÃ PASS 100%!');
}

main().catch(err => {
  console.error('Test Trigger Failed:', err);
  process.exit(1);
});
