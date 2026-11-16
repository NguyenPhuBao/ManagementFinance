/**
 * Cài đặt cá nhân của từng tài khoản quản trị (bảng admin_preference, migration 55, 2026-11-16).
 * Mỗi tài khoản một bộ, đăng nhập ở máy nào cũng dùng đúng bộ của mình. Chỉ nhận đúng các khoá và giá trị dưới đây;
 * giá trị mặc định khớp DEFAULT_SETTINGS của Admin-web (store/settings.context.jsx).
 */
const { prisma } = require('../../config/db');

const RULES = {
  theme: ['light', 'dark'],
  tableDensity: ['comfortable', 'compact'],
  soundEnabled: 'boolean',
  toastDuration: [3000, 4500, 7000, 10000],
  showUnreadBadge: 'boolean',
  metricsInterval: [1, 3, 5, 10],
  autoLockMinutes: [0, 15, 30, 60],
};

const DEFAULTS = Object.freeze({
  theme: 'light',
  tableDensity: 'comfortable',
  soundEnabled: true,
  toastDuration: 4500,
  showUnreadBadge: true,
  metricsInterval: 3,
  autoLockMinutes: 30,
});

const badRequest = (message) => Object.assign(new Error(message), { statusCode: 400 });

const isValid = (key, value) => {
  const rule = RULES[key];
  return rule === 'boolean' ? typeof value === 'boolean' : rule.includes(value);
};

/** Chỉ giữ khoá hợp lệ với giá trị hợp lệ (dữ liệu cũ trong CSDL có thể lệch luật mới). */
const clean = (stored) =>
  Object.fromEntries(Object.entries(stored && typeof stored === 'object' ? stored : {}).filter(([k, v]) => k in RULES && isValid(k, v)));

function validate(partial) {
  if (!partial || typeof partial !== 'object' || Array.isArray(partial)) throw badRequest('Cài đặt phải là một đối tượng');
  const keys = Object.keys(partial);
  if (keys.length === 0) throw badRequest('Không có cài đặt nào để lưu');
  for (const key of keys) {
    if (!(key in RULES)) throw badRequest(`Cài đặt không hợp lệ: ${key}`);
    if (!isValid(key, partial[key])) throw badRequest(`Giá trị không hợp lệ cho ${key}`);
  }
  return partial;
}

async function get(idaccount) {
  const row = await prisma.admin_preference.findUnique({ where: { idaccount } });
  return { settings: { ...DEFAULTS, ...clean(row?.settings) }, saved: Boolean(row) };
}

async function update(idaccount, partial) {
  validate(partial);
  const row = await prisma.admin_preference.findUnique({ where: { idaccount } });
  const settings = { ...clean(row?.settings), ...partial };
  await prisma.admin_preference.upsert({
    where: { idaccount },
    create: { idaccount, settings },
    update: { settings, updated_at: new Date() },
  });
  return { settings: { ...DEFAULTS, ...settings }, saved: true };
}

module.exports = { DEFAULTS, validate, get, update };
