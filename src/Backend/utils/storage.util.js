/**
 * Storage Utility (Nghị định 13/2023/NĐ-CP & An toàn lưu trữ đám mây)
 * Quản trị Private Bucket & sinh Pre-signed URL có thời hạn ngắn (15 - 30 phút)
 * cho hình ảnh biên lai / chứng từ trong bảng transaction
 */

const crypto = require('crypto');

const STORAGE_SIGNING_SECRET = process.env.STORAGE_SIGNING_SECRET || process.env.JWT_ACCESS_SECRET || 'storage-presigned-signing-key-2026';
const DEFAULT_TTL_SECONDS = 1800; // 30 phút

/**
 * Sinh Pre-signed URL có thời hạn truy cập ngắn cho ảnh chứng từ
 * @param {string|null} imageKey Đường dẫn tệp nội bộ trong Private Bucket (ví dụ: 'receipts/acc_1/tx_abc.jpg')
 * @param {number} [expiresInSeconds=1800] Thời gian sống của link (mặc định 30 phút)
 * @returns {string|null} Pre-signed URL kèm chữ ký số HMAC và thời điểm hết hạn
 */
function getPresignedReceiptUrl(imageKey, expiresInSeconds = DEFAULT_TTL_SECONDS) {
  if (!imageKey || typeof imageKey !== 'string') return null;
  const key = imageKey.trim();
  if (!key) return null;

  // Nếu là chuỗi rỗng hoặc data URI base64 thì giữ nguyên
  if (key.startsWith('data:image')) return key;

  const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const dataToSign = `${key}:${expiresAt}`;
  const signature = crypto
    .createHmac('sha256', STORAGE_SIGNING_SECRET)
    .update(dataToSign)
    .digest('hex');

  // Trả về Pre-signed URL chuẩn hóa an toàn
  const baseUrl = process.env.STORAGE_PRIVATE_BASE_URL || '/api/v1/storage/private';
  return `${baseUrl}/${encodeURIComponent(key)}?expires=${expiresAt}&sig=${signature}`;
}

/**
 * Kiểm tra tính hợp lệ của Pre-signed URL khi truy cập tệp
 * @param {string} key 
 * @param {number} expiresAt 
 * @param {string} signature 
 * @returns {boolean}
 */
function verifyPresignedUrl(key, expiresAt, signature) {
  if (!key || !expiresAt || !signature) return false;
  const now = Math.floor(Date.now() / 1000);
  if (now > Number(expiresAt)) return false; // Đã hết hạn

  const expectedSignature = crypto
    .createHmac('sha256', STORAGE_SIGNING_SECRET)
    .update(`${key}:${expiresAt}`)
    .digest('hex');

  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature));
}

module.exports = {
  getPresignedReceiptUrl,
  verifyPresignedUrl,
  DEFAULT_TTL_SECONDS,
};
