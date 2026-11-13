/**
 * Device History Service
 * Ghi nhận Tên thiết bị và Địa chỉ IP mỗi lần người dùng đăng nhập hoặc truy cập app.
 * - IP và thiết bị KHÔNG đổi -> UPDATE last_active_at.
 * - IP (đầy đủ) hoặc thiết bị đổi -> INSERT dòng mới, không ghi đè, giữ dấu vết.
 * Bảo vệ IP (Data_Security.md mục 10.8): IP lấy từ req.ip (trust proxy), lưu ba dạng
 * bản che (hiển thị), bản mã AES-256-GCM (chỉ giải khi admin xác thực PIN) và chỉ mục mù HMAC (so khớp, tra cứu).
 * Bản mã và chỉ mục mù bị xóa khi quá hạn IP_RETENTION_DAYS; bản che giữ cùng dòng lịch sử.
 */

const { prisma } = require('../../config/db');
const { getClientIp, protectIp, revealIp } = require('../../utils/ip-protection.util');
const logger = require('../../core/logger');

const accessCache = new Map();
const THROTTLE_MS = 60 * 1000;

function extractClientInfo(req, customData = {}) {
  const headers = req?.headers || {};

  let deviceName = customData.deviceName ||
    headers['x-device-name'] ||
    req?.body?.deviceName ||
    headers['user-agent'] ||
    'Unknown Device';
  deviceName = String(deviceName).trim().substring(0, 150) || 'Unknown Device';

  const { masked, encrypted, hash } = protectIp(customData.ipAddress || getClientIp(req));
  const userAgent = customData.userAgent || headers['user-agent'] || null;

  return { deviceName, maskedIp: masked || 'xx.xx.xx.xx', ipEncrypted: encrypted, ipHash: hash, userAgent };
}

async function trackDeviceAccess(idaccount, req = {}, customData = {}, options = {}) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return null;

  const { deviceName, maskedIp, ipEncrypted, ipHash, userAgent } = extractClientInfo(req, customData);
  const cacheKey = `${numId}:${deviceName}:${ipHash || maskedIp}`;
  const now = Date.now();

  if (!options.skipThrottle) {
    const cached = accessCache.get(cacheKey);
    if (cached && now - cached.timestamp < THROTTLE_MS) {
      return { action: 'THROTTLED', record: cached.record, skipped: true };
    }
  }

  try {
    const latestRecord = await prisma.account_device_history.findFirst({
      where: { idaccount: numId },
      orderBy: { last_active_at: 'desc' },
    });

    const isSameDevice = latestRecord && latestRecord.device_name === deviceName;
    const isSameIp = latestRecord && (latestRecord.ip_hash && ipHash
      ? latestRecord.ip_hash === ipHash
      : latestRecord.ip_address === maskedIp);

    if (latestRecord && isSameDevice && isSameIp) {
      const data = { last_active_at: new Date(), user_agent: userAgent || latestRecord.user_agent };
      if (!latestRecord.ip_encrypted && ipEncrypted) {
        data.ip_encrypted = ipEncrypted;
        data.ip_hash = ipHash;
      }
      const updated = await prisma.account_device_history.update({ where: { id: latestRecord.id }, data });
      accessCache.set(cacheKey, { timestamp: now, record: updated });
      return { action: 'UPDATED', record: updated };
    }

    const created = await prisma.account_device_history.create({
      data: {
        idaccount: numId,
        device_name: deviceName,
        ip_address: maskedIp,
        ip_encrypted: ipEncrypted,
        ip_hash: ipHash,
        user_agent: userAgent,
        first_seen_at: new Date(),
        last_active_at: new Date(),
      },
    });
    accessCache.set(cacheKey, { timestamp: now, record: created });
    return { action: 'INSERTED', record: created };
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

async function getDeviceHistory(idaccount, limit = 20) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return [];

  return prisma.account_device_history.findMany({
    where: { idaccount: numId },
    orderBy: { last_active_at: 'desc' },
    take: limit,
  });
}

async function listDevicesForAdmin(idaccount, limit = 10) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return [];

  const rows = await prisma.account_device_history.findMany({
    where: { idaccount: numId },
    orderBy: { last_active_at: 'desc' },
    take: limit,
    select: {
      id: true,
      device_name: true,
      ip_address: true,
      ip_encrypted: true,
      user_agent: true,
      first_seen_at: true,
      last_active_at: true,
    },
  });
  return rows.map((r) => ({
    id: String(r.id),
    device_name: r.device_name,
    ip_address: r.ip_address,
    user_agent: r.user_agent || null,
    first_seen_at: r.first_seen_at,
    last_active_at: r.last_active_at,
    canRevealIp: Boolean(r.ip_encrypted),
  }));
}

async function revealDeviceIp(idaccount, deviceId) {
  const numId = Number(idaccount);
  if (!numId || isNaN(numId)) return null;
  let id;
  try {
    id = BigInt(deviceId);
  } catch (_) {
    return null;
  }
  const record = await prisma.account_device_history.findFirst({
    where: { id, idaccount: numId },
    orderBy: { last_active_at: 'desc' },
  });
  return record ? revealIp(record.ip_encrypted) : null;
}

async function purgeExpiredIpData(retentionDays) {
  const cutoff = new Date(Date.now() - Number(retentionDays) * 86400000);
  const result = await prisma.account_device_history.updateMany({
    where: { last_active_at: { lt: cutoff }, ip_encrypted: { not: null } },
    data: { ip_encrypted: null, ip_hash: null },
  });
  return result?.count || 0;
}

function clearCache() {
  accessCache.clear();
}

module.exports = {
  extractClientInfo,
  trackDeviceAccess,
  getDeviceHistory,
  listDevicesForAdmin,
  revealDeviceIp,
  purgeExpiredIpData,
  clearCache,
  THROTTLE_MS,
};
