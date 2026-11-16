/**
 * Dấu nội bộ đặt ở đầu account.reason_inactive để biết khoá nào do AIOps tạo — không bao giờ hiện cho người dùng.
 * - AUTO: AIOps tự khoá (Task 58.5), hết hạn tự mở.
 * - ADMIN_TEMP: admin tạm khoá trên trang AIOps, hết hạn tự mở.
 * - ADMIN_BAN: admin khoá vĩnh viễn trên trang AIOps, chỉ mở thủ công.
 */
const AIOPS_AUTO_REASON_PREFIX = '[AIOPS_AUTO_QUARANTINE]';
const AIOPS_ADMIN_TEMP_PREFIX = '[AIOPS_ADMIN_TEMP]';
const AIOPS_ADMIN_BAN_PREFIX = '[AIOPS_ADMIN_BAN]';

/** Các dấu của khoá có thời hạn: hết hạn thì được tự mở. */
const AIOPS_EXPIRING_PREFIXES = [AIOPS_AUTO_REASON_PREFIX, AIOPS_ADMIN_TEMP_PREFIX];
const ALL_PREFIXES = [AIOPS_AUTO_REASON_PREFIX, AIOPS_ADMIN_TEMP_PREFIX, AIOPS_ADMIN_BAN_PREFIX];

/** Lý do đưa ra cho người dùng: bỏ dấu nội bộ, giữ nguyên lý do của admin. */
function lyDoChoNguoiDung(reason) {
  if (!reason) return reason;
  const s = String(reason);
  const prefix = ALL_PREFIXES.find((p) => s.startsWith(p));
  return prefix ? s.slice(prefix.length).replace(/^[:\s]+/, '') : s;
}

module.exports = {
  AIOPS_AUTO_REASON_PREFIX,
  AIOPS_ADMIN_TEMP_PREFIX,
  AIOPS_ADMIN_BAN_PREFIX,
  AIOPS_EXPIRING_PREFIXES,
  lyDoChoNguoiDung,
};
