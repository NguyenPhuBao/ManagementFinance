/**
 * Script bù danh mục riêng (kế hoạch 2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md, B6).
 *
 * (a) Tài khoản chưa xoá, CHƯA TỪNG có danh mục riêng (kể cả hàng xoá mềm) ⇒ tạo bản riêng từ khuôn đang hoạt động.
 * (b) transaction / budget / bill (không thuộc nhà) còn trỏ vào khuôn ⇒ trỏ sang bản riêng cùng tên chuẩn hoá của chính
 *     tài khoản đó, nâng Server_update_at để máy khác kéo về. Không có bản cùng tên, hoặc hàng thuộc nhà ⇒ chỉ báo.
 * Mặc định chạy thử (không ghi). Chạy lại lần hai không đổi gì.
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const { buDanhMucCaNhan } = require('../../scripts/bu_danh_muc_ca_nhan');

/** CSDL giả trong bộ nhớ, hiểu đúng các điều kiện script dùng: bằng, null, { in }, { not: null }. */
function fakeDb(seed) {
  const t = JSON.parse(JSON.stringify(seed));
  const match = (row, where = {}) => Object.entries(where).every(([k, v]) => {
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      if ('in' in v) return v.in.includes(row[k]);
      if ('not' in v) return v.not === null ? row[k] !== null && row[k] !== undefined : row[k] !== v.not;
    }
    if (v === null) return row[k] === null || row[k] === undefined;
    return row[k] === v;
  });
  const table = (name, pk) => ({
    findMany: async ({ where } = {}) => t[name].filter((r) => match(r, where)).map((r) => ({ ...r })),
    createMany: async ({ data }) => { t[name].push(...data.map((d) => ({ ...d }))); return { count: data.length }; },
    update: async ({ where, data }) => {
      const r = t[name].find((x) => x[pk] === where[pk]);
      Object.assign(r, data);
      return r;
    },
  });
  const db = {
    tables: t,
    account: table('account', 'idaccount'),
    category: table('category', 'idcategory'),
    transaction: table('transaction', 'idtran'),
    budget: table('budget', 'idbudget'),
    bill: table('bill', 'idbill'),
  };
  db.$transaction = async (cb) => cb(db);
  return db;
}

const tpl = (id, name, extra = {}) => ({
  idcategory: id, name_category: name, classify: 'Chi', keyword: null, icon: null, color: null, create_by: 1,
  is_default: true, is_group: false, idhousehold: null, delete_at: null, create_at: '2026-01-01T00:00:00Z', ...extra,
});
const own = (id, acc, name, extra = {}) => ({
  idcategory: id, name_category: name, classify: 'Chi', create_by: acc, is_default: false, is_group: false,
  idhousehold: null, delete_at: null, ...extra,
});

function seedData() {
  return {
    account: [
      { idaccount: 10, delete_at: null },   // chưa có danh mục riêng ⇒ được bù
      { idaccount: 11, delete_at: null },   // đã có bản riêng ⇒ không bù
      { idaccount: 12, delete_at: null },   // từng có nhưng đã xoá hết (xoá mềm) ⇒ KHÔNG bù lại
      { idaccount: 13, delete_at: '2026-10-01T00:00:00Z' }, // tài khoản đã xoá ⇒ bỏ qua
    ],
    category: [
      tpl('T-AN', 'Ăn uống'), tpl('T-DL', 'Đi lại'), tpl('T-OLD', 'Cũ', { delete_at: '2026-09-01T00:00:00Z' }),
      own('P11-AN', 11, 'ăn  uống'),
      own('P12-X', 12, 'Riêng', { delete_at: '2026-09-02T00:00:00Z' }),
    ],
    transaction: [
      { idtran: 'tr1', idaccount: 11, idcategory: 'T-AN', idhousehold: null },  // dời sang P11-AN
      { idtran: 'tr2', idaccount: 11, idcategory: 'T-DL', idhousehold: null },  // 11 không có bản "Đi lại" ⇒ báo
      { idtran: 'tr3', idaccount: 11, idcategory: 'T-AN', idhousehold: 7 },     // thuộc nhà ⇒ báo, không dời
      { idtran: 'tr4', idaccount: 10, idcategory: 'T-OLD', idhousehold: null }, // khuôn đã xoá, 10 không có bản "Cũ" ⇒ báo
      { idtran: 'tr5', idaccount: 11, idcategory: 'P11-AN', idhousehold: null }, // đã đúng ⇒ không đụng
    ],
    budget: [{ idbudget: 'b1', idaccount: 10, idcategory: 'T-AN', idhousehold: null }], // 10 được bù "Ăn uống" ⇒ dời
    bill: [{ idbill: 'h1', idaccount: 11, idcategory: 'T-AN' }],                      // dời sang P11-AN
  };
}

describe('Script bù danh mục riêng', () => {
  it('chạy thử: báo đúng số liệu, không ghi gì', async () => {
    const db = fakeDb(seedData());
    const before = JSON.stringify(db.tables);
    const r = await buDanhMucCaNhan(db, { apply: false });
    assert.strictEqual(JSON.stringify(db.tables), before, 'chạy thử không được ghi');
    assert.strictEqual(r.apply, false);
    assert.deepStrictEqual(r.taiKhoanCanBu, 1);      // chỉ tài khoản 10
    assert.strictEqual(r.banRiengSeTao, 2);            // Ăn uống, Đi lại (khuôn sống)
  });

  it('ghi thật: bù tài khoản thiếu, dời tham chiếu, báo hàng không dời được', async () => {
    const db = fakeDb(seedData());
    const r = await buDanhMucCaNhan(db, { apply: true });
    const cats = db.tables.category;
    const p10 = cats.filter((c) => c.create_by === 10 && !c.is_default);
    assert.deepStrictEqual(p10.map((c) => c.name_category).sort(), ['Ăn uống', 'Đi lại']);
    assert.strictEqual(cats.filter((c) => c.create_by === 11).length, 1, 'tài khoản đã có bản riêng không được bù thêm');
    assert.strictEqual(cats.filter((c) => c.create_by === 12).length, 1, 'tài khoản đã xoá hết danh mục không được tạo lại');
    assert.strictEqual(cats.filter((c) => c.create_by === 13).length, 0);

    const tr = Object.fromEntries(db.tables.transaction.map((x) => [x.idtran, x]));
    assert.strictEqual(tr.tr1.idcategory, 'P11-AN');
    assert.ok(tr.tr1.server_update_at, 'phải nâng Server_update_at để máy khác kéo về');
    assert.strictEqual(tr.tr2.idcategory, 'T-DL');
    assert.strictEqual(tr.tr3.idcategory, 'T-AN');
    assert.strictEqual(tr.tr4.idcategory, 'T-OLD');
    assert.strictEqual(tr.tr5.server_update_at, undefined, 'hàng đã đúng không bị đụng');
    const an10 = p10.find((c) => c.name_category === 'Ăn uống').idcategory;
    assert.strictEqual(db.tables.budget[0].idcategory, an10, 'dời sang bản vừa bù trong cùng lượt');
    assert.strictEqual(db.tables.bill[0].idcategory, 'P11-AN');

    assert.strictEqual(r.taiKhoanDaBu, 1);
    assert.strictEqual(r.thamChieuDaDoi, 3);           // tr1, b1, h1
    assert.strictEqual(r.thamChieuKhongDoi, 3);        // tr2, tr3, tr4
  });

  it('chạy lại lần hai không đổi gì (luỹ đẳng)', async () => {
    const db = fakeDb(seedData());
    await buDanhMucCaNhan(db, { apply: true });
    const after1 = JSON.stringify(db.tables);
    const r2 = await buDanhMucCaNhan(db, { apply: true });
    assert.strictEqual(JSON.stringify(db.tables), after1);
    assert.strictEqual(r2.taiKhoanDaBu, 0);
    assert.strictEqual(r2.thamChieuDaDoi, 0);
  });

  it('báo cáo chỉ có số đếm, không mang tên danh mục hay id tài khoản', async () => {
    const r = await buDanhMucCaNhan(fakeDb(seedData()), { apply: false });
    assert.doesNotMatch(JSON.stringify(r), /Ăn uống|Đi lại|"10"|idaccount/);
  });
});
