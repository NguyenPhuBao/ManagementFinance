/**
 * Danh mục mặc định chỉ áp cho tài khoản mới (Chủ dự án chốt 2026-11-17).
 * Kế hoạch: docs/superpowers/plans/2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md
 *
 * - Mọi tài khoản (người dùng đăng ký, quản trị do Admin tạo) được tạo kèm bản danh mục riêng, chép từ khuôn đang hoạt động,
 *   trong cùng giao tác tạo tài khoản.
 * - /sync/pull không còn trả hàng khuôn (is_default = true): thay đổi khuôn không tới được tài khoản đã có.
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const { prisma } = require('../../config/db');
const { buildPersonalCopies, seedPersonalCategories, normalizeName } = require('../../modules/account/personal-categories');
const authRepository = require('../../modules/auth/auth.repository');
const adminRepository = require('../../modules/admin/admin.repository');
const syncRepository = require('../../modules/sync/sync.repository');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const khuon = (over = {}) => ({
  idcategory: over.idcategory || 'tpl-' + Math.random().toString(36).slice(2),
  name_category: 'Ăn uống',
  classify: 'Chi',
  keyword: 'pho,com',
  icon: 'food',
  color: '#FF0000',
  is_default: true,
  is_group: false,
  idgroup: null,
  idhousehold: null,
  delete_at: null,
  create_at: new Date('2026-01-01'),
  ...over,
});

/** Giao tác giả: ghi lại mọi lệnh gọi, trả khuôn cho category.findMany. */
function fakeTx(templates, created = []) {
  const calls = { findMany: [], createMany: [] };
  const tx = {
    calls,
    account: { create: async ({ data }) => ({ idaccount: 77, ...data }) },
    user: { create: async ({ data }) => ({ iduser: 9, ...data }) },
    User: { create: async ({ data }) => ({ iduser: 9, ...data }) },
    category: {
      findMany: async (args) => { calls.findMany.push(args); return templates; },
      createMany: async (args) => { calls.createMany.push(args); created.push(...args.data); return { count: args.data.length }; },
    },
  };
  return tx;
}

describe('buildPersonalCopies (tầng 1: luật chép)', () => {
  it('chép đủ trường, gán đúng chủ, không còn là khuôn, id mới dạng UUID', () => {
    const t = khuon({ idcategory: 'tpl-1' });
    const [c] = buildPersonalCopies([t], 42);
    assert.strictEqual(c.create_by, 42);
    assert.strictEqual(c.is_default, false);
    assert.strictEqual(c.is_group, false);
    assert.strictEqual(c.idgroup, null);
    assert.strictEqual(c.idhousehold, null);
    assert.strictEqual(c.name_category, 'Ăn uống');
    assert.strictEqual(c.classify, 'Chi');
    assert.strictEqual(c.keyword, 'pho,com');
    assert.strictEqual(c.icon, 'food');
    assert.strictEqual(c.color, '#FF0000');
    assert.match(c.idcategory, UUID_RE);
    assert.notStrictEqual(c.idcategory, 'tpl-1');
  });

  it('bỏ khuôn đã xoá mềm, khuôn nhóm, hàng của nhà, hàng không phải khuôn', () => {
    const out = buildPersonalCopies([
      khuon({ name_category: 'A' }),
      khuon({ name_category: 'B', delete_at: new Date() }),
      khuon({ name_category: 'C', is_group: true }),
      khuon({ name_category: 'D', idhousehold: 5 }),
      khuon({ name_category: 'E', is_default: false }),
    ], 1);
    assert.deepStrictEqual(out.map((c) => c.name_category), ['A']);
  });

  it('khuôn trùng tên chuẩn hoá (khác hoa thường, khoảng trắng, khác loại) chỉ sinh MỘT bản, giữ khuôn tạo sớm nhất', () => {
    const out = buildPersonalCopies([
      khuon({ name_category: 'Trả  nợ ', classify: 'Vay', create_at: new Date('2026-03-01') }),
      khuon({ name_category: 'trả nợ', classify: 'Chi', create_at: new Date('2026-02-01') }),
    ], 1);
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].classify, 'Chi');
  });

  it('normalizeName khớp chỉ mục uq_category_owner_name (NFC, trim, gộp khoảng trắng, chữ thường)', () => {
    assert.strictEqual(normalizeName('  Ăn   UỐNG '), normalizeName('ăn uống'));
    assert.strictEqual(normalizeName('À'), normalizeName('À'));
  });

  it('mỗi lần gọi sinh id mới, không dùng lại giữa hai tài khoản', () => {
    const t = [khuon()];
    assert.notStrictEqual(buildPersonalCopies(t, 1)[0].idcategory, buildPersonalCopies(t, 2)[0].idcategory);
  });
});

describe('seedPersonalCategories (tầng 2: ghi qua giao tác)', () => {
  it('đọc khuôn đang hoạt động bằng chính giao tác và ghi createMany', async () => {
    const tx = fakeTx([khuon({ name_category: 'A' }), khuon({ name_category: 'B' })]);
    const n = await seedPersonalCategories(tx, 42);
    assert.strictEqual(n, 2);
    const where = tx.calls.findMany[0].where;
    assert.strictEqual(where.is_default, true);
    assert.strictEqual(where.delete_at, null);
    assert.strictEqual(tx.calls.createMany.length, 1);
    assert.ok(tx.calls.createMany[0].data.every((c) => c.create_by === 42));
  });

  it('không có khuôn thì không gọi createMany', async () => {
    const tx = fakeTx([]);
    assert.strictEqual(await seedPersonalCategories(tx, 42), 0);
    assert.strictEqual(tx.calls.createMany.length, 0);
  });
});

describe('Tạo tài khoản ⇒ có bản danh mục riêng trong cùng giao tác (tầng 2)', () => {
  const runWith = async (templates, fn) => {
    const created = [];
    const tx = fakeTx(templates, created);
    const saved = prisma.$transaction;
    prisma.$transaction = async (cb) => cb(tx);
    try { await fn(); } finally { prisma.$transaction = saved; }
    return created;
  };

  it('người dùng đăng ký: danh mục riêng mang id tài khoản mới', async () => {
    const created = await runWith([khuon({ name_category: 'A' }), khuon({ name_category: 'B' })], () =>
      authRepository.createAccountWithUser({ username: 'u1', email: 'u1@example.test', hashedPassword: 'x', fullname: 'U' }));
    assert.strictEqual(created.length, 2);
    assert.ok(created.every((c) => c.create_by === 77 && c.is_default === false));
  });

  it('tài khoản quản trị do Admin tạo: cũng có danh mục riêng', async () => {
    const created = await runWith([khuon({ name_category: 'A' })], () =>
      adminRepository.createAdminAccount({ username: 'ad1', email: 'ad1@example.test', passwordHash: 'x', pinHash: 'y' }));
    assert.strictEqual(created.length, 1);
    assert.strictEqual(created[0].create_by, 77);
  });

  it('tạo danh mục lỗi ⇒ lỗi nổi lên để giao tác huỷ cả tài khoản', async () => {
    const tx = fakeTx([khuon()]);
    tx.category.createMany = async () => { throw new Error('boom'); };
    const saved = prisma.$transaction;
    prisma.$transaction = async (cb) => cb(tx);
    try {
      await assert.rejects(() =>
        authRepository.createAccountWithUser({ username: 'u2', email: 'u2@example.test', hashedPassword: 'x', fullname: 'U' }), /boom/);
    } finally { prisma.$transaction = saved; }
  });
});

describe('/sync/pull không còn trả khuôn (tầng 2)', () => {
  const capture = async (fn) => {
    const saved = { many: prisma.category.findMany, count: prisma.category.count };
    let args;
    prisma.category.findMany = async (a) => { args = a; return []; };
    prisma.category.count = async (a) => { args = a; return 0; };
    try { await fn(); } finally { prisma.category.findMany = saved.many; prisma.category.count = saved.count; }
    return args;
  };
  const hasDefault = (where) => JSON.stringify(where).includes('"is_default":true');

  it('getCategoriesByAccount chỉ lấy danh mục của tài khoản (và nhà đang ở), không lấy is_default', async () => {
    const args = await capture(() => syncRepository.getCategoriesByAccount(42, null, 5));
    assert.ok(!hasDefault(args.where), 'không được kèm điều kiện is_default = true');
    const s = JSON.stringify(args.where);
    assert.match(s, /"create_by":42/);
    assert.match(s, /"idhousehold":5/);
  });

  it('countCategory không đếm khuôn', async () => {
    const args = await capture(() => syncRepository.countCategory(42));
    assert.ok(!hasDefault(args.where));
  });
});
