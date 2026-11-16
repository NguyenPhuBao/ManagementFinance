import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import 'dayjs/locale/vi';

dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.locale('vi');
dayjs.tz.setDefault('Asia/Ho_Chi_Minh');

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
