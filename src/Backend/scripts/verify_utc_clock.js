const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function verify() {
  const connectionString = process.env.DIRECT_URL || process.env.DATABASE_URL;
  const client = new Client({ connectionString });
  await client.connect();

  console.log('================================================================');
  console.log('🔍 THẨM TRA ĐỘ LỆCH ĐỒNG HỒ TRÊN MÔI TRƯỜNG TIMEZONE = Asia/Bangkok');
  console.log('================================================================\n');

  // 1. Giả lập múi giờ phiên là Asia/Bangkok (UTC+7)
  await client.query("SET timezone = 'Asia/Bangkok';");
  const tzRes = await client.query("SELECT current_setting('TimeZone') as tz;");
  console.log(`📌 Múi giờ phiên hiện tại: ${tzRes.rows[0].tz}`);

  // 2. Chạy kịch bản Mục 4 trong SERVER_UPDATE_AT_HAI_DONG_HO.md
  await client.query('BEGIN;');
  const updateRes = await client.query(`
    UPDATE "wallet" 
    SET "Update_at" = "Update_at" 
    WHERE "Idwallet" = (SELECT "Idwallet" FROM "wallet" LIMIT 1)
    RETURNING "Server_update_at"::text AS server, (now() AT TIME ZONE 'UTC')::text AS utc_now;
  `);
  await client.query('ROLLBACK;');

  if (updateRes.rows.length > 0) {
    const { server, utc_now } = updateRes.rows[0];
    const serverTime = new Date(server + 'Z').getTime();
    const utcTime = new Date(utc_now + 'Z').getTime();
    const diffMs = Math.abs(serverTime - utcTime);

    console.log(`⏱️ Giá trị Server_update_at qua Trigger: ${server}`);
    console.log(`⏱️ Giá trị (now() AT TIME ZONE 'UTC'):   ${utc_now}`);
    console.log(`📊 Độ lệch tuyệt đối: ${diffMs} ms`);

    if (diffMs < 1000) {
      console.log('✅ XÁC NHẬN: Trigger đã ghi đúng UTC! Không còn lệch 7 giờ (+25,200,000 ms)!\n');
    } else {
      console.error(`❌ CẢNH BÁO: Độ lệch vẫn còn lớn: ${diffMs} ms`);
      process.exit(1);
    }
  }

  // 3. Kiểm tra DEFAULT khi INSERT
  await client.query('BEGIN;');
  const insertRes = await client.query(`
    INSERT INTO "category" ("Idcategory", "Create_by", "NameCategory", "Classify", "Is_default", "Is_group")
    VALUES ('test-tz-cat-' || floor(random()*10000), 1, 'Test Cat', 'Expense', false, false)
    RETURNING "Server_update_at"::text AS server, (now() AT TIME ZONE 'UTC')::text AS utc_now;
  `);
  await client.query('ROLLBACK;');

  if (insertRes.rows.length > 0) {
    const { server, utc_now } = insertRes.rows[0];
    const serverTime = new Date(server + 'Z').getTime();
    const utcTime = new Date(utc_now + 'Z').getTime();
    const diffMs = Math.abs(serverTime - utcTime);

    console.log(`⏱️ Giá trị DEFAULT Server_update_at: ${server}`);
    console.log(`⏱️ Giá trị (now() AT TIME ZONE 'UTC'):  ${utc_now}`);
    console.log(`📊 Độ lệch DEFAULT: ${diffMs} ms`);

    if (diffMs < 1000) {
      console.log('✅ XÁC NHẬN: DEFAULT đã ghi đúng UTC!\n');
    } else {
      console.error(`❌ CẢNH BÁO: DEFAULT lệch lớn: ${diffMs} ms`);
      process.exit(1);
    }
  }

  await client.end();
  console.log('🎉 TOÀN BỘ CƠ CHẾ TRIGGER & DEFAULT ĐÃ HOÀN TOÀN KHỚP VỚI UTC!');
}

verify().catch((err) => {
  console.error('Lỗi thẩm tra:', err);
  process.exit(1);
});
