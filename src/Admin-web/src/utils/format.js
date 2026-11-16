import { useMemo } from 'react';
import dayjs from 'dayjs';
import { useLanguageSafe } from '../store/language.context';
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

// ── Định dạng số / tiền theo ngôn ngữ giao diện (vi → vi-VN, en → en-US) ──
const LOCALE_OF = { vi: 'vi-VN', en: 'en-US' };
const localeOf = (lang) => LOCALE_OF[lang] || LOCALE_OF.vi;
const toNumber = (value) => {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
};

// Số thường. Mặc định tối đa 2 chữ số thập phân: 1.234,5 (vi) / 1,234.5 (en).
export const formatNumber = (value, { minFrac = 0, maxFrac = 2 } = {}, lang = 'vi') =>
  new Intl.NumberFormat(localeOf(lang), { minimumFractionDigits: minFrac, maximumFractionDigits: Math.max(minFrac, maxFrac) }).format(toNumber(value));

// Giá trị đã ở đơn vị phần trăm (99.95 → "99,95%").
export const formatPercent = (value, frac = 2, lang = 'vi') => `${formatNumber(value, { minFrac: frac, maxFrac: frac }, lang)}%`;

// Tiền tệ theo quy ước của Intl cho từng ngôn ngữ: "49.000 ₫" (vi) / "₫49,000" (en).
export const formatCurrency = (value, currency = 'VND', lang = 'vi') =>
  new Intl.NumberFormat(localeOf(lang), { style: 'currency', currency })
    .format(toNumber(value))
    .replace(/ /g, ' ');

// Hook cho component: bám ngôn ngữ đang chọn.
export const useNumberFormat = () => {
  const { language } = useLanguageSafe();
  return useMemo(
    () => ({
      lang: language,
      number: (value, opts) => formatNumber(value, opts, language),
      percent: (value, frac) => formatPercent(value, frac, language),
      currency: (value, currency = 'VND') => formatCurrency(value, currency, language),
    }),
    [language]
  );
};

export default dayjs;
