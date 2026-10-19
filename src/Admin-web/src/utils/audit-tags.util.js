/**
 * Audit Log Tag Classification Utility
 * Phân loại hoạt động hệ thống & nhật ký kiểm toán thành các nhãn phân loại:
 * [AUTH], [PAYMENT], [USER], [SYSTEM], [AIOPS], [CATEGORY], [API]
 */

export const AUDIT_TAGS = {
  AUTH: {
    key: 'AUTH',
    tag: '[AUTH]',
    label: 'Xác thực',
    bg: 'bg-blue-50',
    text: 'text-blue-700',
    border: 'border-blue-200',
    icon: 'lock',
  },
  PAYMENT: {
    key: 'PAYMENT',
    tag: '[PAYMENT]',
    label: 'Thanh toán',
    bg: 'bg-emerald-50',
    text: 'text-emerald-700',
    border: 'border-emerald-200',
    icon: 'payments',
  },
  USER: {
    key: 'USER',
    tag: '[USER]',
    label: 'Người dùng',
    bg: 'bg-purple-50',
    text: 'text-purple-700',
    border: 'border-purple-200',
    icon: 'person',
  },
  SYSTEM: {
    key: 'SYSTEM',
    tag: '[SYSTEM]',
    label: 'Hệ thống',
    bg: 'bg-amber-50',
    text: 'text-amber-800',
    border: 'border-amber-200',
    icon: 'settings',
  },
  AIOPS: {
    key: 'AIOPS',
    tag: '[AIOPS]',
    label: 'An ninh',
    bg: 'bg-rose-50',
    text: 'text-rose-700',
    border: 'border-rose-200',
    icon: 'security',
  },
  CATEGORY: {
    key: 'CATEGORY',
    tag: '[CATEGORY]',
    label: 'Danh mục',
    bg: 'bg-teal-50',
    text: 'text-teal-700',
    border: 'border-teal-200',
    icon: 'category',
  },
  API: {
    key: 'API',
    tag: '[API]',
    label: 'API',
    bg: 'bg-slate-100',
    text: 'text-slate-700',
    border: 'border-slate-200',
    icon: 'api',
  },
};

/**
 * Phân loại action name / path để lấy nhãn phân loại chuẩn hóa
 * @param {string} actionText - Chuỗi mô tả hành động hoặc endpoint
 * @returns {{ tagInfo: object, cleanAction: string }}
 */
export const classifyAuditAction = (actionText) => {
  if (!actionText || typeof actionText !== 'string') {
    return { tagInfo: AUDIT_TAGS.API, cleanAction: 'Hoạt động' };
  }

  const trimmed = actionText.trim();

  // 1. Kiểm tra nếu action đã có sẵn thẻ [TAG] ở đầu
  const bracketMatch = trimmed.match(/^\[([A-Z0-9_-]+)\]\s*(.*)$/);
  if (bracketMatch) {
    const rawTagKey = bracketMatch[1].toUpperCase();
    const cleanAction = bracketMatch[2].trim() || trimmed;
    if (AUDIT_TAGS[rawTagKey]) {
      return { tagInfo: AUDIT_TAGS[rawTagKey], cleanAction };
    }
  }

  const lower = trimmed.toLowerCase();

  // 2. Nhận diện nhãn theo từ khóa nghiệp vụ
  // AIOps & An ninh
  if (
    lower.includes('aiops') ||
    lower.includes('sentinel') ||
    lower.includes('quarantine') ||
    lower.includes('cô lập') ||
    lower.includes('cách ly') ||
    lower.includes('blacklist') ||
    lower.includes('threat') ||
    lower.includes('tạm khóa ip') ||
    lower.includes('khóa ip')
  ) {
    return { tagInfo: AUDIT_TAGS.AIOPS, cleanAction: trimmed };
  }

  // Payment & Gói cước
  if (
    lower.includes('thanh toán') ||
    lower.includes('payment') ||
    lower.includes('payos') ||
    lower.includes('refund') ||
    lower.includes('hoàn tiền') ||
    lower.includes('nâng cấp gói') ||
    lower.includes('đơn hàng') ||
    lower.includes('webhook')
  ) {
    return { tagInfo: AUDIT_TAGS.PAYMENT, cleanAction: trimmed };
  }

  // Auth & Xác thực
  if (
    lower.includes('đăng nhập') ||
    lower.includes('login') ||
    lower.includes('logout') ||
    lower.includes('đăng xuất') ||
    lower.includes('mật khẩu') ||
    lower.includes('password') ||
    lower.includes('token') ||
    lower.includes('otp') ||
    lower.includes('mã pin') ||
    lower.includes('pin') ||
    lower.includes('re-auth') ||
    lower.includes('xác thực')
  ) {
    return { tagInfo: AUDIT_TAGS.AUTH, cleanAction: trimmed };
  }

  // User & Tài khoản người dùng
  if (
    lower.includes('người dùng') ||
    lower.includes('user') ||
    lower.includes('tài khoản') ||
    lower.includes('profile') ||
    lower.includes('vô hiệu hóa') ||
    lower.includes('kích hoạt') ||
    lower.includes('xóa mềm') ||
    lower.includes('hủy xóa') ||
    lower.includes('block')
  ) {
    return { tagInfo: AUDIT_TAGS.USER, cleanAction: trimmed };
  }

  // Category & Danh mục
  if (lower.includes('danh mục') || lower.includes('category')) {
    return { tagInfo: AUDIT_TAGS.CATEGORY, cleanAction: trimmed };
  }

  // System & Bảo trì
  if (
    lower.includes('bảo trì') ||
    lower.includes('maintenance') ||
    lower.includes('broadcast') ||
    lower.includes('phát sóng') ||
    lower.includes('hệ thống') ||
    lower.includes('system') ||
    lower.includes('cấu hình')
  ) {
    return { tagInfo: AUDIT_TAGS.SYSTEM, cleanAction: trimmed };
  }

  // Mặc định là API
  return { tagInfo: AUDIT_TAGS.API, cleanAction: trimmed };
};
