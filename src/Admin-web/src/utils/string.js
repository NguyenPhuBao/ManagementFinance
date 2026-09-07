/**
 * String normalization utilities for Admin-web
 */

/**
 * Chuẩn hóa tên danh mục theo quy tắc CSDL:
 * - NFC normalization
 * - Trim khoảng trắng đầu/cuối
 * - Thu gọn khoảng trắng thừa giữa các từ thành 1 space
 * - Chuyển chữ thường (lowercase)
 * @param {string} str 
 * @returns {string}
 */
export const normalizeCategoryName = (str) => {
  if (!str || typeof str !== 'string') return '';
  return str
    .normalize('NFC')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
};

/**
 * Bỏ dấu tiếng Việt phục vụ tìm kiếm mềm (accent-insensitive search)
 * @param {string} str 
 * @returns {string}
 */
export const normalizeVietnameseUnaccent = (str) => {
  if (!str || typeof str !== 'string') return '';
  return str
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .trim();
};
