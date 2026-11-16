export const PLANS = ['Basic', 'Premium'];

export const POLICIES = ['BLOCK_CREATE', 'LOCK_FEATURE', 'READ_ONLY', 'GRACE_PERIOD_3D', 'FALLBACK_DEFAULT'];

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
  downgrade_policy: feature.default_downgrade_policy || 'BLOCK_CREATE',
  scope_config: {},
});

export const isChanged = (draft, orig) =>
  Boolean(draft && orig) &&
  (draft.is_enabled !== orig.is_enabled ||
    draft.limit_value !== orig.limit_value ||
    draft.downgrade_policy !== orig.downgrade_policy ||
    JSON.stringify(draft.scope_config || {}) !== JSON.stringify(orig.scope_config || {}));

export const scopeSummary = (scope, t) => {
  if (!scope || typeof scope !== 'object' || Object.keys(scope).length === 0) return t('permissions.scope.default');
  const parts = [];
  if (scope.allowed_formats) {
    parts.push((Array.isArray(scope.allowed_formats) ? scope.allowed_formats.join(', ') : String(scope.allowed_formats)).toUpperCase());
  }
  if (scope.forecast_days) parts.push(`${scope.forecast_days}d`);
  if (scope.max_image_size_mb) parts.push(`${scope.max_image_size_mb}MB`);
  if (scope.daily_scans) parts.push(`${scope.daily_scans}/d`);
  if (scope.model_type) parts.push(String(scope.model_type));
  if (scope.rule) parts.push(String(scope.rule));
  if (parts.length) return parts.join(' · ');
  const values = Object.values(scope).map((v) => (typeof v === 'object' ? '…' : String(v)));
  return values.slice(0, 2).join(' · ') || t('permissions.scope.custom');
};
