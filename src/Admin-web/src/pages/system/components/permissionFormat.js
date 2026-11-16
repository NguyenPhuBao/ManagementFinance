export const PLANS = ['Basic', 'Premium'];

/**
 * Cách ứng dụng di động xử lý khi người dùng bị hạ gói (chốt 2026-11-16: app viết cứng, Admin-web chỉ hiện, không chỉnh).
 * Nguồn: Client-app `features/premium/domain/quyen_tinh_nang.dart` (9 mã không bao giờ khoá) và `tran_goi.dart`
 * (vượt hạn mức chỉ chặn tạo thêm); gia đình do Backend chuyển nhà sang chỉ xem khi chủ nhà hết Premium.
 */
const NEVER_LOCK = [
  'transaction_management', 'offline_first_sync', 'vietqr_payment', 'account_deletion', 'biometric_auth',
  'payment_history', 'ai_model_management', 'offline_login', 'financial_health_fhs',
];
const HOUSEHOLD_READ_ONLY = ['household', 'household_members', 'household_wallets'];

/** Hạn mức Backend viết cứng (gia đình: 6 thành viên, 10 ví chung): không cho sửa số. */
export const FIXED_LIMITS = ['household_members', 'household_wallets'];

export const downgradeBehavior = (feature) => {
  if (NEVER_LOCK.includes(feature.id)) return 'neverLock';
  if (HOUSEHOLD_READ_ONLY.includes(feature.id)) return 'householdReadOnly';
  return feature.type === 'LIMIT' ? 'blockCreate' : 'lockFeature';
};

const GROUP_KEYS = {
  'Tài nguyên': 'resources',
  'Trí tuệ nhân tạo': 'ai',
  'Trí tuệ nhân tạo & Edge AI': 'ai',
  'Báo cáo & Phân tích': 'reporting',
  'Tự động hóa & Tiện ích': 'automation',
  'Xác thực & Bảo mật': 'auth',
  'Trang chủ & Điều hướng': 'home',
  'Quản lý Ví & Tài sản': 'wallet',
  'Sổ giao dịch Thu Chi': 'transactions',
  'Hệ thống Danh mục': 'categories',
  'Ngân sách Chi tiêu': 'budget',
  'Hóa đơn định kỳ': 'bills',
  'Mục tiêu Tích lũy': 'goals',
  'Thông báo & Giám sát': 'notifications',
  'Gói cước & Thanh toán': 'payment',
  'Đồng bộ Ngoại tuyến': 'sync',
  'Gia đình': 'family',
};

export const groupLabel = (group, t) => {
  const key = GROUP_KEYS[group];
  return key ? t(`permissions.groups.${key}`, group) : group;
};

export const defaultPermission = (feature, plan) => ({
  is_enabled: true,
  limit_value: feature.type === 'LIMIT' && plan === 'Basic' ? 3 : null,
});

/** Chỉ quyền truy cập và hạn mức chỉnh được; phạm vi và chính sách hạ cấp không hiện / không gửi (chốt 2026-11-16). */
export const isChanged = (draft, orig) =>
  Boolean(draft && orig) && (draft.is_enabled !== orig.is_enabled || draft.limit_value !== orig.limit_value);
