import { baseURL } from '../../api/axios-client';

export const STATUS_TONE = {
  PAID: 'success',
  PENDING: 'warning',
  WAITING_CONFIRMATION: 'info',
  REFUND_PENDING: 'warning',
  REFUNDED: 'neutral',
  CANCELLED: 'neutral',
  EXPIRED: 'danger',
};

export const STATUSES = Object.keys(STATUS_TONE);

export const formatVnd = (amount) => `${Number(amount || 0).toLocaleString('vi-VN')} ₫`;

export const formatDate = (value) => {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' });
};

export const formatCountdown = (secs) => `${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`;

export const effectiveStatus = (order) =>
  order.status === 'PENDING' && order.expired_at && new Date(order.expired_at) <= new Date() ? 'EXPIRED' : order.status;

export const packageLabel = (type, t) => {
  if (type === 'Basic') return t('payments.package.Basic');
  if (type === 'Premium' || String(type || '').startsWith('PREMIUM')) return t('payments.package.Premium');
  return type || '—';
};

export const assetUrl = (path) => {
  if (!path || /^https?:\/\//i.test(path)) return path;
  const origin = /^https?:\/\//i.test(baseURL) ? baseURL.replace(/\/api\/?$/, '') : '';
  return `${origin}${path}`;
};
