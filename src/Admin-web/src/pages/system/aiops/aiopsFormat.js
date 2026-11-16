export const VECTOR_TONE = { auth: 'warning', traffic: 'info', exploit: 'danger', resource: 'success' };

export const maskIp = (raw) => {
  const clean = String(raw || '').replace(/^::ffff:/, '').trim();
  if (!clean || clean === 'N/A' || clean === '--') return '--';
  if (clean === '127.0.0.1' || clean === '::1' || clean === 'localhost') return '127.0.xxx.xxx';
  if (clean.includes('xx')) return clean;
  const v4 = clean.match(/^(\d{1,3}\.\d{1,3})\./);
  if (v4) return `${v4[1]}.xxx.xxx`;
  const parts = clean.split(':');
  if (parts.length > 2) return `${parts[0]}:${parts[1]}:xxxx:xxxx`;
  return '--';
};

export const incidentActor = (item, myIp) => {
  const identity = item.actor?.identity || item.actor_identity || item.actorIdentity || '';
  const hash = item.actor?.ipHash || item.actor_hash || item.actorHash || '';
  const type = item.actor?.type || item.actor_type || 'IP_SOURCE';
  const account = item.actor?.username || item.username || item.actor?.targetAccount || item.targetAccount;
  const username = account && account !== 'all' && account !== 'Khách vãng lai / Ẩn danh' ? account : null;
  const userId = item.actor?.userId || item.user_id || item.userId || null;
  const vector = item.vector || 'traffic';
  const system = type === 'SYSTEM_INTERNAL' || vector === 'resource' || hash === 'system_core' || hash === 'system_host';
  const prefix = myIp ? myIp.split('.').slice(0, 2).join('.') : '';
  const mine = Boolean(myIp && (identity === myIp || identity.includes(myIp) || (prefix && identity.startsWith(`${prefix}.`))));
  const loopback = ['127.0.0.1', '::1', 'localhost', 'Internal', 'Loopback'].some((x) => identity.includes(x));
  return { identity, hash, username, userId, vector, system, mine, protectedActor: system || mine || loopback };
};

const minutesLeft = (expiresAt, remaining, fallback, now) => {
  if (expiresAt) return Math.ceil((new Date(expiresAt).getTime() - now) / 60000);
  if (remaining !== undefined && remaining !== null) return remaining;
  if (fallback !== undefined && fallback !== null) return fallback;
  return 0;
};

export const lockState = (item, now = Date.now()) => {
  const describe = (status, expiresAt, remaining) => {
    if (status === 'permanent') return { kind: 'permanent', minutes: null };
    if (status === 'temporary' || status === 'temp') {
      const minutes = minutesLeft(expiresAt, remaining, item.remainingMinutes, now);
      return minutes > 0 ? { kind: 'locked', minutes } : { kind: 'unlocked', minutes: null };
    }
    return { kind: 'unlocked', minutes: null };
  };
  const account = item.username && item.username !== 'N/A' ? item.username : item.idaccount || null;
  return {
    ip: describe(item.ipStatus || 'temporary', item.ipExpiresAt || item.expiresAt, item.ipRemainingMinutes),
    account: account ? describe(item.accountStatus, item.accountExpiresAt, item.accountRemainingMinutes) : null,
    accountLabel: account,
  };
};

export const formatMinutes = (minutes, t) => {
  const m = Math.max(0, Math.round(Number(minutes) || 0));
  if (m < 60) return t('aiopsPage.time.minutes', { m });
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest ? t('aiopsPage.time.hoursMinutes', { h, m: rest }) : t('aiopsPage.time.hours', { h });
};
