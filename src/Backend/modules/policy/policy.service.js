/**
 * Chính sách bảo mật theo phiên bản và bằng chứng người dùng đồng ý (Nghị định 356/2025 Điều 6).
 * Người dùng đồng ý một lần cho mỗi phiên bản; không có rút đồng ý từng mục đích.
 * Chưa chặn người dùng chưa đồng ý (Client-app sẽ bắt buộc ở phiên bản sau).
 */
const { prisma } = require('../../config/db');
const { getClientIp, protectIp } = require('../../utils/ip-protection.util');
const logger = require('../../core/logger');

const httpError = (message, statusCode, code) => Object.assign(new Error(message), { statusCode, code });

const toPublic = (p) => (p ? { version: p.version, title: p.title, content: p.content, publishedAt: p.published_at } : null);

async function getCurrentPolicy() {
  return prisma.privacy_policy.findFirst({ orderBy: { version: 'desc' } });
}

async function getStatus(idaccount) {
  const [policy, accepted] = await Promise.all([
    getCurrentPolicy(),
    prisma.policy_acceptance.findFirst({ where: { idaccount }, orderBy: { policy_version: 'desc' } }),
  ]);
  const acceptedVersion = accepted ? accepted.policy_version : null;
  return {
    policy: toPublic(policy),
    acceptedVersion,
    acceptedAt: accepted ? accepted.accepted_at : null,
    mustAccept: Boolean(policy) && acceptedVersion !== policy.version,
  };
}

async function accept(idaccount, version, req = {}) {
  const v = Number(version);
  if (!Number.isInteger(v) || v <= 0) throw httpError('Thiếu phiên bản chính sách hợp lệ', 400, 'POLICY_VERSION_REQUIRED');
  const policy = await getCurrentPolicy();
  if (!policy) throw httpError('Chưa có chính sách bảo mật nào được đăng', 404, 'POLICY_NOT_FOUND');
  if (v !== policy.version) {
    throw httpError(`Chính sách đã có phiên bản mới (v${policy.version}). Vui lòng đọc và đồng ý phiên bản mới.`, 409, 'POLICY_VERSION_OUTDATED');
  }
  const existing = await prisma.policy_acceptance.findUnique({
    where: { idaccount_policy_version: { idaccount, policy_version: v } },
  });
  if (existing) return { created: false, acceptance: existing };

  const headers = req.headers || {};
  const deviceName = String(headers['x-device-name'] || '').trim().substring(0, 150) || null;
  const acceptance = await prisma.policy_acceptance.create({
    data: {
      idaccount,
      policy_version: v,
      ip_hash: protectIp(getClientIp(req)).hash,
      device_name: deviceName,
      user_agent: headers['user-agent'] || null,
    },
  });
  logger.info('Người dùng đồng ý chính sách bảo mật', { idaccount, version: v });
  return { created: true, acceptance };
}

async function publish({ title, content }, publishedBy) {
  const cleanTitle = String(title || '').trim();
  const cleanContent = String(content || '').trim();
  if (!cleanTitle || cleanTitle.length > 200) throw httpError('Tiêu đề chính sách bắt buộc, tối đa 200 ký tự', 400, 'POLICY_TITLE_INVALID');
  if (!cleanContent) throw httpError('Nội dung chính sách bắt buộc', 400, 'POLICY_CONTENT_INVALID');
  return { title: cleanTitle, content: cleanContent, publishedBy };
}

async function createVersion({ title, content, publishedBy }) {
  const current = await getCurrentPolicy();
  const created = await prisma.privacy_policy.create({
    data: { version: (current ? current.version : 0) + 1, title, content, published_by: publishedBy || null },
  });
  try {
    const { getIO } = require('../../core/socket');
    const io = getIO();
    if (io) io.emit('system.policy_updated', { version: created.version, title: created.title, publishedAt: created.published_at });
  } catch (_) {}
  return created;
}

async function listForAdmin() {
  const [rows, activeUsers] = await Promise.all([
    prisma.privacy_policy.findMany({
      orderBy: { version: 'desc' },
      include: { _count: { select: { acceptances: true } } },
    }),
    prisma.account.count({ where: { idrole: 2, status: 'Active' } }),
  ]);
  return {
    policies: rows.map((p) => ({ ...toPublic(p), publishedBy: p.published_by, acceptedCount: p._count?.acceptances || 0 })),
    activeUsers,
  };
}

async function acceptancesForAccount(idaccount) {
  const [rows, policy] = await Promise.all([
    prisma.policy_acceptance.findMany({
      where: { idaccount },
      orderBy: { policy_version: 'desc' },
      select: { policy_version: true, accepted_at: true, device_name: true },
    }),
    getCurrentPolicy(),
  ]);
  return {
    currentVersion: policy ? policy.version : null,
    acceptances: rows.map((a) => ({ policy_version: a.policy_version, accepted_at: a.accepted_at, device_name: a.device_name || null })),
  };
}

module.exports = { getCurrentPolicy, getStatus, accept, publish, createVersion, listForAdmin, acceptancesForAccount };
