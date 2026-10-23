/**
 * Device History Service
 * Ghi nhận lịch sử Tên thiết bị và Địa chỉ IP mỗi lần người dùng đăng nhập hoặc truy cập app.
 * Quy tắc nghiệp vụ (PO duyệt):
 * - Khi người dùng truy cập app nhưng IP và thiết bị KHÔNG thay đổi -> UPDATE dữ liệu (last_active_at).
 * - Khi IP hoặc Thiết bị thay đổi -> INSERT thêm dòng mới vào CSDL, tuyệt đối không ghi đè, bảo toàn dấu vết.
 * Tuân thủ: Luật An toàn thông tin mạng 2015, Nghị định 13/2023/NĐ-CP (Masked IP), Rule 9 & 10.
 */

const { prisma } = require('../../config/db');
const { maskIp } = require('../../utils/masking.util');
const logger = require('../../core/logger');

// Cache chống dồn request (Throttle Cache) trong vòng 60 giây cho cùng 1 phiên (idaccount:device:ip)
const accessCache = new Map();
const THROTTLE_MS = 60 * 1000; // 60 giây

/**
 * Trích xuất thông tin thiết bị và địa chỉ IP từ request
 * @param {object} req 
 * @param {object} customData 
 * @returns {{ deviceName: string, maskedIp: string, userAgent: string|null }}
 */
function extractClientInfo(req, customData = {}) {
  const headers = req?.headers || {};

  // 1. Tên thiết bị: Ưu tiên x-device-name từ Client-app -> customData -> user-agent -> fallback
  let deviceName = customData.deviceName ||
    headers['x-device-name'] ||
    req?.body?.deviceName ||
    headers['user-agent'] ||
    'Unknown Device';

  deviceName = String(deviceName).trim().substring(0, 150);
  if (!deviceName) deviceName = 'Unknown Device';

  // 2. Địa chỉ IP: Lấy IP thực -> chuyển qua maskIp (Nghị định 13/2023/NĐ-CP)
  const rawIp = customData.ipAddress ||
    headers['x-forwarded-for']?.split(',')[0]?.trim() ||
    req?.ip ||
    req?.socket?.remoteAddress ||
    '127.0.0.1';

  const maskedIp = maskIp(rawIp) || 'xx.xx.xx.xx';

  // 3. User agent
  const userAgent = customData.userAgent || headers['user-agent'] || null;

  return { deviceName, maskedIp, userAgent };
}

/**
 * Ghi nhận hoặc cập nhật lịch sử truy cập thiết bị của người dùng
 * @param {number|string} idaccount 
 * @param {object} req Express request object
 * @param {object} [customData] Dữ liệu tùy biến nếu gọi từ unit test hoặc worker
 * @param {boolean} [options.skipThrottle=false] Bỏ qua bộ lọc throttle (dùng cho Login/Logout/Test)
 * @returns {Promise<{ action: 'UPDATED'|'INSERTED'|'THROTTLED', record: object|null }>}
 */
async function trackDeviceAccess(idaccount, req = {}, customData = {}, options = {}) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return null;

  const { deviceName, maskedIp, userAgent } = extractClientInfo(req, customData);
  const cacheKey = `${numId}:${deviceName}:${maskedIp}`;
  const now = Date.now();

  // Kiểm tra throttle cache: Nếu cùng thiết bị và cùng IP truy cập trong 60s -> bỏ qua để bảo vệ DB
  if (!options.skipThrottle) {
    const cached = accessCache.get(cacheKey);
    if (cached && now - cached.timestamp < THROTTLE_MS) {
      return { action: 'THROTTLED', record: cached.record, skipped: true };
    }
  }

  try {
    // 1. Tìm bản ghi gần nhất của tài khoản này
    const latestRecord = await prisma.account_device_history.findFirst({
      where: { idaccount: numId },
      orderBy: { last_active_at: 'desc' },
    });

    const isSameDevice = latestRecord && latestRecord.device_name === deviceName;
    const isSameIp = latestRecord && latestRecord.ip_address === maskedIp;

    // 2. Phân nhánh theo quy tắc PO:
    if (latestRecord && isSameDevice && isSameIp) {
      // TRƯỜNG HỢP 1: IP và Thiết bị KHÔNG thay đổi -> UPDATE last_active_at
      const updated = await prisma.account_device_history.update({
        where: { id: latestRecord.id },
        data: {
          last_active_at: new Date(),
          user_agent: userAgent || latestRecord.user_agent,
        },
      });

      accessCache.set(cacheKey, { timestamp: now, record: updated });
      return { action: 'UPDATED', record: updated };
    } else {
      // TRƯỜNG HỢP 2: IP hoặc Thiết bị CÓ thay đổi (hoặc chưa có lịch sử) -> INSERT dòng mới
      const created = await prisma.account_device_history.create({
        data: {
          idaccount: numId,
          device_name: deviceName,
          ip_address: maskedIp,
          user_agent: userAgent,
          first_seen_at: new Date(),
          last_active_at: new Date(),
        },
      });

      accessCache.set(cacheKey, { timestamp: now, record: created });
      return { action: 'INSERTED', record: created };
    }
  } catch (error) {
    logger.error('Lỗi khi ghi nhận lịch sử thiết bị (trackDeviceAccess):', {
      idaccount: numId,
      deviceName,
      maskedIp,
      error: error.message,
    });
    return null;
  }
}

/**
 * Lấy lịch sử truy cập thiết bị của tài khoản (dành cho Admin hoặc Người dùng tự xem)
 * @param {number|string} idaccount 
 * @param {number} limit 
 * @returns {Promise<Array>}
 */
async function getDeviceHistory(idaccount, limit = 20) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return [];

  return prisma.account_device_history.findMany({
    where: { idaccount: numId },
    orderBy: { last_active_at: 'desc' },
    take: limit,
  });
}

/**
 * Xóa cache (phục vụ test)
 */
function clearCache() {
  accessCache.clear();
}

module.exports = {
  extractClientInfo,
  trackDeviceAccess,
  getDeviceHistory,
  clearCache,
  THROTTLE_MS,
};
