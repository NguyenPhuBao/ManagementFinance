/**
 * Tài khoản quản trị gốc (Chủ dự án chốt 2026-11-16).
 *
 * - Nhận diện bằng email cố định ROOT_ADMIN_EMAIL, trùng email viết trong trigger CSDL
 *   fn_protect_root_admin trong database/FlowMoney_Schema.sql (không thêm cột vào bảng account). Đổi email phải có migration mới.
 * - Đăng nhập hai bước: mật khẩu (băm trong CSDL) + khoá thứ hai ROOT_ADMIN_SECOND_KEY (biến môi trường).
 *   Thiếu biến thì tài khoản gốc không đăng nhập được.
 * - Token của tài khoản gốc mang `root: true` và `rkf` (vân tay khoá = HMAC của khoá thứ hai bằng bí mật JWT).
 *   Đổi khoá trong biến môi trường thì mọi phiên cũ bị từ chối.
 * - Giữ an toàn tài khoản này là trách nhiệm của admin đứng đầu nắm giữ nó.
 */
const crypto = require('crypto');
const config = require('../../config');

const ROOT_ADMIN_EMAIL = 'admin@wealthcommand.com';

const isRootEmail = (email) => String(email || '').trim().toLowerCase() === ROOT_ADMIN_EMAIL;
const isRootAccount = (account) => Boolean(account) && isRootEmail(account.email);

const secondKey = () => String(process.env.ROOT_ADMIN_SECOND_KEY || '').trim();
const rootUsername = () => String(process.env.ROOT_ADMIN_USERNAME || '').trim().toLowerCase();

const keyFingerprint = () => {
  const key = secondKey();
  if (!key) return null;
  return crypto.createHmac('sha256', String(config.jwt.accessSecret)).update(key).digest('hex').slice(0, 16);
};

const sha256 = (v) => crypto.createHash('sha256').update(String(v)).digest();

const rootError = (statusCode, code, message) => Object.assign(new Error(message), { statusCode, code });

/** Bước 2 khi đăng nhập tài khoản gốc. Ném lỗi khi thiếu cấu hình, thiếu khoá hoặc sai khoá. */
function assertSecondFactor(rootKey) {
  const key = secondKey();
  if (!key) throw rootError(403, 'ROOT_KEY_NOT_CONFIGURED', 'Máy chủ chưa cấu hình khoá quản trị gốc, tài khoản này tạm thời không đăng nhập được');
  if (!rootKey || !String(rootKey).trim()) throw rootError(401, 'ROOT_KEY_REQUIRED', 'Cần nhập khoá quản trị gốc');
  if (!crypto.timingSafeEqual(sha256(String(rootKey).trim()), sha256(key))) {
    throw rootError(401, 'ROOT_KEY_INVALID', 'Khoá quản trị gốc không đúng');
  }
}

const rootClaims = () => ({ root: true, rkf: keyFingerprint() });

/** Phiên thường luôn hợp lệ ở bước này; phiên tài khoản gốc phải mang vân tay của khoá hiện tại. */
function isRootSessionValid(decoded) {
  if (!decoded || decoded.root !== true) return true;
  const current = keyFingerprint();
  return Boolean(current) && decoded.rkf === current;
}

const revokedError = () => rootError(401, 'ROOT_SESSION_REVOKED', 'Phiên của tài khoản quản trị gốc đã hết hiệu lực, vui lòng đăng nhập lại');

/** Request đăng nhập bằng tên tài khoản gốc (để đi qua lớp chặn IP; vẫn phải qua hai bước xác thực). */
function isRootLoginRequest(req) {
  const name = rootUsername();
  if (!name || String(req?.method || '').toUpperCase() !== 'POST') return false;
  const url = String(req.originalUrl || req.url || req.path || '').split('?')[0];
  if (!url.endsWith('/auth/login')) return false;
  return String(req.body?.username || '').trim().toLowerCase() === name;
}

/** Request mang access token hợp lệ của tài khoản gốc (chữ ký đúng và vân tay khoá còn hiệu lực). */
function isRootTokenRequest(req) {
  const header = req?.headers?.authorization || '';
  if (!header.startsWith('Bearer ')) return false;
  try {
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(header.slice(7).trim(), config.jwt.accessSecret);
    return decoded.root === true && isRootSessionValid(decoded);
  } catch (_) {
    return false;
  }
}

module.exports = {
  ROOT_ADMIN_EMAIL,
  isRootEmail,
  isRootAccount,
  keyFingerprint,
  assertSecondFactor,
  rootClaims,
  isRootSessionValid,
  revokedError,
  isRootLoginRequest,
  isRootTokenRequest,
};
