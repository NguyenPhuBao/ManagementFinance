const { prisma } = require('../../config/db');
const logger = require('../../core/logger');

const DEADLINE_MS = 72 * 60 * 60 * 1000;
const SOURCES = ['AIOPS', 'AUDIT_LOG', 'USER_REPORT', 'PROCESSOR', 'OTHER'];
const STATUS_ORDER = { OPEN: 0, CONTAINED: 1, REPORTED: 2, CLOSED: 3 };

const fail = (message, statusCode = 400, code = 'INVALID_INPUT') => Object.assign(new Error(message), { statusCode, code });
const text = (v) => (typeof v === 'string' ? v.trim() : '');
const optText = (v) => (text(v) ? text(v) : null);

function optCount(value, label) {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0) throw fail(`${label} phải là số nguyên không âm`);
  return n;
}

function optDate(value, label, { notFuture = false } = {}) {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw fail(`${label} không hợp lệ`);
  if (notFuture && d.getTime() > Date.now() + 5 * 60 * 1000) throw fail(`${label} không được ở tương lai`);
  return d;
}

function toView(row) {
  const detected = new Date(row.detected_at).getTime();
  const deadline = detected + DEADLINE_MS;
  const reportedAt = row.authority_reported_at ? new Date(row.authority_reported_at).getTime() : null;
  return {
    ...row,
    deadline: new Date(deadline).toISOString(),
    remainingMs: deadline - Date.now(),
    overdue: !reportedAt && !row.report_not_required && row.status !== 'CLOSED' && Date.now() > deadline,
    reportedLate: Boolean(reportedAt && reportedAt > deadline),
  };
}

const EDITABLE = {
  title: (v) => { const t = text(v); if (!t) throw fail('Tiêu đề không được để trống'); if (t.length > 200) throw fail('Tiêu đề tối đa 200 ký tự'); return t; },
  description: (v) => { const t = text(v); if (!t) throw fail('Mô tả không được để trống'); return t; },
  source: (v) => { if (!SOURCES.includes(v)) throw fail('Nguồn phát hiện không hợp lệ'); return v; },
  detectedAt: (v) => optDate(v, 'Thời điểm phát hiện', { notFuture: true }),
  occurredAt: (v) => optDate(v, 'Thời điểm xảy ra', { notFuture: true }),
  dataTypes: optText,
  sensitive: (v) => Boolean(v),
  affectedUsers: (v) => optCount(v, 'Số người dùng bị ảnh hưởng'),
  affectedRecords: (v) => optCount(v, 'Số bản ghi bị ảnh hưởng'),
  consequences: optText,
  measures: optText,
  contact: optText,
};
const COLUMN = {
  title: 'title', description: 'description', source: 'source', detectedAt: 'detected_at', occurredAt: 'occurred_at',
  dataTypes: 'data_types', sensitive: 'sensitive', affectedUsers: 'affected_users', affectedRecords: 'affected_records',
  consequences: 'consequences', measures: 'measures', contact: 'contact',
};

function pickEditable(input) {
  const data = {};
  for (const [key, parse] of Object.entries(EDITABLE)) {
    if (input[key] === undefined) continue;
    const value = parse(input[key]);
    if (value !== undefined) data[COLUMN[key]] = value;
  }
  return data;
}

function emitChanged(incident) {
  try {
    const { getIO } = require('../../core/socket');
    const io = getIO();
    if (io) io.to('admin_room').emit('admin.data_incident_changed', { id: incident.id, code: incident.code, status: incident.status });
  } catch (err) {
    logger.warn('[DataIncident] Không phát được sự kiện', { error: err.message });
  }
}

async function nextCode(detectedAt) {
  const year = new Date(detectedAt).getFullYear();
  const prefix = `SC-${year}-`;
  const count = await prisma.data_incident.count({ where: { code: { startsWith: prefix } } });
  return `${prefix}${String(count + 1).padStart(3, '0')}`;
}

async function createIncident(input, adminId) {
  const data = pickEditable({ source: 'OTHER', ...input });
  if (!data.title) throw fail('Tiêu đề không được để trống');
  if (!data.description) throw fail('Mô tả không được để trống');
  if (!data.detected_at) data.detected_at = new Date();
  data.code = await nextCode(data.detected_at);
  data.created_by = adminId || null;
  data.updated_by = adminId || null;
  const row = await prisma.data_incident.create({ data });
  service.emitChanged(row);
  return row;
}

async function getOpen(id) {
  const row = await prisma.data_incident.findUnique({ where: { id: Number(id) } });
  if (!row) throw fail('Không tìm thấy sự cố', 404, 'NOT_FOUND');
  if (row.status === 'CLOSED') throw fail('Sự cố đã đóng, không sửa được', 409, 'INCIDENT_CLOSED');
  return row;
}

async function save(id, data, adminId) {
  const row = await prisma.data_incident.update({ where: { id: Number(id) }, data: { ...data, updated_by: adminId || null, updated_at: new Date() } });
  service.emitChanged(row);
  return row;
}

async function updateIncident(id, input, adminId) {
  await getOpen(id);
  return save(id, pickEditable(input || {}), adminId);
}

async function runAction(id, action, payload = {}, adminId) {
  const row = await getOpen(id);
  const now = new Date();
  if (action === 'contain') {
    return save(id, { status: row.status === 'OPEN' ? 'CONTAINED' : row.status, contained_at: row.contained_at || now }, adminId);
  }
  if (action === 'report') {
    const reportedAt = optDate(payload.reportedAt, 'Thời điểm báo cơ quan', { notFuture: true }) || now;
    const late = reportedAt.getTime() > new Date(row.detected_at).getTime() + DEADLINE_MS;
    const lateReason = optText(payload.lateReason);
    if (late && !lateReason) throw fail('Báo cơ quan sau 72 giờ phải ghi lý do báo muộn', 400, 'LATE_REASON_REQUIRED');
    return save(id, {
      status: 'REPORTED',
      contained_at: row.contained_at || now,
      authority_reported_at: reportedAt,
      authority_report_ref: optText(payload.reference),
      late_reason: late ? lateReason : null,
    }, adminId);
  }
  if (action === 'notify-users') {
    return save(id, { users_notified_at: optDate(payload.notifiedAt, 'Thời điểm báo người dùng', { notFuture: true }) || now }, adminId);
  }
  if (action === 'close') {
    const rootCause = optText(payload.rootCause);
    if (!rootCause) throw fail('Phải ghi nguyên nhân gốc trước khi đóng', 400, 'ROOT_CAUSE_REQUIRED');
    const notRequired = Boolean(payload.reportNotRequired);
    const noReportReason = optText(payload.noReportReason);
    if (notRequired && !noReportReason) throw fail('Phải ghi lý do không cần báo cơ quan', 400, 'NO_REPORT_REASON_REQUIRED');
    if (!row.authority_reported_at && !notRequired) throw fail('Phải báo cơ quan chuyên trách, hoặc ghi lý do không cần báo, trước khi đóng', 400, 'REPORT_REQUIRED');
    return save(id, {
      status: 'CLOSED',
      root_cause: rootCause,
      report_not_required: !row.authority_reported_at && notRequired,
      no_report_reason: !row.authority_reported_at && notRequired ? noReportReason : null,
      closed_at: now,
    }, adminId);
  }
  throw fail('Thao tác không hợp lệ', 400, 'INVALID_ACTION');
}

async function listIncidents({ status } = {}) {
  const where = status && STATUS_ORDER[status] !== undefined ? { status } : {};
  const rows = await prisma.data_incident.findMany({ where, orderBy: { detected_at: 'desc' } });
  return rows
    .map(toView)
    .sort((a, b) => (a.status === 'CLOSED') - (b.status === 'CLOSED') || new Date(b.detected_at) - new Date(a.detected_at));
}

const service = {
  DEADLINE_MS,
  SOURCES,
  toView,
  emitChanged,
  createIncident,
  updateIncident,
  runAction,
  listIncidents,
};

module.exports = service;
