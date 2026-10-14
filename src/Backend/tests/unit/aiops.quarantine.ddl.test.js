const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

test('AIOps Quarantine DDL & Database Schema Verification (Task 1)', async (t) => {
  const ddlFilePath = path.join(__dirname, '../../database/26_create_aiops_quarantine_tables.sql');
  const prismaSchemaPath = path.join(__dirname, '../../prisma/schema.prisma');

  await t.test('1. File migration SQL DDL 26 phải tồn tại và có nội dung', () => {
    assert.strictEqual(fs.existsSync(ddlFilePath), true, 'File 26_create_aiops_quarantine_tables.sql phải tồn tại');
    const content = fs.readFileSync(ddlFilePath, 'utf8');
    assert.ok(content.length > 100, 'Nội dung DDL phải hợp lệ');
  });

  await t.test('2. Bảng aiops_ip_quarantine phải có đầy đủ các cột và kiểu dữ liệu chuẩn', () => {
    const content = fs.readFileSync(ddlFilePath, 'utf8');
    assert.ok(/CREATE TABLE IF NOT EXISTS\s+"aiops_ip_quarantine"/i.test(content), 'Thiếu CREATE TABLE aiops_ip_quarantine');
    assert.ok(/"id"\s+VARCHAR\(64\)\s+PRIMARY KEY/i.test(content), 'Thiếu id PK');
    assert.ok(/"ip_hash"\s+VARCHAR\(64\)\s+NOT NULL/i.test(content), 'Thiếu ip_hash');
    assert.ok(/"masked_ip"\s+VARCHAR\(45\)\s+NOT NULL/i.test(content), 'Thiếu masked_ip');
    assert.ok(/"status"\s+VARCHAR\(20\)\s+NOT NULL/i.test(content), 'Thiếu status');
    assert.ok(/"reason"\s+TEXT\s+NOT NULL/i.test(content), 'Thiếu reason');
    assert.ok(/"hits"\s+INT/i.test(content), 'Thiếu hits');
    assert.ok(/"banned_at"\s+TIMESTAMP/i.test(content), 'Thiếu banned_at');
    assert.ok(/"expires_at"\s+TIMESTAMP/i.test(content), 'Thiếu expires_at');
    assert.ok(/"unblocked_at"\s+TIMESTAMP/i.test(content), 'Thiếu unblocked_at');
    assert.ok(/"banned_by"\s+VARCHAR/i.test(content), 'Thiếu banned_by');
    assert.ok(/"unblocked_by"\s+VARCHAR/i.test(content), 'Thiếu unblocked_by');
  });

  await t.test('3. Bảng aiops_account_quarantine phải có đầy đủ các cột và kiểu dữ liệu chuẩn', () => {
    const content = fs.readFileSync(ddlFilePath, 'utf8');
    assert.ok(/CREATE TABLE IF NOT EXISTS\s+"aiops_account_quarantine"/i.test(content), 'Thiếu CREATE TABLE aiops_account_quarantine');
    assert.ok(/"id"\s+VARCHAR\(64\)\s+PRIMARY KEY/i.test(content), 'Thiếu id PK');
    assert.ok(/"username"\s+VARCHAR\(255\)\s+NOT NULL/i.test(content), 'Thiếu username');
    assert.ok(/"idaccount"\s+INT/i.test(content), 'Thiếu idaccount');
    assert.ok(/"status"\s+VARCHAR\(20\)\s+NOT NULL/i.test(content), 'Thiếu status');
    assert.ok(/"reason"\s+TEXT\s+NOT NULL/i.test(content), 'Thiếu reason');
    assert.ok(/"banned_at"\s+TIMESTAMP/i.test(content), 'Thiếu banned_at');
    assert.ok(/"unblocked_at"\s+TIMESTAMP/i.test(content), 'Thiếu unblocked_at');
    assert.ok(/"banned_by"\s+VARCHAR/i.test(content), 'Thiếu banned_by');
    assert.ok(/"unblocked_by"\s+VARCHAR/i.test(content), 'Thiếu unblocked_by');
  });

  await t.test('4. Bảng liên kết aiops_quarantine_incident_link phải chứa khóa ngoại N-N và các cột audit', () => {
    const content = fs.readFileSync(ddlFilePath, 'utf8');
    assert.ok(/CREATE TABLE IF NOT EXISTS\s+"aiops_quarantine_incident_link"/i.test(content), 'Thiếu CREATE TABLE aiops_quarantine_incident_link');
    assert.ok(/"ip_quarantine_id"\s+VARCHAR\(64\)/i.test(content), 'Thiếu ip_quarantine_id');
    assert.ok(/"account_quarantine_id"\s+VARCHAR\(64\)/i.test(content), 'Thiếu account_quarantine_id');
    assert.ok(/"ip_hash"\s+VARCHAR\(64\)/i.test(content), 'Thiếu ip_hash');
    assert.ok(/"username"\s+VARCHAR\(255\)/i.test(content), 'Thiếu username');
    assert.ok(/"reason"\s+TEXT/i.test(content), 'Thiếu reason');
    assert.ok(/"detected_at"\s+TIMESTAMP/i.test(content), 'Thiếu detected_at');
  });

  await t.test('5. Phải có đầy đủ các chỉ mục tối ưu hóa truy vấn an toàn (IF NOT EXISTS)', () => {
    const content = fs.readFileSync(ddlFilePath, 'utf8');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_aiops_ip_quarantine_status"/i.test(content), 'Thiếu idx_aiops_ip_quarantine_status');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_aiops_ip_quarantine_ip_hash"/i.test(content), 'Thiếu idx_aiops_ip_quarantine_ip_hash');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_aiops_account_quarantine_status"/i.test(content), 'Thiếu idx_aiops_account_quarantine_status');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_aiops_account_quarantine_username"/i.test(content), 'Thiếu idx_aiops_account_quarantine_username');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_quarantine_link_ip"/i.test(content), 'Thiếu idx_quarantine_link_ip');
    assert.ok(/CREATE INDEX IF NOT EXISTS\s+"idx_quarantine_link_account"/i.test(content), 'Thiếu idx_quarantine_link_account');
  });

  await t.test('6. Schema Prisma phải có định nghĩa cho cả 3 models để hỗ trợ Prisma Client', () => {
    const content = fs.readFileSync(prismaSchemaPath, 'utf8');
    assert.ok(/model aiops_ip_quarantine\s+\{/i.test(content), 'Thiếu model aiops_ip_quarantine trong Prisma schema');
    assert.ok(/model aiops_account_quarantine\s+\{/i.test(content), 'Thiếu model aiops_account_quarantine trong Prisma schema');
    assert.ok(/model aiops_quarantine_incident_link\s+\{/i.test(content), 'Thiếu model aiops_quarantine_incident_link trong Prisma schema');
  });
});
