// ============================================
// WealthCommand Admin - Constants
// ============================================

// API base URL (proxied via Vite)
export const API_BASE_URL = '/api';

// Local storage keys
export const STORAGE_KEYS = {
  ACCESS_TOKEN: 'wealthcommand_access_token',
  REFRESH_TOKEN: 'wealthcommand_refresh_token',
  USER: 'wealthcommand_user',
};

// Pagination defaults
export const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_SIZE: 10,
  PAGE_SIZE_OPTIONS: [10, 25, 50, 100],
};

// Transaction types
export const TRANSACTION_TYPES = {
  EXPENSE: 'expense',
  INCOME: 'income',
  DEBT: 'debt',
};

export const TRANSACTION_TYPE_LABELS = {
  expense: 'Chi phí',
  income: 'Thu nhập',
  debt: 'Vay/nợ',
};

// Category defaults
export const CATEGORY_DEFAULTS = {
  YES: 'Yes',
  NO: 'No',
};

// User status
export const USER_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
};

export const USER_STATUS_LABELS = {
  active: 'Hoạt động',
  inactive: 'Ngừng hoạt động',
};

// Time filters for dashboard
export const TIME_FILTERS = {
  TODAY: 'today',
  WEEK: '7days',
  MONTH: '30days',
};

export const TIME_FILTER_LABELS = {
  today: 'Hôm nay',
  '7days': '7 Ngày',
  '30days': '30 Ngày',
};

// System status
export const SYSTEM_STATUS = {
  STABLE: 'Ổn định',
  WARNING: 'Cảnh báo',
  CRITICAL: 'Khẩn cấp',
};
