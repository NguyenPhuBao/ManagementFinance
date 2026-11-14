const { encrypt, decrypt, hashBlindIndex } = require('./crypto.util');
const { maskIp } = require('./masking.util');

const DEFAULT_RETENTION_DAYS = 365;

function normalize(ip) {
  if (!ip || typeof ip !== 'string') return null;
  const clean = ip.replace(/^::ffff:/, '').trim();
  return clean || null;
}

function getClientIp(req) {
  return normalize(req?.ip) || normalize(req?.socket?.remoteAddress) || null;
}

function protectIp(rawIp) {
  const ip = normalize(rawIp);
  if (!ip) return { masked: null, encrypted: null, hash: null };
  return { masked: maskIp(ip), encrypted: encrypt(ip), hash: hashBlindIndex(ip) };
}

function revealIp(encrypted) {
  if (!encrypted) return null;
  try {
    return decrypt(encrypted);
  } catch (_) {
    return null;
  }
}

const EMPTY_IP_HASH = '0000000000000000';

function ipLookupHash(rawIp) {
  const ip = normalize(rawIp);
  return ip ? hashBlindIndex(ip) : EMPTY_IP_HASH;
}

const RAW_IP_KEYS = new Set(['rawIp', 'raw_ip']);

function stripRawIp(value) {
  if (Array.isArray(value)) return value.map(stripRawIp);
  if (!value || typeof value !== 'object' || value instanceof Date) return value;
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (!RAW_IP_KEYS.has(k)) out[k] = stripRawIp(v);
  }
  return out;
}

function getRetentionDays() {
  const days = Number.parseInt(process.env.IP_RETENTION_DAYS, 10);
  return Number.isFinite(days) && days > 0 ? days : DEFAULT_RETENTION_DAYS;
}

module.exports = { getClientIp, protectIp, revealIp, ipLookupHash, stripRawIp, getRetentionDays, DEFAULT_RETENTION_DAYS };
