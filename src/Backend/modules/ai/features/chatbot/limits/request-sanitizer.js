/**
 * Làm sạch lịch sử hội thoại trước khi đi tiếp: chặn lỗ hổng "lịch sử dài vô hạn" (chi phí token + CPU che PII).
 * Thứ tự quan trọng: CẮT SỐ TIN trước, rồi mới cắt độ dài từng tin, để công việc phía sau luôn bị chặn trên.
 */

function normalizeRole(role) {
  if (role === 'user') return 'user';
  if (role === 'model' || role === 'assistant') return 'model';
  return null;
}

/**
 * @param {unknown} history
 * @param {{ maxHistoryItems: number, maxHistoryItemChars: number }} limits
 * @returns {Array<{ role: 'user'|'model', text: string }>}
 */
function sanitizeHistory(history, limits) {
  if (!Array.isArray(history)) return [];

  const out = [];
  for (const item of history.slice(-limits.maxHistoryItems)) {
    if (!item || typeof item !== 'object') continue;
    const role = normalizeRole(item.role);
    const raw = typeof item.text === 'string' ? item.text : (typeof item.content === 'string' ? item.content : '');
    if (!role || !raw.trim()) continue;
    out.push({
      role,
      text: raw.length > limits.maxHistoryItemChars ? raw.slice(0, limits.maxHistoryItemChars) : raw,
    });
  }
  return out;
}

module.exports = { sanitizeHistory };
