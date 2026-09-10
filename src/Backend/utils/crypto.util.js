/**
 * Crypto Utility (Nghị định 13/2023/NĐ-CP & PCI-DSS v4.0)
 * Quản trị mã hóa At-Rest AES-256-GCM và hàm băm tra soát Blind Index (HMAC-SHA256)
 */

const crypto = require('crypto');
const logger = require('../core/logger');

// Khóa mã hóa 32 bytes (256-bit) lấy từ biến môi trường
const RAW_KEY = process.env.DATA_ENCRYPTION_KEY || '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const RAW_BLIND_SECRET = process.env.BLIND_INDEX_SECRET || 'blind-index-default-secret-salt-2026';

let ENCRYPTION_KEY;
try {
  ENCRYPTION_KEY = Buffer.from(RAW_KEY, 'hex');
  if (ENCRYPTION_KEY.length !== 32) {
    // Fallback sha256 nếu chuỗi key chưa đủ chuẩn 32 bytes hex
    ENCRYPTION_KEY = crypto.createHash('sha256').update(RAW_KEY).digest();
  }
} catch {
  ENCRYPTION_KEY = crypto.createHash('sha256').update(RAW_KEY).digest();
}

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // NIST khuyến nghị 12 bytes cho GCM
const PREFIX = 'enc:';

/**
 * Mã hóa chuỗi bản rõ bằng AES-256-GCM
 * Định dạng lưu trữ: enc:<iv_hex>:<authTag_hex>:<ciphertext_hex>
 * @param {string|null} text 
 * @returns {string|null}
 */
function encrypt(text) {
  if (text === null || text === undefined) return null;
  const str = String(text);
  if (str === '') return '';

  // Tránh mã hóa lặp nếu đã là chuỗi mã hóa
  if (isEncrypted(str)) {
    return str;
  }

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, ENCRYPTION_KEY, iv);

  let encrypted = cipher.update(str, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');

  return `${PREFIX}${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Giải mã chuỗi AES-256-GCM
 * @param {string|null} cipherText 
 * @returns {string|null}
 */
function decrypt(cipherText) {
  if (cipherText === null || cipherText === undefined) return null;
  const str = String(cipherText);
  if (str === '') return '';

  if (!isEncrypted(str)) {
    // Nếu chưa mã hóa (dữ liệu cũ legacy) -> trả về trực tiếp
    return str;
  }

  try {
    const parts = str.slice(PREFIX.length).split(':');
    if (parts.length !== 3) {
      logger.warn('[Crypto] Chuỗi mã hóa sai định dạng:', str);
      return str;
    }

    const [ivHex, authTagHex, encryptedHex] = parts;
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');

    const decipher = crypto.createDecipheriv(ALGORITHM, ENCRYPTION_KEY, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (err) {
    logger.error('[Crypto] Lỗi giải mã AES-256-GCM:', { error: err.message });
    return str;
  }
}

/**
 * Kiểm tra xem chuỗi có phải đã được mã hóa theo chuẩn của hệ thống hay không
 * @param {string} text 
 * @returns {boolean}
 */
function isEncrypted(text) {
  if (!text || typeof text !== 'string') return false;
  return text.startsWith(PREFIX) && text.split(':').length === 4;
}

/**
 * Tính toán mã băm Blind Index một chiều (HMAC-SHA256)
 * Phục vụ tìm kiếm chính xác O(1) cho số tài khoản ngân hàng hoặc SĐT
 * @param {string|null} value 
 * @returns {string|null}
 */
function hashBlindIndex(value) {
  if (value === null || value === undefined) return null;
  const cleaned = String(value).trim().replace(/[\s-]/g, '');
  if (cleaned === '') return null;

  return crypto
    .createHmac('sha256', RAW_BLIND_SECRET)
    .update(cleaned)
    .digest('hex');
}

module.exports = {
  encrypt,
  decrypt,
  isEncrypted,
  hashBlindIndex,
};
