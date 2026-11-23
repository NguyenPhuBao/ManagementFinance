const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

// Lược đồ cài mới database/FlowMoney_Schema.sql (định dạng pg_dump) phải có đủ 3 bảng phong toả AIOps.
test('AIOps Quarantine DDL & Database Schema Verification (Task 1)', async (t) => {
  const schemaPath = path.join(__dirname, '../../database/FlowMoney_Schema.sql');
  const prismaSchemaPath = path.join(__dirname, '../../prisma/schema.prisma');
  const schema = () => fs.readFileSync(schemaPath, 'utf8');
  const bang = (ten) => {
    const m = schema().match(new RegExp(`^CREATE TABLE public\\.${ten} \\(\\n([\\s\\S]*?)\\n\\);`, 'm'));
    assert.ok(m, `Thiếu CREATE TABLE ${ten}`);
    return m[1];
  };
  const cot = (than, ten, kieu) => assert.ok(new RegExp(`^\\s+${ten} ${kieu}`, 'm').test(than), `Thiếu cột ${ten} ${kieu}`);

  await t.test('1. FlowMoney_Schema.sql phải tồn tại và có nội dung', () => {
    assert.ok(fs.existsSync(schemaPath), 'Thiếu database/FlowMoney_Schema.sql');
    assert.ok(schema().length > 100, 'Nội dung DDL phải hợp lệ');
  });

  await t.test('2. Bảng aiops_ip_quarantine phải có đầy đủ các cột và kiểu dữ liệu chuẩn', () => {
    const b = bang('aiops_ip_quarantine');
    cot(b, 'id', 'character varying\\(64\\) NOT NULL');
    assert.ok(/ADD CONSTRAINT aiops_ip_quarantine_pkey PRIMARY KEY \(id\);/.test(schema()), 'Thiếu id PK');
    cot(b, 'ip_hash', 'character varying\\(64\\) NOT NULL');
    cot(b, 'masked_ip', 'character varying\\(45\\) NOT NULL');
    cot(b, 'status', 'character varying\\(20\\)[^,]* NOT NULL');
    cot(b, 'reason', 'text NOT NULL');
    cot(b, 'hits', 'integer');
    cot(b, 'banned_at', 'timestamp');
    cot(b, 'expires_at', 'timestamp');
    cot(b, 'unblocked_at', 'timestamp');
    cot(b, 'banned_by', 'character varying');
    cot(b, 'unblocked_by', 'character varying');
  });

  await t.test('3. Bảng aiops_account_quarantine phải có đầy đủ các cột và kiểu dữ liệu chuẩn', () => {
    const b = bang('aiops_account_quarantine');
    cot(b, 'id', 'character varying\\(64\\) NOT NULL');
    assert.ok(/ADD CONSTRAINT aiops_account_quarantine_pkey PRIMARY KEY \(id\);/.test(schema()), 'Thiếu id PK');
    cot(b, 'username', 'character varying\\(255\\) NOT NULL');
    cot(b, 'idaccount', 'integer');
    cot(b, 'status', 'character varying\\(20\\)[^,]* NOT NULL');
    cot(b, 'reason', 'text NOT NULL');
    cot(b, 'banned_at', 'timestamp');
    cot(b, 'unblocked_at', 'timestamp');
    cot(b, 'banned_by', 'character varying');
    cot(b, 'unblocked_by', 'character varying');
  });

  await t.test('4. Bảng liên kết aiops_quarantine_incident_link phải chứa khóa ngoại N-N và các cột audit', () => {
    const b = bang('aiops_quarantine_incident_link');
    cot(b, 'ip_quarantine_id', 'character varying\\(64\\)');
    cot(b, 'account_quarantine_id', 'character varying\\(64\\)');
    cot(b, 'ip_hash', 'character varying\\(64\\)');
    cot(b, 'username', 'character varying\\(255\\)');
    cot(b, 'reason', 'text');
    cot(b, 'detected_at', 'timestamp');
  });

  await t.test('5. Phải có đầy đủ các chỉ mục tối ưu hóa truy vấn', () => {
    const s = schema();
    for (const idx of ['idx_aiops_ip_quarantine_status', 'idx_aiops_ip_quarantine_ip_hash', 'idx_aiops_account_quarantine_status',
      'idx_aiops_account_quarantine_username', 'idx_quarantine_link_ip', 'idx_quarantine_link_account']) {
      assert.ok(new RegExp(`^CREATE INDEX ${idx} ON public\\.`, 'm').test(s), `Thiếu ${idx}`);
    }
  });

  await t.test('6. Schema Prisma phải có định nghĩa cho cả 3 models để hỗ trợ Prisma Client', () => {
    const content = fs.readFileSync(prismaSchemaPath, 'utf8');
    assert.ok(/model aiops_ip_quarantine\s+\{/i.test(content), 'Thiếu model aiops_ip_quarantine trong Prisma schema');
    assert.ok(/model aiops_account_quarantine\s+\{/i.test(content), 'Thiếu model aiops_account_quarantine trong Prisma schema');
    assert.ok(/model aiops_quarantine_incident_link\s+\{/i.test(content), 'Thiếu model aiops_quarantine_incident_link trong Prisma schema');
  });
});
