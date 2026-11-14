const { randomUUID } = require('crypto');
const { prisma } = require('../../config/db');
const logger = require('../../core/logger');
const storageMod = require('../../core/storage');
const syncRepository = require('../sync/sync.repository');
const emailService = require('../../core/email.service');
const socket = require('../../core/socket');
const { decrypt, isEncrypted } = require('../../utils/crypto.util');
const { maskEmail } = require('../../utils/masking.util');

const DAY_MS = 24 * 60 * 60 * 1000;
const ACTIVITY_DAYS = 365;
const RATE_LIMIT_MS = DAY_MS;
const FILE_TTL_MS = DAY_MS;

const SCOPE_NOTE =
  'Tệp này gồm dữ liệu cá nhân FlowMoney đang lưu trên máy chủ về bạn. Nhật ký hoạt động chỉ gồm các lượt ứng dụng gọi tới máy chủ trong 12 tháng gần nhất, ' +
  'dùng để bảo đảm hệ thống hoạt động ổn định và đủ khả năng chịu tải. FlowMoney không thu thập hoạt động cá nhân của bạn trong ứng dụng. ' +
  'Không đưa vào tệp: mật khẩu, mã PIN, mã phiên đăng nhập, mã OTP, địa chỉ IP đầy đủ và dữ liệu điều tra an ninh.';

const safeDecrypt = (value, context) => {
  if (!value) return value ?? null;
  if (!isEncrypted(value)) return value;
  try {
    return decrypt(value, context);
  } catch (_) {
    return null;
  }
};

const toJson = (value) =>
  JSON.stringify(value, (_k, v) => (typeof v === 'bigint' ? v.toString() : v), 2);

async function collect(idaccount) {
  const id = Number(idaccount);
  const [account, user, wallets, transactions, budgets, bills, goals, categories, memberships, orders, devices, acceptances, activity] = await Promise.all([
    prisma.account.findUnique({ where: { idaccount: id } }),
    prisma.user.findUnique({ where: { idaccount: id } }),
    syncRepository.getWalletsByAccount(id, null, null),
    syncRepository.getTransactionsByAccount(id, null, null),
    syncRepository.getBudgetsByAccount(id, null, null),
    syncRepository.getBillsByAccount(id, null),
    syncRepository.getGoalsByAccount(id, null, null),
    syncRepository.getCategoriesByAccount(id, null, null),
    prisma.household_member.findMany({ where: { idaccount: id }, include: { household: { select: { name: true } } } }),
    prisma.payment_order.findMany({ where: { idaccount: id, is_template: false }, orderBy: { created_at: 'desc' } }),
    prisma.account_device_history.findMany({ where: { idaccount: id }, orderBy: { last_active_at: 'desc' } }),
    prisma.policy_acceptance.findMany({ where: { idaccount: id }, orderBy: { accepted_at: 'asc' } }),
    prisma.auditlog.findMany({
      where: { idaccount: id, time_req: { gte: new Date(Date.now() - ACTIVITY_DAYS * DAY_MS) } },
      orderBy: { time_req: 'desc' },
    }),
  ]);
  if (!account) {
    const err = new Error('Không tìm thấy tài khoản');
    err.statusCode = 404;
    throw err;
  }

  return {
    meta: { generatedAt: new Date().toISOString(), format: 'FlowMoney personal data export v1', scope: SCOPE_NOTE },
    account: {
      username: account.username,
      email: account.email,
      plan: account.type,
      status: account.status,
      premiumExpiresAt: account.premium_expires_at,
      createdAt: account.create_at,
    },
    profile: user
      ? {
          fullname: user.fullname,
          email: user.email,
          phone: safeDecrypt(user.phone, { table: 'user', field: 'phone', id }),
          address: safeDecrypt(user.address, { table: 'user', field: 'address', id }),
          countryCode: user.country_code,
        }
      : null,
    wallets,
    transactions,
    budgets,
    bills,
    goals,
    categories,
    households: memberships.map((m) => ({ name: m.household?.name, role: m.role, joinedAt: m.joined_at, leftAt: m.left_at })),
    payments: orders.map((o) => ({
      order_code: o.order_code,
      package_type: o.package_type,
      amount: o.amount,
      status: o.status,
      created_at: o.created_at,
      paid_at: o.paid_at,
      refunded_at: o.refunded_at,
      refunded_amount: o.refunded_amount,
      refund_reason: o.refund_reason,
    })),
    devices: devices.map((d) => ({ device: d.device_name, ip: d.ip_address, userAgent: d.user_agent, firstSeenAt: d.first_seen_at, lastActiveAt: d.last_active_at })),
    policyAcceptances: acceptances.map((a) => ({ version: a.policy_version, acceptedAt: a.accepted_at, device: a.device_name })),
    serverActivity: activity.map((a) => ({ time: a.time_req, request: a.request, action: a.action, status: a.req_status, reason: a.reason })),
  };
}

const csvCell = (value) => {
  const s = value === null || value === undefined ? '' : String(value);
  return /[;"\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

function transactionsCsv(data) {
  const walletName = new Map((data.wallets || []).map((w) => [w.idwallet, w.name]));
  const categoryName = new Map((data.categories || []).map((c) => [c.idcategory, c.name_category]));
  const lines = ['sep=;', ['Ngày', 'Loại', 'Số tiền', 'Ví', 'Danh mục', 'Ghi chú', 'Đã xóa'].join(';')];
  for (const t of data.transactions || []) {
    const date = t.date_transaction ? new Date(t.date_transaction).toISOString() : '';
    lines.push(
      [date, t.type, String(t.amount ?? ''), walletName.get(t.idwallet) || t.idwallet, categoryName.get(t.idcategory) || t.idcategory || '', t.note || '', t.deleted_at ? 'Có' : '']
        .map(csvCell)
        .join(';')
    );
  }
  return `﻿${lines.join('\r\n')}\r\n`;
}

async function buildPackage(idaccount) {
  const data = await collect(idaccount);
  return { data, json: toJson(data), csv: transactionsCsv(data) };
}

function rateLimitError(last) {
  const retryAfterSec = Math.max(1, Math.ceil((new Date(last.requested_at).getTime() + RATE_LIMIT_MS - Date.now()) / 1000));
  const err = new Error('Bạn đã yêu cầu bản sao dữ liệu trong 24 giờ qua');
  err.statusCode = 429;
  err.code = 'DATA_EXPORT_RATE_LIMITED';
  err.retryAfterSec = retryAfterSec;
  return err;
}

async function requestExport(idaccount) {
  const id = Number(idaccount);
  const last = await prisma.data_export_request.findFirst({
    where: { idaccount: id, status: { not: 'FAILED' }, requested_at: { gte: new Date(Date.now() - RATE_LIMIT_MS) } },
    orderBy: { requested_at: 'desc' },
  });
  if (last) throw rateLimitError(last);
  const account = await prisma.account.findUnique({ where: { idaccount: id } });
  if (!account) {
    const err = new Error('Không tìm thấy tài khoản');
    err.statusCode = 404;
    throw err;
  }
  const row = await prisma.data_export_request.create({ data: { id: randomUUID(), idaccount: id, status: 'PROCESSING', requested_at: new Date() } });
  return { request: row, email: maskEmail(account.email) };
}

const emailHtml = (expiresAt) => `
  <p>Chào bạn,</p>
  <p>Bản sao dữ liệu cá nhân FlowMoney của bạn đã sẵn sàng.</p>
  <p>Để bảo vệ dữ liệu, tệp chỉ tải được trong ứng dụng: mở FlowMoney, đăng nhập, vào <b>Cài đặt → Dữ liệu của tôi</b> và tải trước
  <b>${expiresAt.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}</b>. Sau thời điểm này tệp tự xóa.</p>
  <p>Nếu bạn không yêu cầu bản sao này, hãy đổi mật khẩu và liên hệ bộ phận hỗ trợ của FlowMoney.</p>`;

const inFlight = new Map();

function processRequest(requestId) {
  if (inFlight.has(requestId)) return inFlight.get(requestId);
  const job = buildAndDeliver(requestId).finally(() => inFlight.delete(requestId));
  inFlight.set(requestId, job);
  return job;
}

async function buildAndDeliver(requestId) {
  const row = await prisma.data_export_request.findFirst({ where: { id: requestId } });
  if (!row || row.status !== 'PROCESSING') return row;
  try {
    const { data, json, csv } = await buildPackage(row.idaccount);
    const storage = storageMod.getStorage();
    const base = `${row.idaccount}/${row.id}`;
    const jsonRef = await storage.put({ bucket: storageMod.BUCKETS.DATA_EXPORTS, key: `${base}.json`, buffer: Buffer.from(json, 'utf8'), contentType: 'application/json' });
    const csvRef = await storage.put({ bucket: storageMod.BUCKETS.DATA_EXPORTS, key: `${base}.csv`, buffer: Buffer.from(csv, 'utf8'), contentType: 'text/csv' });
    const now = new Date();
    const expiresAt = new Date(now.getTime() + FILE_TTL_MS);
    await prisma.data_export_request.update({ where: { id: row.id }, data: { status: 'READY', json_ref: jsonRef, csv_ref: csvRef, ready_at: now, expires_at: expiresAt } });

    try {
      const sent = await emailService.sendMail({ to: data.account.email, subject: 'FlowMoney: bản sao dữ liệu của bạn đã sẵn sàng', html: emailHtml(expiresAt) });
      if (sent?.success !== false) await prisma.data_export_request.update({ where: { id: row.id }, data: { email_sent_at: new Date() } });
    } catch (mailErr) {
      logger.warn('[DataExport] Không gửi được email thông báo', { id: row.id, error: mailErr.message });
    }
    try {
      socket.emitToAccount(row.idaccount, 'account.data_export_ready', { id: row.id, expiresAt: expiresAt.toISOString() });
    } catch (_) {
      logger.warn('[DataExport] Không phát được sự kiện', { id: row.id });
    }
    return { ...row, status: 'READY' };
  } catch (err) {
    logger.error('[DataExport] Tạo bản sao thất bại', { id: row.id, error: err.message });
    await prisma.data_export_request.update({ where: { id: row.id }, data: { status: 'FAILED', error: String(err.message).slice(0, 500) } });
    return { ...row, status: 'FAILED' };
  }
}

const toPublic = (row) =>
  row && {
    id: row.id,
    status: row.status,
    requestedAt: row.requested_at,
    readyAt: row.ready_at || null,
    expiresAt: row.expires_at || null,
    emailSentAt: row.email_sent_at || null,
    files: row.status === 'READY' ? ['json', 'csv'] : [],
  };

async function getLatest(idaccount) {
  const row = await prisma.data_export_request.findFirst({ where: { idaccount: Number(idaccount) }, orderBy: { requested_at: 'desc' } });
  return toPublic(row);
}

async function getFile(idaccount, requestId, format) {
  const fmt = format === 'csv' ? 'csv' : 'json';
  const row = await prisma.data_export_request.findFirst({ where: { id: String(requestId), idaccount: Number(idaccount) } });
  const fail = (msg, statusCode, code) => Object.assign(new Error(msg), { statusCode, code });
  if (!row) throw fail('Không tìm thấy bản sao dữ liệu', 404, 'DATA_EXPORT_NOT_FOUND');
  if (row.status === 'EXPIRED' || (row.expires_at && new Date(row.expires_at) < new Date())) throw fail('Bản sao dữ liệu đã hết hạn', 410, 'DATA_EXPORT_EXPIRED');
  if (row.status !== 'READY') throw fail('Bản sao dữ liệu chưa sẵn sàng', 409, 'DATA_EXPORT_NOT_READY');
  const ref = fmt === 'csv' ? row.csv_ref : row.json_ref;
  const buffer = await storageMod.getStorage().download(ref);
  const stamp = new Date(row.ready_at || Date.now()).toLocaleDateString('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }).replace(/-/g, '');
  return {
    buffer,
    contentType: fmt === 'csv' ? 'text/csv; charset=utf-8' : 'application/json; charset=utf-8',
    filename: fmt === 'csv' ? `flowmoney-giao-dich-${stamp}.csv` : `flowmoney-du-lieu-ca-nhan-${stamp}.json`,
  };
}

async function purgeExpired() {
  const rows = await prisma.data_export_request.findMany({ where: { status: 'READY', expires_at: { lt: new Date() } } });
  const storage = storageMod.getStorage();
  let count = 0;
  for (const row of rows) {
    try {
      for (const ref of [row.json_ref, row.csv_ref]) if (ref) await storage.remove(ref);
      await prisma.data_export_request.update({ where: { id: row.id }, data: { status: 'EXPIRED', json_ref: null, csv_ref: null } });
      count += 1;
    } catch (err) {
      logger.warn('[DataExport] Không dọn được tệp hết hạn', { id: row.id, error: err.message });
    }
  }
  return count;
}

async function listForAdmin(idaccount, limit = 5) {
  const rows = await prisma.data_export_request.findMany({ where: { idaccount: Number(idaccount) }, orderBy: { requested_at: 'desc' }, take: limit });
  return rows.map((r) => ({ ...toPublic(r), error: r.error || null }));
}

module.exports = {
  SCOPE_NOTE,
  buildPackage,
  requestExport,
  processRequest,
  getLatest,
  getFile,
  purgeExpired,
  listForAdmin,
};
