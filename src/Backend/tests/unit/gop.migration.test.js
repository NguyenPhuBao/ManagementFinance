// scripts/gop-migration.js: gộp tệp migration N_*.sql vào cuối lược đồ cài mới, đúng thứ tự số, bỏ BOM,
// mỗi tệp một đoạn có dấu mở / đóng; gộp lại tệp đã có thì từ chối và không ghi gì.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { gop } = require('../../scripts/gop-migration');

test('gộp migration vào lược đồ: thứ tự số, bỏ BOM, dấu đoạn, chặn gộp trùng', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gop-'));
  const dich = path.join(dir, 'Schema.sql');
  fs.writeFileSync(dich, '-- lược đồ gốc\nCREATE TABLE a (id int);\n');
  const tep = (ten, noiDung) => { const p = path.join(dir, ten); fs.writeFileSync(p, noiDung); return p; };
  const f58 = tep('58_c.sql', 'ALTER TABLE a ADD COLUMN c int;\r\n');
  const f57b = tep('57b_b.sql', 'ALTER TABLE a ADD COLUMN b int;');
  const f57 = tep('57_a.sql', '﻿ALTER TABLE a ADD COLUMN x int;\n\n');

  assert.deepEqual(gop([f58, f57b, f57], dich), ['57_a.sql', '57b_b.sql', '58_c.sql']);
  const s = fs.readFileSync(dich, 'utf8');
  assert.ok(s.startsWith('-- lược đồ gốc\nCREATE TABLE a (id int);\n'), 'giữ nguyên phần đã có');
  assert.equal(s.indexOf('﻿'), -1, 'bỏ BOM');
  assert.ok(!s.includes('\r'), 'đổi CRLF thành LF');
  assert.ok(s.includes('\n-- >>> 57_a.sql\nALTER TABLE a ADD COLUMN x int;\n-- <<< 57_a.sql\n'));
  assert.ok(s.indexOf('-- >>> 57_a.sql') < s.indexOf('-- >>> 57b_b.sql') && s.indexOf('-- >>> 57b_b.sql') < s.indexOf('-- >>> 58_c.sql'));

  assert.throws(() => gop([f57], dich), /đã có/);
  assert.equal(fs.readFileSync(dich, 'utf8'), s, 'gộp trùng không ghi gì');
  assert.throws(() => gop([tep('khong_so.sql', 'x;')], dich), /N_\*\.sql/);
  fs.rmSync(dir, { recursive: true, force: true });
});
