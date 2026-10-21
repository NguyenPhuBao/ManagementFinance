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
 * Bộ từ điển ánh xạ thông minh chuyển đổi từ chuỗi API Endpoint (hoặc mã thô) sang câu nghiệp vụ tiếng Việt
 * Đảm bảo 100% cột Hành động luôn hiển thị tiếng Việt rõ ràng, thân thiện cho người quản trị.
 * @param {string} raw - Chuỗi hành động thô hoặc endpoint
 * @returns {string|null} - Câu mô tả tiếng Việt chuẩn hóa, hoặc null nếu không khớp
 */
export const translateApiToActionName = (raw) => {
  if (!raw || typeof raw !== 'string') return null;
  const str = raw.trim();
  const lower = str.toLowerCase();

  // Kiểm tra nếu chuỗi chứa dấu hiệu của một API route hoặc HTTP method
  const isApiLike =
    /^(get|post|put|patch|delete|options|head)\s+/i.test(str) ||
    lower.includes('/api/') ||
    lower.startsWith('/');

  if (!isApiLike) {
    return null;
  }

  const m = (/^(GET|POST|PUT|PATCH|DELETE)/i.exec(str)?.[0] || 'GET').toUpperCase();

  // 1. Nhóm Thanh Toán & Gói Cước (Payments & PayOS)
  if (lower.includes('/payment') || lower.includes('/payos') || lower.includes('thanh toán')) {
    if (lower.includes('/create-order') || lower.includes('/create-payment')) return 'Tạo đơn hàng thanh toán gói cước';
    if (lower.includes('/order-status')) return 'Tra cứu trạng thái đơn hàng';
    if (lower.includes('/subscription-info') || lower.includes('/packages')) return 'Tra cứu thông tin gói dịch vụ';
    if (lower.includes('/history') || lower.includes('/orders')) {
      if (lower.includes('/refund')) return 'Xử lý hoàn tiền đơn hàng';
      return 'Xem lịch sử giao dịch thanh toán';
    }
    if (lower.includes('/webhook')) return 'Webhook tiếp nhận thanh toán PayOS';
    if (lower.includes('/confirm-upgrade')) return 'Xác nhận nâng cấp gói cước';
    if (lower.includes('/stats')) return 'Thống kê doanh thu thanh toán';
    if (lower.includes('/payos-qr')) return 'Tạo mã QR thanh toán PayOS';
    if (lower.includes('/simulate-webhook')) return 'Mô phỏng Webhook thanh toán';
    return 'Giao dịch thanh toán gói cước';
  }

  // 2. Nhóm Xác Thực & Tài Khoản (Auth)
  if (lower.includes('/auth/')) {
    if (lower.includes('/login')) return 'Đăng nhập hệ thống';
    if (lower.includes('/register')) return 'Đăng ký tài khoản';
    if (lower.includes('/logout')) return 'Đăng xuất';
    if (lower.includes('/refresh')) return 'Làm mới phiên đăng nhập';
    if (lower.includes('/forgot-password')) return 'Yêu cầu đặt lại mật khẩu';
    if (lower.includes('/verify-otp')) return 'Xác thực mã OTP';
    if (lower.includes('/reset-password')) return 'Đặt lại mật khẩu';
    if (lower.includes('/change-password')) return 'Đổi mật khẩu tài khoản';
    if (lower.includes('/profile')) return m === 'PUT' ? 'Cập nhật hồ sơ cá nhân' : 'Xem thông tin cá nhân';
  }

  // 3. Nhóm Quản Trị Hệ Thống & Bảo Mật (Admin Security & System)
  if (lower.includes('/admin/')) {
    if (lower.includes('/verify-security-action')) return 'Xác thực mã PIN bảo mật';
    if (lower.includes('/change-pin')) return 'Đổi mã PIN quản trị viên';
    if (lower.includes('/first-login-setup')) return 'Thiết lập bảo mật lần đầu';
    if (lower.includes('/create-admin')) return 'Tạo tài khoản quản trị mới';
    if (lower.includes('/permissions/reset')) return 'Khôi phục phân quyền mặc định';
    if (lower.includes('/permissions')) return m === 'PUT' ? 'Cập nhật phân quyền gói cước' : 'Xem ma trận phân quyền gói cước';
    if (lower.includes('/system/maintenance/schedule')) return 'Hủy lịch bảo trì hệ thống';
    if (lower.includes('/system/maintenance/history')) return 'Xem lịch sử bảo trì hệ thống';
    if (lower.includes('/system/maintenance')) return m === 'POST' ? 'Cập nhật trạng thái bảo trì hệ thống' : 'Kiểm tra trạng thái bảo trì';
    if (lower.includes('/system/health')) return 'Kiểm tra sức khỏe hệ thống';
    if (lower.includes('/audit-logs')) return 'Truy vấn nhật ký kiểm toán';
    if (lower.includes('/updatestatus') || lower.includes('/users/status')) return 'Khóa/mở khóa tài khoản';
    if (lower.includes('/deleteuser') || (lower.includes('/users') && m === 'DELETE')) return 'Xóa tài khoản người dùng';
    if (lower.includes('/getuser') || lower.includes('/users')) return 'Tra cứu danh sách người dùng';
    if (lower.includes('/deletecategory') || (lower.includes('/categories') && m === 'DELETE')) return 'Xóa danh mục hệ thống';
    if (lower.includes('/addcategory') || (lower.includes('/categories') && m === 'POST')) return 'Tạo danh mục hệ thống';
    if (lower.includes('/updatecategory') || (lower.includes('/categories') && (m === 'PUT' || m === 'PATCH'))) return 'Cập nhật danh mục hệ thống';
    if (lower.includes('/getcategory') || lower.includes('/categories')) return 'Lấy danh sách danh mục';
  }

  // 4. Nhóm AIOps Sentinel & An Ninh
  if (lower.includes('/aiops/')) {
    if (lower.includes('/quarantine/permanent-ip')) return 'Khóa vĩnh viễn IP nguy hại';
    if (lower.includes('/quarantine/temporary-ip')) return 'Tạm khóa IP nghi vấn';
    if (lower.includes('/quarantine/unblock-ip')) return 'Mở khóa IP cách ly';
    if (lower.includes('/quarantine/permanent-account')) return 'Khóa vĩnh viễn tài khoản nguy hại';
    if (lower.includes('/quarantine/temporary-account')) return 'Tạm khóa tài khoản nghi vấn';
    if (lower.includes('/quarantine/unblock-account')) return 'Mở khóa tài khoản cách ly';
    if (lower.includes('/quarantine')) return 'Quản lý danh sách cách ly an ninh';
    if (lower.includes('/incidents')) return 'Xử lý sự cố an ninh AIOps';
    if (lower.includes('/vectors')) return 'Cấu hình vector phòng vệ AIOps';
    if (lower.includes('/calibrate')) return 'Hiệu chỉnh mô hình AIOps';
    if (lower.includes('/scale')) return 'Điều chỉnh độ nhạy AIOps';
    if (lower.includes('/status') || lower.includes('/history')) return 'Giám sát an ninh AIOps';
  }

  // 5. Nhóm Đồng Bộ & Ngân Hàng
  if (lower.includes('/sync/')) {
    if (lower.includes('/push')) return 'Đồng bộ dữ liệu (Push)';
    if (lower.includes('/pull')) return 'Tải dữ liệu đồng bộ (Pull)';
    if (lower.includes('/full')) return 'Đồng bộ toàn bộ dữ liệu';
    if (lower.includes('/default-categories')) return 'Đồng bộ danh mục mặc định';
  }
  if (lower.includes('/bank/')) {
    if (lower.includes('/sync')) return 'Đồng bộ giao dịch ngân hàng';
    if (lower.includes('/webhook')) return 'Webhook biến động số dư';
    if (lower.includes('/connect') || lower.includes('/link')) return 'Liên kết tài khoản ngân hàng';
  }

  // 6. Nhóm AI Trợ Lý & Phân Loại
  if (lower.includes('/ai/')) {
    if (lower.includes('/chatbot/reset') || lower.includes('/chat/reset')) return 'Làm mới hội thoại AI';
    if (lower.includes('/chat')) return 'Hỏi đáp trợ lý tài chính AI';
    if (lower.includes('/classify')) return 'Phân loại giao dịch AI';
  }

  // 7. Nhóm Nghiệp Vụ Tài Chính Khách Hàng (Transactions, Wallets, Budgets)
  if (lower.includes('/transactions')) {
    if (m === 'POST') return 'Ghi nhận giao dịch tài chính';
    if (m === 'PUT' || m === 'PATCH') return 'Cập nhật giao dịch tài chính';
    if (m === 'DELETE') return 'Xóa giao dịch tài chính';
    return 'Tra cứu lịch sử giao dịch';
  }
  if (lower.includes('/wallets')) {
    if (m === 'POST') return 'Tạo ví tài chính mới';
    if (m === 'PUT' || m === 'PATCH') return 'Cập nhật thông tin ví';
    if (m === 'DELETE') return 'Xóa ví tài chính';
    return 'Xem danh sách ví tài chính';
  }
  if (lower.includes('/budgets')) {
    if (m === 'POST') return 'Thiết lập hạn mức ngân sách';
    if (m === 'PUT' || m === 'PATCH') return 'Cập nhật ngân sách';
    if (m === 'DELETE') return 'Xóa ngân sách';
    return 'Tra cứu hạn mức ngân sách';
  }
  if (lower.includes('/reports')) return 'Xem báo cáo phân tích tài chính';

  // Fallback thân thiện nếu là endpoint khác chưa liệt kê
  if (m === 'GET') return 'Truy vấn dữ liệu hệ thống';
  if (m === 'POST') return 'Thực hiện thao tác tạo mới';
  if (m === 'PUT' || m === 'PATCH') return 'Thực hiện cập nhật dữ liệu';
  if (m === 'DELETE') return 'Thực hiện yêu cầu xóa dữ liệu';

  return 'Yêu cầu API hệ thống';
};

/**
 * Phân loại action name / path để lấy nhãn phân loại chuẩn hóa
 * Tự động chuyển đổi các chuỗi API thô sang câu tiếng Việt mô tả nghiệp vụ
 * @param {string} actionText - Chuỗi mô tả hành động hoặc endpoint
 * @param {string} [requestFallback] - Chuỗi endpoint dự phòng nếu action rỗng
 * @returns {{ tagInfo: object, cleanAction: string }}
 */
export const classifyAuditAction = (actionText, requestFallback = '') => {
  const effectiveText = (actionText && typeof actionText === 'string' && actionText.trim()) ||
    (requestFallback && typeof requestFallback === 'string' && requestFallback.trim()) ||
    '';

  if (!effectiveText) {
    return { tagInfo: AUDIT_TAGS.API, cleanAction: 'Hoạt động hệ thống' };
  }

  const trimmed = effectiveText.trim();

  // 1. Kiểm tra nếu action đã có sẵn thẻ [TAG] ở đầu
  const bracketMatch = trimmed.match(/^\[([A-Z0-9_-]+)\]\s*(.*)$/);
  if (bracketMatch) {
    const rawTagKey = bracketMatch[1].toUpperCase();
    const rawCleanAction = bracketMatch[2].trim() || trimmed;
    const translated = translateApiToActionName(rawCleanAction);
    const finalClean = translated || rawCleanAction;
    if (AUDIT_TAGS[rawTagKey]) {
      return { tagInfo: AUDIT_TAGS[rawTagKey], cleanAction: finalClean };
    }
  }

  // 2. Dịch chuỗi API thô sang tiếng Việt nếu phát hiện chuỗi API
  const translatedAction = translateApiToActionName(trimmed);
  const cleanAction = translatedAction || trimmed;
  const lower = (trimmed + ' ' + (translatedAction || '')).toLowerCase();

  // 3. Nhận diện nhãn theo từ khóa nghiệp vụ
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
    return { tagInfo: AUDIT_TAGS.AIOPS, cleanAction };
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
    return { tagInfo: AUDIT_TAGS.PAYMENT, cleanAction };
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
    return { tagInfo: AUDIT_TAGS.AUTH, cleanAction };
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
    return { tagInfo: AUDIT_TAGS.USER, cleanAction };
  }

  // Category & Danh mục
  if (lower.includes('danh mục') || lower.includes('category')) {
    return { tagInfo: AUDIT_TAGS.CATEGORY, cleanAction };
  }

  // System & Bảo trì & Phân quyền
  if (
    lower.includes('bảo trì') ||
    lower.includes('maintenance') ||
    lower.includes('broadcast') ||
    lower.includes('phát sóng') ||
    lower.includes('hệ thống') ||
    lower.includes('system') ||
    lower.includes('cấu hình') ||
    lower.includes('phân quyền') ||
    lower.includes('permission')
  ) {
    return { tagInfo: AUDIT_TAGS.SYSTEM, cleanAction };
  }

  // Mặc định là API
  return { tagInfo: AUDIT_TAGS.API, cleanAction };
};
