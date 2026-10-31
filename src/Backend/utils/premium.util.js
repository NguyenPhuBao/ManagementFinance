/**
 * Định nghĩa DUY NHẤT của "Premium đang hiệu lực" (Task 55.A3).
 * Premium không có premium_expires_at là dữ liệu hỏng ⇒ KHÔNG phải Premium.
 */
function isPremiumEffective(account, now = new Date()) {
  if (!account || account.type !== 'Premium' || !account.premium_expires_at) return false;
  return new Date(account.premium_expires_at) > now;
}

module.exports = { isPremiumEffective };
