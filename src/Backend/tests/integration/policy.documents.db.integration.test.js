/**
 * Migration 54 trên CSDL thử thật (TEST_DATABASE_URL đã áp migration 49, 54): trigger chỉ cho đổi trạng thái,
 * mỗi chính sách tối đa một bản ACTIVE, luồng thêm / ngừng / kích hoạt / đồng ý của policy.service.
 */
const { describe, it, before } = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('../../config/db');
const policyService = require('../../modules/policy/policy.service');

const uniq = () => `IT chính sách ${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;

describe('Migration 54: ràng buộc CSDL', () => {
  let accountId;
  before(async () => {
    accountId = (await pool.query('SELECT "Idaccount" AS id FROM "account" ORDER BY 1 LIMIT 1')).rows[0].id;
  });

  it('mọi phiên bản đều thuộc một chính sách và có số phiên bản; tiêu đề chính sách không trùng', async () => {
    const orphan = (await pool.query('SELECT count(*)::int n FROM "privacy_policy" WHERE "document_id" IS NULL OR "doc_version" IS NULL')).rows[0].n;
    assert.equal(orphan, 0);
    await assert.rejects(pool.query(`INSERT INTO "policy_document" ("title") SELECT "title" FROM "policy_document" LIMIT 1`), /uq_policy_document_title/);
  });

  it('trigger: đổi trạng thái được; sửa nội dung / tiêu đề / số phiên bản bị chặn', async () => {
    const created = await policyService.createVersion(await policyService.publish({ title: uniq(), content: 'Nội dung gốc' }, accountId));
    await pool.query(`UPDATE "privacy_policy" SET "status" = 'ACTIVE', "status_changed_at" = now() WHERE "version" = $1`, [created.version]);
    await pool.query(`UPDATE "privacy_policy" SET "status" = 'INACTIVE' WHERE "version" = $1`, [created.version]);
    await assert.rejects(pool.query(`UPDATE "privacy_policy" SET "content" = 'sửa lén' WHERE "version" = $1`, [created.version]), /chỉ được đổi trạng thái/);
    await assert.rejects(pool.query(`UPDATE "privacy_policy" SET "title" = 'đổi tên' WHERE "version" = $1`, [created.version]), /chỉ được đổi trạng thái/);
    await assert.rejects(pool.query(`UPDATE "privacy_policy" SET "doc_version" = 99 WHERE "version" = $1`, [created.version]), /chỉ được đổi trạng thái/);
    const row = (await pool.query('SELECT "content" FROM "privacy_policy" WHERE "version" = $1', [created.version])).rows[0];
    assert.equal(row.content, 'Nội dung gốc');
  });

  it('index: một chính sách không thể có hai bản ACTIVE; trạng thái chỉ nhận ACTIVE / INACTIVE', async () => {
    const v1 = await policyService.createVersion(await policyService.publish({ title: uniq(), content: 'v1' }, accountId));
    const v2 = await policyService.createVersion(await policyService.publish({ documentId: v1.document_id, content: 'v2' }, accountId));
    await pool.query(`UPDATE "privacy_policy" SET "status" = 'ACTIVE' WHERE "version" = $1`, [v1.version]);
    await assert.rejects(pool.query(`UPDATE "privacy_policy" SET "status" = 'ACTIVE' WHERE "version" = $1`, [v2.version]), /uq_privacy_policy_one_active/);
    await assert.rejects(pool.query(`UPDATE "privacy_policy" SET "status" = 'DELETED' WHERE "version" = $1`, [v2.version]), /ck_privacy_policy_status/);
  });

  it('bằng chứng đồng ý vẫn chỉ được thêm, không sửa', async () => {
    const p = await policyService.createVersion(await policyService.publish({ title: uniq(), content: 'x' }, accountId));
    await policyService.setStatus({ version: p.version, status: 'ACTIVE', actorId: accountId });
    await policyService.accept(accountId, p.version, { headers: {} });
    await assert.rejects(
      pool.query('UPDATE "policy_acceptance" SET "device_name" = $1 WHERE "idaccount" = $2 AND "policy_version" = $3', ['x', accountId, p.version]),
      /chỉ được thêm/
    );
  });
});

describe('Luồng policy.service trên CSDL thật', () => {
  let accountId;
  before(async () => {
    accountId = (await pool.query('SELECT "Idaccount" AS id FROM "account" ORDER BY 1 LIMIT 1')).rows[0].id;
  });

  it('thêm chính sách mới (v1) và phiên bản mới (v2) đều Ngừng sử dụng; phiên bản tăng theo chính sách', async () => {
    const title = uniq();
    const v1 = await policyService.createVersion(await policyService.publish({ title, content: 'a' }, accountId));
    const v2 = await policyService.createVersion(await policyService.publish({ documentId: v1.document_id, content: 'b' }, accountId));
    assert.deepEqual([v1.doc_version, v1.status, v2.doc_version, v2.status], [1, 'INACTIVE', 2, 'INACTIVE']);
    assert.equal(v2.document.title, title);
    await assert.rejects(policyService.createVersion({ title, content: 'c', publishedBy: accountId }), (e) => e.code === 'POLICY_TITLE_EXISTS');
  });

  it('kích hoạt khi đã có bản đang dùng: 409; ngừng bản kia rồi kích hoạt được; người dùng phải đồng ý bản mới', async () => {
    const v1 = await policyService.createVersion(await policyService.publish({ title: uniq(), content: 'a' }, accountId));
    const v2 = await policyService.createVersion(await policyService.publish({ documentId: v1.document_id, content: 'b' }, accountId));
    await policyService.setStatus({ version: v1.version, status: 'ACTIVE', actorId: accountId });
    await policyService.accept(accountId, v1.version, { headers: {} });
    await assert.rejects(policyService.setStatus({ version: v2.version, status: 'ACTIVE', actorId: accountId }), (e) => e.code === 'POLICY_ALREADY_ACTIVE');
    await policyService.setStatus({ version: v1.version, status: 'INACTIVE', actorId: accountId });
    const on = await policyService.setStatus({ version: v2.version, status: 'ACTIVE', actorId: accountId });
    assert.equal(on.status, 'ACTIVE');
    assert.equal(on.status_changed_by, accountId);
    const st = await policyService.getStatus(accountId);
    const mine = st.policies.find((p) => p.version === v2.version);
    assert.equal(mine.accepted, false);
    assert.equal(st.mustAccept, true);
    await assert.rejects(policyService.accept(accountId, v1.version, { headers: {} }), (e) => e.code === 'POLICY_VERSION_OUTDATED');
    await policyService.setStatus({ version: v2.version, status: 'INACTIVE', actorId: accountId });
  });

  it('danh sách cho admin: đủ trường, có danh sách chính sách để chọn', async () => {
    const d = await policyService.listForAdmin();
    assert.ok(d.policies.length > 0);
    for (const p of d.policies) {
      assert.ok(p.title && p.docVersion > 0 && ['ACTIVE', 'INACTIVE'].includes(p.status));
    }
    assert.ok(d.documents.length > 0);
  });
});
