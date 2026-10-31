/**
 * Dấu nhận khoá tự động của AIOps (Task 58.5) — chỉ dùng nội bộ, không bao giờ hiện cho người dùng.
 */
const AIOPS_AUTO_REASON_PREFIX = '[AIOPS_AUTO_QUARANTINE]';

/** Lý do đưa ra cho người dùng: bỏ dấu nội bộ, giữ nguyên lý do của admin. */
function lyDoChoNguoiDung(reason) {
  if (!reason) return reason;
  const s = String(reason);
  return s.startsWith(AIOPS_AUTO_REASON_PREFIX)
    ? s.slice(AIOPS_AUTO_REASON_PREFIX.length).replace(/^[:\s]+/, '')
    : s;
}

module.exports = { AIOPS_AUTO_REASON_PREFIX, lyDoChoNguoiDung };
