/**
 * Áp một tệp migration SQL trong một giao tác.
 * KHÔNG đọc DATABASE_URL trong .env: phải chỉ định --url=<chuỗi kết nối> và --file=<tên tệp trong database/>.
 * CSDL không nằm trên máy cục bộ phải kèm --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).
 *
 *   node scripts/apply_migration_file.js --file=49_privacy_policy_acceptance.sql --url=postgresql://.../flowmoney_adminweb
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const arg = (name) => process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const url = arg('url');
const file = arg('file');
if (!url || !file) {
  console.error('Thiếu --url=<chuỗi kết nối> hoặc --file=<tệp migration>. Script không đọc .env.');
  process.exit(1);
}
const sqlPath = path.join(__dirname, '../database', path.basename(file));
if (!fs.existsSync(sqlPath)) {
  console.error(`Không có tệp ${sqlPath}`);
  process.exit(1);
}
const host = new URL(url).hostname;
if (!['localhost', '127.0.0.1', '::1'].includes(host) && !process.argv.includes('--xac-nhan-tu-xa')) {
  console.error(`CSDL ${host} không phải máy cục bộ. Cần --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).`);
  process.exit(1);
}

(async () => {
  const client = new Client({ connectionString: url });
  await client.connect();
  const db = (await client.query('SELECT current_database() AS d')).rows[0].d;
  console.log(`CSDL đích: ${db} @ ${host}; tệp: ${path.basename(sqlPath)}`);
  try {
    await client.query('BEGIN');
    await client.query(fs.readFileSync(sqlPath, 'utf8').replace(/^﻿/, ''));
    await client.query('COMMIT');
    console.log('Áp xong.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Lỗi, đã ROLLBACK:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
