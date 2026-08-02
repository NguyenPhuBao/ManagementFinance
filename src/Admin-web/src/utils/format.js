import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';

dayjs.extend(relativeTime);
dayjs.locale('vi');

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

// Format date
export const formatDate = (date, format = 'DD/MM/YYYY') => {
  return dayjs(date).format(format);
};

// Format date time
export const formatDateTime = (date) => {
  return dayjs(date).format('DD/MM/YYYY HH:mm');
};

// Format relative time (e.g. "2 giờ trước")
export const formatRelativeTime = (date) => {
  const d = dayjs(date);
  const now = dayjs();
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

export default dayjs;
