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

function getRetentionDays() {
  const days = Number.parseInt(process.env.IP_RETENTION_DAYS, 10);
  return Number.isFinite(days) && days > 0 ? days : DEFAULT_RETENTION_DAYS;
}

module.exports = { getClientIp, protectIp, revealIp, getRetentionDays, DEFAULT_RETENTION_DAYS };
