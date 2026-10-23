import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import 'dayjs/locale/vi';

dayjs.extend(relativeTime);
dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.locale('vi');
dayjs.tz.setDefault('Asia/Ho_Chi_Minh');

// Format currency (VND)
export const formatCurrency = (amount) => {
  if (amount == null) return '0 ₫';
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0,
  }).format(amount);
};

// Format number with commas
export const formatNumber = (num) => {
  if (num == null) return '0';
  return new Intl.NumberFormat('vi-VN').format(num);
};

// Format date (Asia/Ho_Chi_Minh)
export const formatDate = (date, format = 'DD/MM/YYYY') => {
  if (!date) return '';
  return dayjs(date).tz('Asia/Ho_Chi_Minh').format(format);
};

// Format date time (Asia/Ho_Chi_Minh)
export const formatDateTime = (date) => {
  if (!date) return '';
  return dayjs(date).tz('Asia/Ho_Chi_Minh').format('DD/MM/YYYY HH:mm');
};

// Format date time with full seconds (Asia/Ho_Chi_Minh)
export const formatFullDateTime = (date) => {
  if (!date) return '';
  return dayjs(date).tz('Asia/Ho_Chi_Minh').format('DD/MM/YYYY HH:mm:ss');
};

// Format relative time (e.g. "2 giờ trước") theo mốc giờ Việt Nam
export const formatRelativeTime = (date) => {
  if (!date) return '';
  const d = dayjs(date).tz('Asia/Ho_Chi_Minh');
  const now = dayjs().tz('Asia/Ho_Chi_Minh');
  if (now.diff(d, 'hour') < 24) {
    return d.fromNow();
  }
  return d.format('DD/MM/YYYY');
};

// Format percentage
export const formatPercent = (value) => {
  return `${value > 0 ? '+' : ''}${value}%`;
};

// Truncate text
export const truncateText = (text, maxLength = 50) => {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
};

// Get status color
export const getStatusColor = (status) => {
  const colors = {
    active: { bg: '#dcfce7', text: '#166534' },
    inactive: { bg: '#f1f5f9', text: '#475569' },
    pending: { bg: '#fef3c7', text: '#92400e' },
    error: { bg: '#fee2e2', text: '#991b1b' },
  };
  return colors[status] || colors.inactive;
};

/**
 * Mask số điện thoại bảo vệ quyền riêng tư (Data Privacy & PII protection)
 * Giữ 3 số đầu + 3 số cuối, che 4 số giữa: 098****321
 * @param {string} phone
 * @returns {string}
 */
export const maskPhone = (phone) => {
  if (!phone || phone === '—' || typeof phone !== 'string') return '—';
  const cleanPhone = phone.trim();
  if (cleanPhone.length < 7) return cleanPhone;

  // Trường hợp chuẩn 10 số (ví dụ: 0981234567)
  if (cleanPhone.length === 10) {
    return `${cleanPhone.slice(0, 3)}****${cleanPhone.slice(7)}`;
  }

  // Trường hợp có mã quốc gia +84
  if (cleanPhone.startsWith('+84') && cleanPhone.length === 12) {
    return `${cleanPhone.slice(0, 5)}****${cleanPhone.slice(9)}`;
  }
  if (cleanPhone.startsWith('84') && cleanPhone.length === 11) {
    return `${cleanPhone.slice(0, 4)}****${cleanPhone.slice(8)}`;
  }

  // Trường hợp tổng quát: giữ 3 đầu, 3 cuối, che giữa
  const first = cleanPhone.slice(0, 3);
  const last = cleanPhone.slice(-3);
  return `${first}****${last}`;
};

export default dayjs;
