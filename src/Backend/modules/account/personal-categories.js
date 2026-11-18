/**
 * Bản danh mục riêng của một tài khoản, chép từ bộ danh mục mặc định (khuôn) đang hoạt động.
 *
 * Nghiệp vụ (Chủ dự án chốt 2026-11-17): mọi tài khoản tạo mới (người dùng đăng ký, quản trị do Admin tạo) nhận một bản
 * riêng ngay lúc tạo, trong cùng giao tác. Admin sửa khuôn về sau chỉ ảnh hưởng tài khoản tạo sau đó.
 * Kế hoạch: docs/superpowers/plans/2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md (B1, B2, B6).
 */
const { randomUUID } = require('crypto');

/** Chuẩn hoá tên giống chỉ mục `uq_category_owner_name`: NFC, trim, gộp khoảng trắng, chữ thường. */
function normalizeName(name) {
  return String(name || '').normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();
}

function isLiveTemplate(t) {
  return t.is_default === true && !t.delete_at && !t.is_group && (t.idhousehold === null || t.idhousehold === undefined);
}

/**
 * Hàm thuần: từ danh sách khuôn dựng các hàng danh mục riêng cho [idaccount].
 * Khuôn trùng tên chuẩn hoá (kể cả khác loại) chỉ sinh một bản, giữ khuôn tạo sớm nhất, vì chỉ mục khoá theo tên.
 */
function buildPersonalCopies(templates, idaccount) {
  const live = templates.filter(isLiveTemplate)
    .sort((a, b) => new Date(a.create_at || 0) - new Date(b.create_at || 0));
  const seen = new Set();
  const now = new Date();
  const copies = [];
  for (const t of live) {
    const key = normalizeName(t.name_category);
    if (seen.has(key)) continue;
    seen.add(key);
    copies.push({
      idcategory: randomUUID(),
      create_by: Number(idaccount),
      name_category: t.name_category,
      classify: t.classify,
      is_default: false,
      is_group: false,
      idgroup: null,
      idhousehold: null,
      keyword: t.keyword ?? null,
      icon: t.icon ?? null,
      color: t.color ?? null,
      create_at: now,
      update_at: now,
      server_update_at: now,
    });
  }
  return copies;
}

/** Đọc khuôn đang hoạt động bằng [tx] (giao tác của nơi gọi) và ghi bản riêng cho [idaccount]. Trả số bản đã tạo. */
async function seedPersonalCategories(tx, idaccount) {
  const templates = await tx.category.findMany({
    where: { is_default: true, delete_at: null, is_group: false, idhousehold: null },
    select: {
      name_category: true, classify: true, keyword: true, icon: true, color: true,
      is_default: true, is_group: true, idhousehold: true, delete_at: true, create_at: true,
    },
    orderBy: { create_at: 'asc' },
  });
  const copies = buildPersonalCopies(templates, idaccount);
  if (copies.length === 0) return 0;
  await tx.category.createMany({ data: copies });
  return copies.length;
}

module.exports = { normalizeName, buildPersonalCopies, seedPersonalCategories };
