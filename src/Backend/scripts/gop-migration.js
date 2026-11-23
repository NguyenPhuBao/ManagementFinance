// Gộp tệp migration vào database/FlowMoney_Schema.sql (lược đồ đầy đủ cho bản cài mới).
//
// Quy trình đổi CSDL: viết database/N_*.sql luỹ đẳng -> áp lên Supabase (có xác nhận) -> chạy
//   node scripts/gop-migration.js database/N_*.sql
// rồi xoá tệp N_*.sql. Mỗi tệp thành một đoạn giữa "-- >>> <tên>" và "-- <<< <tên>" ở cuối tệp.
// Tệp được xếp theo số đầu tên (27 trước 27b trước 28), bỏ BOM.
const fs = require('fs');
const path = require('path');

const SCHEMA = path.join(__dirname, '../database/FlowMoney_Schema.sql');
const HEADER = `-- FlowMoney: lược đồ CSDL PostgreSQL đầy đủ cho bản cài mới.
-- Cài mới: chạy cả tệp một lần trên CSDL trống. Không chạy lại trên CSDL đã có dữ liệu.
-- Thay đổi về sau: viết database/N_*.sql, áp lên CSDL đang chạy, rồi gộp vào đây bằng scripts/gop-migration.js.
`;

function khoa(ten) {
  if (/^New_Database\.sql$/i.test(ten)) return [0, ''];
  const m = ten.match(/^(\d+)([a-z]*)_/i);
  if (!m) throw new Error(`Tên tệp không theo mẫu N_*.sql: ${ten}`);
  return [Number(m[1]), m[2].toLowerCase()];
}

function gop(tepList, dich = SCHEMA) {
  tepList.forEach((f) => khoa(path.basename(f)));   // kiểm tên mọi tệp, kể cả khi chỉ có một tệp
  const tep = [...tepList].sort((a, b) => {
    const [na, sa] = khoa(path.basename(a)); const [nb, sb] = khoa(path.basename(b));
    return na - nb || sa.localeCompare(sb);
  });
  let out = fs.existsSync(dich) ? fs.readFileSync(dich, 'utf8') : HEADER;
  for (const f of tep) {
    const ten = path.basename(f);
    if (out.includes(`-- >>> ${ten}\n`)) throw new Error(`${ten} đã có trong FlowMoney_Schema.sql`);
    const sql = fs.readFileSync(f, 'utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n').replace(/\s*$/, '\n');
    out += `\n-- >>> ${ten}\n${sql}-- <<< ${ten}\n`;
  }
  fs.writeFileSync(dich, out, 'utf8');
  return tep.map((f) => path.basename(f));
}

module.exports = { gop, khoa, SCHEMA, HEADER };

if (require.main === module) {
  const args = process.argv.slice(2);
  if (!args.length) { console.error('Dùng: node scripts/gop-migration.js database/N_*.sql ...'); process.exit(1); }
  const xong = gop(args);
  console.log(`Đã gộp ${xong.length} tệp vào ${path.relative(process.cwd(), SCHEMA)}:`, xong.join(', '));
}
