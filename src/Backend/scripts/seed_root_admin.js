/**
 * Tạo tài khoản quản trị gốc (Phần 3 kế hoạch sửa trang AIOps, 2026-11-16). Luỹ đẳng: đã có thì không tạo lại.
 *
 * Đọc ROOT_ADMIN_USERNAME, ROOT_ADMIN_EMAIL, ROOT_ADMIN_PASSWORD từ biến môi trường (hoặc .env của Backend).
 * KHÔNG đọc DATABASE_URL: phải chỉ định --url=<chuỗi kết nối>. CSDL không nằm trên máy cục bộ phải kèm
 * --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).
 *
 * - Mật khẩu lưu dạng bcrypt; Is_first_login = true nên lần đăng nhập đầu phải đổi mật khẩu và đặt PIN
 *   (luồng first-login-setup sẵn có). ROOT_ADMIN_PASSWORD chỉ dùng cho lần tạo này.
 * - Email phải đúng ROOT_ADMIN_EMAIL trong modules/auth/root-admin.js (trùng trigger CSDL 56).
 * - --reset-password: đặt lại mật khẩu từ ROOT_ADMIN_PASSWORD và bắt đổi lại ở lần đăng nhập sau.
 *
 *   node scripts/seed_root_admin.js --url=postgresql://.../flowmoney_adminweb
 */
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { Client } = require('pg');
const { ROOT_ADMIN_EMAIL } = require('../modules/auth/root-admin');

const arg = (name) => process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const fail = (msg) => {
  console.error(msg);
  process.exit(1);
};

const url = arg('url');
if (!url) fail('Thiếu --url=<chuỗi kết nối>. Script không đọc DATABASE_URL trong .env.');
const host = new URL(url).hostname;
if (!['localhost', '127.0.0.1', '::1'].includes(host) && !process.argv.includes('--xac-nhan-tu-xa')) {
  fail(`CSDL ${host} không phải máy cục bộ. Cần --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).`);
}

// Chỉ lấy các biến ROOT_ADMIN_* từ .env khi chưa đặt trong môi trường.
const envFile = path.join(__dirname, '..', '.env');
const fileVars = fs.existsSync(envFile) ? require('dotenv').parse(fs.readFileSync(envFile)) : {};
const read = (k) => String(process.env[k] ?? fileVars[k] ?? '').trim();
const username = read('ROOT_ADMIN_USERNAME');
const email = read('ROOT_ADMIN_EMAIL').toLowerCase();
const password = read('ROOT_ADMIN_PASSWORD');

if (!username || !email || !password) fail('Thiếu ROOT_ADMIN_USERNAME, ROOT_ADMIN_EMAIL hoặc ROOT_ADMIN_PASSWORD.');
if (email !== ROOT_ADMIN_EMAIL) fail(`ROOT_ADMIN_EMAIL phải là ${ROOT_ADMIN_EMAIL} (trùng trigger CSDL 56).`);
if (!read('ROOT_ADMIN_SECOND_KEY')) console.warn('Cảnh báo: chưa đặt ROOT_ADMIN_SECOND_KEY; tài khoản gốc sẽ chưa đăng nhập được.');

(async () => {
  const db = new Client({ connectionString: url });
  await db.connect();
  const name = (await db.query('SELECT current_database() AS d')).rows[0].d;
  console.log(`CSDL đích: ${name} @ ${host}`);
  try {
    const hash = await bcrypt.hash(password, 10);
    const found = await db.query('SELECT "Idaccount", "Username" FROM "account" WHERE lower("Email") = $1', [email]);
    if (found.rowCount) {
      if (process.argv.includes('--reset-password')) {
        await db.query('UPDATE "account" SET "Password" = $1, "is_first_login" = TRUE, "Update_at" = NOW() WHERE "Idaccount" = $2', [hash, found.rows[0].Idaccount]);
        console.log(`Đã đặt lại mật khẩu tài khoản gốc ${found.rows[0].Username}; lần đăng nhập sau phải đổi mật khẩu.`);
      } else {
        console.log(`Tài khoản gốc đã có (${found.rows[0].Username}), không tạo lại.`);
      }
      return;
    }
    await db.query('BEGIN');
    const acc = await db.query(
      `INSERT INTO "account" ("Idrole", "Email", "Username", "Password", "Status", "Type", "is_first_login", "Create_at", "Update_at")
       VALUES (1, $1, $2, $3, 'Active', 'Basic', TRUE, NOW(), NOW()) RETURNING "Idaccount"`,
      [email, username, hash]
    );
    await db.query(
      `INSERT INTO "user" ("Idaccount", "Fullname", "Email", "Country_code", "Create_at", "Update_at")
       VALUES ($1, 'Quản trị viên gốc', $2, '+84', NOW(), NOW())`,
      [acc.rows[0].Idaccount, email]
    );
    await db.query('COMMIT');
    console.log(`Đã tạo tài khoản gốc ${username} (Idaccount ${acc.rows[0].Idaccount}). Lần đăng nhập đầu phải đổi mật khẩu và đặt PIN.`);
  } catch (err) {
    await db.query('ROLLBACK').catch(() => {});
    console.error('Lỗi, đã ROLLBACK:', err.message);
    process.exitCode = 1;
  } finally {
    await db.end();
  }
})();
