/**
 * Crypto Utility (Nghị định 13/2023/NĐ-CP & PCI-DSS v4.0)
 * Quản trị mã hóa At-Rest AES-256-GCM và hàm băm tra soát Blind Index (HMAC-SHA256)
 */

const crypto = require('crypto');
const path = require('path');
const logger = require('../core/logger');

// Tự động nạp .env nếu chưa được nạp (chống race-condition khi chạy test suite cô lập)
if (!process.env.DATA_ENCRYPTION_KEY) {
  try {
    require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
  } catch (_) {}
}

// Khóa mã hóa 32 bytes (256-bit) lấy từ biến môi trường
const _rawKey = process.env.DATA_ENCRYPTION_KEY;
const _rawBlindSecret = process.env.BLIND_INDEX_SECRET;

// Cảnh báo rõ ràng khi thiếu khoá — không chấp nhận khoá mặc định ở production
const _isProduction = process.env.NODE_ENV === 'production';
if (!_rawKey) {
  if (_isProduction) {
    // Crash sớm: không để dữ liệu production mã hoá bằng khoá hardcoded
    logger.error('[SECURITY] DATA_ENCRYPTION_KEY không được đặt ở môi trường production. Từ chối khởi động.');
    process.exit(1);
  } else {
    logger.warn('[SECURITY] DATA_ENCRYPTION_KEY chưa đặt — dùng khoá mặc định CHỈ cho môi trường dev/test.');
  }
}

if (!_rawBlindSecret) {
  if (_isProduction) {
    // Crash sớm: không để blind index production dùng secret mặc định đoán được
    logger.error('[SECURITY] BLIND_INDEX_SECRET không được đặt ở môi trường production. Từ chối khởi động.');
    process.exit(1);
  } else {
    logger.warn('[SECURITY] BLIND_INDEX_SECRET chưa đặt — dùng secret mặc định CHỈ cho môi trường dev/test.');
  }
}

const RAW_KEY = _rawKey || '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const RAW_BLIND_SECRET = _rawBlindSecret || 'blind-index-default-secret-salt-2026';

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

  // Tránh mã hóa lặp nếu đã là chuỗi mã hóa hợp lệ với khóa hiện tại
  if (isEncrypted(str)) {
    try {
      decrypt(str);
      return str; // Giải mã thành công bằng khóa hiện tại -> thực sự là bản mã hợp lệ
    } catch (_) {
      // Giải mã thất bại -> Đây là chuỗi do người dùng nhập thô (ví dụ "enc:1:2:3")
      // Tiếp tục xuống dưới để mã hóa thành bản mã AES-GCM hợp lệ!
    }
  }

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, ENCRYPTION_KEY, iv);

  let encrypted = cipher.update(str, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');

  return `${PREFIX}${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Giải mã chuỗi AES-256-GCM (Task 52.1: Nhận context chứa tên bảng + khóa chính để ghi log rõ ràng khi lỗi)
 * @param {string|null} cipherText 
 * @param {object|null} [context] { table: string, id: string|number }
 * @returns {string|null}
 */
function decrypt(cipherText, context = null) {
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
      logger.warn('[Crypto] Chuỗi mã hóa sai định dạng:', { str, table: context?.table, recordId: context?.id || context?.recordId });
      const err = new Error('Chuỗi mã hóa không đúng định dạng (DECRYPT_FAILED)');
      err.code = 'DECRYPT_FAILED';
      throw err;
    }

    const [ivHex, authTagHex, encryptedHex] = parts;
    if (ivHex.length !== IV_LENGTH * 2 || authTagHex.length !== 32) {
      const err = new Error('Độ dài IV hoặc AuthTag không hợp lệ (DECRYPT_FAILED)');
      err.code = 'DECRYPT_FAILED';
      throw err;
    }

    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');

    const decipher = crypto.createDecipheriv(ALGORITHM, ENCRYPTION_KEY, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (err) {
    logger.error('[Crypto] Lỗi giải mã AES-256-GCM:', {
      error: err.message,
      table: context?.table || undefined,
      recordId: context?.id || context?.recordId || undefined,
    });
    const decryptErr = new Error('Lỗi giải mã dữ liệu an ninh (DECRYPT_FAILED)');
    decryptErr.code = 'DECRYPT_FAILED';
    decryptErr.originalMessage = err.message;
    decryptErr.table = context?.table || null;
    decryptErr.recordId = context?.id || context?.recordId || null;
    throw decryptErr;
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
