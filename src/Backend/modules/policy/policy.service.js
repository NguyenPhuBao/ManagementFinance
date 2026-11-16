/**
 * Chính sách và bằng chứng người dùng đồng ý (Nghị định 356/2025 Điều 6).
 *
 * Mô hình (migration 54): nhiều chính sách song song (policy_document); mỗi chính sách có nhiều phiên bản (privacy_policy,
 * `doc_version`), tối đa MỘT phiên bản ACTIVE. `version` là mã nội bộ của một phiên bản — app gửi lại mã này khi đồng ý.
 * Người dùng phải đồng ý mọi phiên bản đang sử dụng; không có rút đồng ý.
 * Chưa chặn người dùng chưa đồng ý (Client-app sẽ bắt buộc ở phiên bản sau).
 */
const { prisma } = require('../../config/db');
const { getClientIp, protectIp } = require('../../utils/ip-protection.util');
const logger = require('../../core/logger');

const STATUSES = ['ACTIVE', 'INACTIVE'];
const httpError = (message, statusCode, code) => Object.assign(new Error(message), { statusCode, code });

const toPublic = (p) =>
  p
    ? {
        version: p.version,
        policyId: p.document_id,
        docVersion: p.doc_version,
        title: p.document?.title || p.title,
        content: p.content,
        status: p.status,
        publishedAt: p.published_at,
      }
    : null;

const label = (p) => `"${p.document?.title || p.title}" v${p.doc_version}`;

async function getActivePolicies() {
  return prisma.privacy_policy.findMany({ where: { status: 'ACTIVE' }, include: { document: true }, orderBy: { document_id: 'asc' } });
}

/**
 * `policies`: mọi chính sách đang dùng kèm cờ `accepted`. `policy` (giữ cho tương thích): chính sách đang dùng đầu tiên mà
 * người dùng chưa đồng ý, hoặc bản đang dùng mới nhất nếu đã đồng ý hết. `mustAccept`: còn chính sách đang dùng chưa đồng ý.
 */
async function getStatus(idaccount) {
  const active = await getActivePolicies();
  const ids = active.map((p) => p.version);
  const [accepted, latest] = await Promise.all([
    ids.length ? prisma.policy_acceptance.findMany({ where: { idaccount, policy_version: { in: ids } } }) : [],
    prisma.policy_acceptance.findFirst({ where: { idaccount }, orderBy: { policy_version: 'desc' } }),
  ]);
  const acceptedAt = new Map(accepted.map((a) => [a.policy_version, a.accepted_at]));
  const policies = active.map((p) => ({ ...toPublic(p), accepted: acceptedAt.has(p.version), acceptedAt: acceptedAt.get(p.version) || null }));
  const pending = active.filter((p) => !acceptedAt.has(p.version));
  const shown = pending[0] || [...active].sort((x, y) => y.version - x.version)[0] || null;
  return {
    policy: toPublic(shown),
    policies,
    acceptedVersion: latest ? latest.policy_version : null,
    acceptedAt: latest ? latest.accepted_at : null,
    mustAccept: pending.length > 0,
  };
}

async function accept(idaccount, version, req = {}) {
  const v = Number(version);
  if (!Number.isInteger(v) || v <= 0) throw httpError('Thiếu phiên bản chính sách hợp lệ', 400, 'POLICY_VERSION_REQUIRED');
  const policy = await prisma.privacy_policy.findUnique({ where: { version: v } });
  if (!policy || policy.status !== 'ACTIVE') {
    const anyActive = await prisma.privacy_policy.findFirst({ where: { status: 'ACTIVE' } });
    if (!anyActive) throw httpError('Chưa có chính sách nào đang sử dụng', 404, 'POLICY_NOT_FOUND');
    throw httpError('Chính sách này đã ngừng sử dụng. Vui lòng tải lại các chính sách hiện hành.', 409, 'POLICY_VERSION_OUTDATED');
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
  logger.info('Người dùng đồng ý chính sách', { idaccount, version: v });
  return { created: true, acceptance };
}

/**
 * Kiểm dữ liệu trước khi hỏi PIN. `documentId` = thêm phiên bản cho chính sách có sẵn; không có thì `title` là chính sách mới.
 */
async function publish({ documentId, title, content }, publishedBy) {
  const hasDoc = documentId !== undefined && documentId !== null && documentId !== '';
  const docId = hasDoc ? Number(documentId) : null;
  if (hasDoc && (!Number.isInteger(docId) || docId <= 0)) throw httpError('Chính sách đã chọn không hợp lệ', 400, 'POLICY_DOCUMENT_INVALID');
  const cleanTitle = String(title || '').trim();
  const cleanContent = String(content || '').trim();
  if (!hasDoc && (!cleanTitle || cleanTitle.length > 200)) throw httpError('Tiêu đề chính sách bắt buộc, tối đa 200 ký tự', 400, 'POLICY_TITLE_INVALID');
  if (!cleanContent) throw httpError('Nội dung chính sách bắt buộc', 400, 'POLICY_CONTENT_INVALID');
  return { documentId: docId, title: cleanTitle, content: cleanContent, publishedBy };
}

/** Tạo phiên bản mới ở trạng thái INACTIVE (admin kích hoạt sau, có PIN). Không phát sự kiện: người dùng chưa bị ảnh hưởng. */
async function createVersion({ documentId, title, content, publishedBy }) {
  let doc;
  if (documentId) {
    doc = await prisma.policy_document.findUnique({ where: { id: documentId } });
    if (!doc) throw httpError('Không tìm thấy chính sách đã chọn', 404, 'POLICY_DOCUMENT_NOT_FOUND');
  } else {
    if (await prisma.policy_document.findUnique({ where: { title } })) {
      throw httpError(`Chính sách "${title}" đã có. Hãy chọn chính sách này trong danh sách để thêm phiên bản mới.`, 409, 'POLICY_TITLE_EXISTS');
    }
    doc = await prisma.policy_document.create({ data: { title, created_by: publishedBy || null } });
  }
  const [lastGlobal, lastOfDoc] = await Promise.all([
    prisma.privacy_policy.findFirst({ orderBy: { version: 'desc' } }),
    prisma.privacy_policy.findFirst({ where: { document_id: doc.id }, orderBy: { doc_version: 'desc' } }),
  ]);
  try {
    return await prisma.privacy_policy.create({
      data: {
        version: (lastGlobal ? lastGlobal.version : 0) + 1,
        document_id: doc.id,
        doc_version: (lastOfDoc ? lastOfDoc.doc_version : 0) + 1,
        title: doc.title,
        content,
        status: 'INACTIVE',
        published_by: publishedBy || null,
      },
      include: { document: true },
    });
  } catch (error) {
    if (error.code === 'P2002') throw httpError('Có người vừa thêm phiên bản cùng lúc. Vui lòng thử lại.', 409, 'POLICY_VERSION_CONFLICT');
    throw error;
  }
}

function assertStatus(status) {
  if (!STATUSES.includes(status)) throw httpError('Trạng thái chính sách không hợp lệ', 400, 'POLICY_STATUS_INVALID');
}

/** Ngừng / kích hoạt một phiên bản. Kích hoạt bị chặn khi chính sách đó đang có phiên bản khác đang sử dụng. */
async function setStatus({ version, status, actorId }) {
  assertStatus(status);
  const policy = await prisma.privacy_policy.findUnique({ where: { version }, include: { document: true } });
  if (!policy) throw httpError('Không tìm thấy phiên bản chính sách', 404, 'POLICY_NOT_FOUND');
  if (policy.status === status) return policy;
  const conflict = () => httpError('', 409, 'POLICY_ALREADY_ACTIVE');
  if (status === 'ACTIVE') {
    const other = await prisma.privacy_policy.findFirst({ where: { document_id: policy.document_id, status: 'ACTIVE' } });
    if (other) {
      const e = conflict();
      e.message = `Chính sách "${policy.document?.title || policy.title}" đang dùng phiên bản v${other.doc_version}. Hãy ngừng phiên bản đó trước khi kích hoạt v${policy.doc_version}.`;
      throw e;
    }
  }
  let updated;
  try {
    updated = await prisma.privacy_policy.update({
      where: { version },
      data: { status, status_changed_at: new Date(), status_changed_by: actorId || null },
      include: { document: true },
    });
  } catch (error) {
    // Index uq_privacy_policy_one_active: hai admin kích hoạt cùng lúc
    if (error.code === 'P2002') {
      const e = conflict();
      e.message = `Chính sách "${policy.document?.title || policy.title}" vừa có phiên bản khác được kích hoạt. Vui lòng tải lại.`;
      throw e;
    }
    throw error;
  }
  try {
    const { getIO } = require('../../core/socket');
    const io = getIO();
    if (io) io.emit('system.policy_updated', { version: updated.version, title: updated.document?.title || updated.title, status: updated.status });
  } catch (_) {}
  return updated;
}

async function listForAdmin() {
  const [rows, documents, activeUsers] = await Promise.all([
    prisma.privacy_policy.findMany({
      include: { document: true, _count: { select: { acceptances: true } } },
      orderBy: [{ document_id: 'asc' }, { doc_version: 'desc' }],
    }),
    prisma.policy_document.findMany({ orderBy: { title: 'asc' } }),
    prisma.account.count({ where: { idrole: 2, status: 'Active' } }),
  ]);
  return {
    policies: rows.map((p) => ({
      ...toPublic(p),
      publishedBy: p.published_by,
      statusChangedAt: p.status_changed_at || null,
      acceptedCount: p._count?.acceptances || 0,
    })),
    documents: documents.map((d) => ({ id: d.id, title: d.title })),
    activeUsers,
  };
}

async function acceptancesForAccount(idaccount) {
  const [rows, active] = await Promise.all([
    prisma.policy_acceptance.findMany({
      where: { idaccount },
      orderBy: { policy_version: 'desc' },
      include: { policy: { include: { document: true } } },
    }),
    getActivePolicies(),
  ]);
  return {
    // Giữ cho tương thích: mã nội bộ của bản đang dùng mới nhất
    currentVersion: active.length ? Math.max(...active.map((p) => p.version)) : null,
    activePolicies: active.map((p) => {
      const { content, ...rest } = toPublic(p);
      return rest;
    }),
    acceptances: rows.map((a) => ({
      policy_version: a.policy_version,
      title: a.policy?.document?.title || a.policy?.title || null,
      doc_version: a.policy?.doc_version ?? null,
      accepted_at: a.accepted_at,
      device_name: a.device_name || null,
    })),
  };
}

module.exports = { getActivePolicies, getStatus, accept, publish, createVersion, assertStatus, setStatus, listForAdmin, acceptancesForAccount, label, toPublic };
