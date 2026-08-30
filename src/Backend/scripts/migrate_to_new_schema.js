const { Pool } = require('pg');
require('dotenv').config({ path: `${__dirname}/../.env` });

const pool = new Pool({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function safeExec(sql, desc) {
  try {
    await pool.query(sql);
    console.log(`✔ [PASS] ${desc}`);
  } catch (err) {
    console.log(`ℹ [SKIP/NOTE] ${desc}: ${err.message}`);
  }
}

async function migrate() {
  console.log('--- STARTING DATABASE MIGRATION TO NEW SCHEMA ---');

  // 1. Backfill NULL Update_at
  await safeExec('UPDATE "public"."account" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill account.Update_at');
  await safeExec('UPDATE "public"."user" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill user.Update_at');
  await safeExec('UPDATE "public"."wallet" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill wallet.Update_at');
  await safeExec('UPDATE "public"."category" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill category.Update_at');
  await safeExec('UPDATE "public"."budget" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill budget.Update_at');
  await safeExec('UPDATE "public"."bill" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill bill.Update_at');
  await safeExec('UPDATE "public"."goal" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill goal.Update_at');
  await safeExec('UPDATE "public"."refreshtoken" SET "Update_at" = NOW() WHERE "Update_at" IS NULL;', 'Backfill refreshtoken.Update_at');

  // 2. Rename columns if old exists
  await safeExec('ALTER TABLE "public"."refreshtoken" RENAME COLUMN "Expiry" TO "Expired";', 'Rename refreshtoken.Expiry -> Expired');
  await safeExec('ALTER TABLE "public"."refreshtoken" RENAME COLUMN "Revoked" TO "Status";', 'Rename refreshtoken.Revoked -> Status');
  await safeExec('ALTER TABLE "public"."refreshtoken" RENAME COLUMN "Ip_address" TO "IP_address";', 'Rename refreshtoken.Ip_address -> IP_address');

  await safeExec('ALTER TABLE "public"."bill" RENAME COLUMN "due_date" TO "Due_date";', 'Rename bill.due_date -> Due_date');
  await safeExec('ALTER TABLE "public"."bill" ALTER COLUMN "Pay_status" TYPE varchar(7) USING (CASE WHEN "Pay_status" = true THEN \'Payed\' ELSE \'Pending\' END);', 'Convert bill.Pay_status to varchar(7)');
  await safeExec('ALTER TABLE "public"."bill" ALTER COLUMN "Pay_status" SET DEFAULT \'Pending\';', 'Set bill.Pay_status default Pending');

  await safeExec('ALTER TABLE "public"."goal" ALTER COLUMN "Status_complete" TYPE varchar(20) USING (CASE WHEN "Status_complete" = true THEN \'True\' ELSE \'False\' END);', 'Convert goal.Status_complete to varchar(20)');
  await safeExec('ALTER TABLE "public"."goal" ALTER COLUMN "Status_complete" SET DEFAULT \'False\';', 'Set goal.Status_complete default False');

  await safeExec('ALTER TABLE "public"."transaction" RENAME COLUMN "Wallet_Transfer" TO "Idwallet_transfer";', 'Rename transaction.Wallet_Transfer -> Idwallet_transfer');
  await safeExec('ALTER TABLE "public"."transaction" RENAME COLUMN "Create_at" TO "DateTransaction";', 'Rename transaction.Create_at -> DateTransaction');
  await safeExec('ALTER TABLE "public"."transaction" RENAME COLUMN "Delete_at" TO "Deleted_at";', 'Rename transaction.Delete_at -> Deleted_at');

  console.log('--- DATABASE MIGRATION COMPLETED ---');
  await pool.end();
}

migrate();
