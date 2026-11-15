/**
 * Biểu đồ "Đăng nhập" ở dashboard phải đếm được lượt đăng nhập thật.
 * Middleware audit-log ghi mỗi lượt gọi đăng nhập với Request = "POST /api/auth/login",
 * Action = "Đăng nhập hệ thống" (middleware/audit-log.middleware.js, auth.service.formatActionName).
 * Lỗi cũ: truy vấn lọc Request chứa "Đăng nhập" nên không bao giờ khớp, biểu đồ luôn 0.
 * Quyết định: đếm MỌI lượt thử (Pass, Fail, Rejected, Interrupted) để thấy được dò mật khẩu.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const { prisma } = require('../../config/db');
const adminRepository = require('../../modules/admin/admin.repository');

// Đánh giá điều kiện `where` của Prisma trên một dòng (đủ cho các dạng repository dùng)
function matchField(value, cond) {
  if (cond === undefined) return true;
  if (typeof cond !== 'object' || cond === null || cond instanceof Date) return value === cond;
  if ('equals' in cond && value !== cond.equals) return false;
  if ('contains' in cond && !String(value).includes(cond.contains)) return false;
  if ('startsWith' in cond && !String(value).startsWith(cond.startsWith)) return false;
  if ('in' in cond && !cond.in.includes(value)) return false;
  if ('gte' in cond && !(value >= cond.gte)) return false;
  if ('lte' in cond && !(value <= cond.lte)) return false;
  return true;
}
const matches = (row, where) => Object.entries(where).every(([k, c]) => matchField(row[k], c));

describe('adminRepository.getLoginLogsByRange', () => {
  const t = (s) => new Date(s);
  // Các dòng đúng định dạng middleware audit-log ghi ra
  const ROWS = [
    { idlog: 1, request: 'POST /api/auth/login', action: 'Đăng nhập hệ thống', req_status: 'Pass', time_req: t('2026-11-15T03:00:00Z') },
    { idlog: 2, request: 'POST /api/auth/login', action: 'Đăng nhập hệ thống', req_status: 'Rejected', time_req: t('2026-11-15T03:01:00Z') },
    { idlog: 3, request: 'POST /api/auth/login', action: 'Đăng nhập hệ thống', req_status: 'Interrupted', time_req: t('2026-11-15T03:02:00Z') },
    { idlog: 4, request: 'POST /api/auth/logout', action: 'Đăng xuất', req_status: 'Pass', time_req: t('2026-11-15T03:03:00Z') },
    { idlog: 5, request: 'POST /api/auth/refresh', action: 'Làm mới phiên đăng nhập', req_status: 'Pass', time_req: t('2026-11-15T03:04:00Z') },
    { idlog: 6, request: 'GET /api/auth/profile', action: 'Xem thông tin cá nhân', req_status: 'Pass', time_req: t('2026-11-15T03:05:00Z') },
    { idlog: 7, request: 'POST /api/auth/login', action: 'Đăng nhập hệ thống', req_status: 'Pass', time_req: t('2026-11-14T03:00:00Z') },
  ];
  let saved;

  beforeEach(() => {
    saved = prisma.auditlog.findMany;
    prisma.auditlog.findMany = async ({ where }) => ROWS.filter((r) => matches(r, where));
  });
  afterEach(() => { prisma.auditlog.findMany = saved; });

  it('đếm mọi lượt gọi đăng nhập trong khoảng (thành công, bị từ chối, bị ngắt)', async () => {
    const rows = await adminRepository.getLoginLogsByRange(t('2026-11-15T00:00:00Z'), t('2026-11-15T23:59:59Z'));
    assert.deepStrictEqual(rows.map((r) => r.idlog).sort(), [1, 2, 3]);
  });

  it('không đếm đăng xuất, làm mới phiên, xem hồ sơ, và lượt ngoài khoảng thời gian', async () => {
    const rows = await adminRepository.getLoginLogsByRange(t('2026-11-15T00:00:00Z'), t('2026-11-15T23:59:59Z'));
    const ids = rows.map((r) => r.idlog);
    for (const excluded of [4, 5, 6, 7]) assert.ok(!ids.includes(excluded), `không được đếm dòng ${excluded}`);
  });
});
