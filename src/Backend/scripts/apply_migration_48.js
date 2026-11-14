/**
 * Áp migration 48 (bảo vệ IP) và mã hóa raw_ip thô còn sót trong aiops_ip_quarantine.
 * KHÔNG tự đọc DATABASE_URL trong .env: phải chỉ định CSDL đích bằng --url=<chuỗi kết nối>.
 * CSDL không nằm trên máy cục bộ (Supabase, Production) phải kèm --xac-nhan-tu-xa, chỉ dùng khi Chủ dự án đã xác nhận.
 * Khóa mã hóa: DATA_ENCRYPTION_KEY của môi trường sở hữu CSDL đó (crypto.util tự nạp .env nếu biến chưa đặt).
 *
 *   node scripts/apply_migration_48.js --url=postgresql://.../flowmoney_adminweb
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const arg = (name) => process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const url = arg('url');
if (!url) {
  console.error('Thiếu --url=<chuỗi kết nối>. Script không đọc .env để tránh áp nhầm lên CSDL dùng chung.');
  process.exit(1);
}
const host = new URL(url).hostname;
const isLocal = ['localhost', '127.0.0.1', '::1'].includes(host);
if (!isLocal && !process.argv.includes('--xac-nhan-tu-xa')) {
  console.error(`CSDL ${host} không phải máy cục bộ. Cần --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).`);
  process.exit(1);
}

const { encrypt, isEncrypted } = require('../utils/crypto.util');

(async () => {
  const client = new Client({ connectionString: url });
  await client.connect();
  const db = (await client.query('SELECT current_database() AS d')).rows[0].d;
  console.log(`CSDL đích: ${db} @ ${host}`);
  const sql = fs.readFileSync(path.join(__dirname, '../database/48_protect_ip_addresses.sql'), 'utf8').replace(/^﻿/, '');
  try {
    await client.query('BEGIN');
    await client.query(sql);
    const rows = (await client.query(`SELECT "id", "raw_ip" FROM "aiops_ip_quarantine" WHERE "raw_ip" IS NOT NULL AND "raw_ip" NOT LIKE 'enc:%'`)).rows;
    for (const r of rows) {
      if (!isEncrypted(r.raw_ip)) {
        await client.query(`UPDATE "aiops_ip_quarantine" SET "raw_ip" = $1 WHERE "id" = $2`, [encrypt(r.raw_ip), r.id]);
      }
    }
    await client.query('COMMIT');
    console.log(`Áp migration 48 xong. Đã mã hóa ${rows.length} raw_ip thô.`);
    const cols = await client.query(`
      SELECT table_name, column_name, data_type FROM information_schema.columns
      WHERE (table_name = 'account_device_history' AND column_name IN ('ip_address', 'ip_encrypted', 'ip_hash'))
         OR (table_name = 'aiops_ip_quarantine' AND column_name = 'raw_ip')
      ORDER BY table_name, column_name`);
    console.table(cols.rows);
    const plain = await client.query(`SELECT count(*)::int AS n FROM "aiops_ip_quarantine" WHERE "raw_ip" IS NOT NULL AND "raw_ip" NOT LIKE 'enc:%'`);
    console.log(`raw_ip thô còn lại: ${plain.rows[0].n}`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Lỗi, đã ROLLBACK:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
