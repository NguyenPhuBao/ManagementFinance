/**
 * Bù danh mục riêng cho tài khoản đã có (kế hoạch docs/superpowers/plans/2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md, B6).
 *
 * (a) Tài khoản chưa xoá, CHƯA TỪNG có danh mục riêng (kể cả hàng xoá mềm) ⇒ tạo bản riêng từ khuôn đang hoạt động.
 *     Tài khoản từng có rồi xoá hết là ý của người dùng ⇒ không tạo lại.
 * (b) transaction / budget / bill còn trỏ vào khuôn ⇒ trỏ sang bản riêng cùng tên chuẩn hoá của chính tài khoản đó, nâng
 *     Server_update_at để máy khác kéo về. Hàng thuộc nhà, hoặc tài khoản không có bản cùng tên ⇒ chỉ đếm, không đoán.
 *     Lý do: từ 2026-11-17 /sync/pull không còn trả khuôn, hàng trỏ vào khuôn sẽ mồ côi trên máy cài mới.
 *
 * Luỹ đẳng. Báo cáo chỉ có số đếm.
 *
 * Cách chạy (từ src/Backend, CSDL lấy theo DATABASE_URL đang hiệu lực):
 *   node scripts/bu_danh_muc_ca_nhan.js                          # chạy thử, không ghi
 *   node scripts/bu_danh_muc_ca_nhan.js --apply --xac-nhan=<tên CSDL>   # ghi thật; tên phải khớp current_database()
 * Supabase dùng chung: chỉ chạy --apply khi Chủ dự án xác nhận đích danh.
 */
const { buildPersonalCopies, normalizeName } = require('../modules/account/personal-categories');

const BANG_THAM_CHIEU = [
  { bang: 'transaction', khoa: 'idtran', coNha: true },
  { bang: 'budget', khoa: 'idbudget', coNha: true },
  { bang: 'bill', khoa: 'idbill', coNha: false },
];

async function buDanhMucCaNhan(db, { apply = false } = {}) {
  const accounts = await db.account.findMany({ where: { delete_at: null }, select: { idaccount: true } });
  const owned = await db.category.findMany({
    where: { is_default: false, idhousehold: null },
    select: { idcategory: true, create_by: true, name_category: true, delete_at: true },
  });
  const templates = await db.category.findMany({ where: { is_default: true } });

  const ownedBy = new Map();
  for (const c of owned) {
    if (!ownedBy.has(c.create_by)) ownedBy.set(c.create_by, []);
    ownedBy.get(c.create_by).push(c);
  }

  // (a) Lập kế hoạch bản riêng.
  const banSao = new Map(); // idaccount -> bản riêng sẽ tạo
  for (const { idaccount } of accounts) {
    if (ownedBy.has(idaccount)) continue;
    const copies = buildPersonalCopies(templates, idaccount);
    if (copies.length) banSao.set(idaccount, copies);
  }

  // Bản riêng còn sống theo tên chuẩn hoá, gồm cả bản sắp tạo, để dời tham chiếu trong cùng lượt.
  const banRiengTheoTen = new Map();
  const ghiTen = (acc, ten, id) => {
    if (!banRiengTheoTen.has(acc)) banRiengTheoTen.set(acc, new Map());
    const m = banRiengTheoTen.get(acc);
    if (!m.has(ten)) m.set(ten, id);
  };
  for (const c of owned) if (!c.delete_at) ghiTen(c.create_by, normalizeName(c.name_category), c.idcategory);
  for (const [acc, copies] of banSao) for (const c of copies) ghiTen(acc, normalizeName(c.name_category), c.idcategory);

  // (b) Lập kế hoạch dời tham chiếu.
  const tenKhuon = new Map(templates.map((t) => [t.idcategory, normalizeName(t.name_category)]));
  const idKhuon = [...tenKhuon.keys()];
  const doi = [];
  let thuocNha = 0;
  let khongCoBanCungTen = 0;
  if (idKhuon.length) {
    for (const { bang, khoa, coNha } of BANG_THAM_CHIEU) {
      const rows = await db[bang].findMany({ where: { idcategory: { in: idKhuon } } });
      for (const r of rows) {
        if (coNha && r.idhousehold !== null && r.idhousehold !== undefined) { thuocNha++; continue; }
        const dich = banRiengTheoTen.get(r.idaccount)?.get(tenKhuon.get(r.idcategory));
        if (!dich) { khongCoBanCungTen++; continue; }
        doi.push({ bang, khoa, id: r[khoa], dich });
      }
    }
  }

  const report = {
    apply,
    taiKhoanCanBu: banSao.size,
    banRiengSeTao: [...banSao.values()].reduce((n, c) => n + c.length, 0),
    thamChieuSeDoi: doi.length,
    thamChieuKhongDoi: thuocNha + khongCoBanCungTen,
    chiTietKhongDoi: { thuocNha, khongCoBanCungTen },
    taiKhoanDaBu: 0,
    thamChieuDaDoi: 0,
  };
  if (!apply) return report;

  for (const copies of banSao.values()) {
    await db.$transaction((tx) => tx.category.createMany({ data: copies }));
    report.taiKhoanDaBu++;
  }
  for (const d of doi) {
    await db[d.bang].update({ where: { [d.khoa]: d.id }, data: { idcategory: d.dich, server_update_at: new Date() } });
    report.thamChieuDaDoi++;
  }
  return report;
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const xacNhan = (args.find((a) => a.startsWith('--xac-nhan=')) || '').split('=')[1];
  const { prisma } = require('../config/db');
  try {
    const [{ current_database: tenCsdl }] = await prisma.$queryRaw`SELECT current_database()`;
    console.log(`CSDL đích: ${tenCsdl} — chế độ: ${apply ? 'GHI THẬT' : 'chạy thử'}`);
    if (apply && xacNhan !== tenCsdl) {
      console.error(`Dừng: --apply cần --xac-nhan=${tenCsdl} (khớp tên CSDL đích).`);
      process.exitCode = 1;
      return;
    }
    console.log(JSON.stringify(await buDanhMucCaNhan(prisma, { apply }), null, 2));
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((e) => { console.error(e.message); process.exitCode = 1; });
}

module.exports = { buDanhMucCaNhan };
