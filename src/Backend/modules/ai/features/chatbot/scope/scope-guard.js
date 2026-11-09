/**
 * Bộ lọc phạm vi câu hỏi của Chatbot AI — LỚP QUY TẮC, chạy trước khi gọi LLM (0 token, 0 độ trễ mạng).
 *
 * Chặn bằng DANH SÁCH LOẠI VIỆC rõ ràng ngoài phạm vi (viết mã, dịch, sáng tác, bài tập, đời sống không
 * liên quan) và các mẫu tiêm lệnh. Không dùng danh sách từ tài chính để cho phép, vì sẽ chặn oan người
 * dùng thật. Từ tài chính chỉ dùng để gỡ chặn nhóm OFF_TOPIC (vd. "viết email xin vay ngân hàng").
 * Mẫu tiêm lệnh (INJECTION) luôn chặn, không gỡ được.
 *
 * Đây không phải bảo đảm tuyệt đối: chi phí được bảo vệ bởi giới hạn số cứng (độ dài, token, hạn mức ngày),
 * lớp này chỉ giảm lạm dụng và lệch chủ đề. Tỷ lệ lọt qua đo bằng bộ câu hỏi riêng.
 */

const SCOPE_REFUSAL_TEXT =
  'Mình là trợ lý tài chính cá nhân của FlowMoney nên chỉ hỗ trợ các câu hỏi về thu chi, ngân sách, mục tiêu tiết kiệm, ' +
  'hóa đơn, vay nợ và kiến thức tài chính. Bạn thử hỏi lại theo hướng đó nhé.';

function normalize(text) {
  return String(text)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/[^a-z0-9+#\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const INJECTION_PATTERNS = [
  /\b(bo qua|quen di|huy bo|phot lo)\b.{0,40}\b(huong dan|chi thi|quy tac|prompt|instruction)/,
  /\bsystem prompt\b/,
  /\bprompt (he thong|goc|ban dau)\b/,
  /\b(huong dan|chi thi) (he thong|ban dau|goc)\b/,
  /\bignore\b.{0,30}\b(instruction|previous|above|prompt|rules)/,
  /\b(developer|dev) mode\b/,
  /\bjailbreak\b/,
  /\bdan mode\b/,
];

const OFF_TOPIC_PATTERNS = [
  /\b(viet|lam|sua|debug|giai thich)\b.{0,15}\b(code|ma nguon|chuong trinh|ham|script|thuat toan)\b/,
  /\b(python|javascript|typescript|java|c\+\+|c#|html|css|php|react|flutter|leetcode)\b/,
  /\bdich\b.{0,60}\b(sang|ra)\b/,
  /\btranslate\b/,
  /\b(lam tho|viet tho|viet truyen|sang tac|viet van|viet bai van|viet bai luan|viet bai thuyet trinh|soan bai)\b/,
  /\bgiai\b.{0,25}\b(bai tap|phuong trinh|de thi|bai toan)\b/,
  /\b(bai tap ve nha|bai kiem tra|lam bai thi)\b/,
  /\b(thoi tiet|du bao thoi tiet|cong thuc nau|nau an|tu vi|boi bai|bong da|ket qua tran|lich chieu phim|review phim)\b/,
  /\bke chuyen cuoi\b/,
];

const FINANCE_ANCHORS = [
  'tien', 'chi tieu', 'thu nhap', 'ngan sach', 'tiet kiem', 'vay', 'tra no', 'khoan no', 'con no', 'lai suat',
  'dau tu', 'thue', 'luong', 'hoa don', 'giao dich', 'muc tieu', 'bao hiem', 'tai chinh', 'ngan hang',
  'tai khoan', 'so du', 'chung khoan', 'co phieu', 'bat dong san', 'quy khan cap', 'dong tien',
];

function hasFinanceAnchor(normalized) {
  return FINANCE_ANCHORS.some((w) => new RegExp(`\\b${w}\\b`).test(normalized));
}

/**
 * @param {unknown} message
 * @returns {{ allowed: true } | { allowed: false, code: 'OFF_TOPIC'|'INJECTION', refusalText: string }}
 */
function checkScope(message) {
  if (typeof message !== 'string' || !message.trim()) return { allowed: true };
  const text = normalize(message);

  if (INJECTION_PATTERNS.some((re) => re.test(text))) {
    return { allowed: false, code: 'INJECTION', refusalText: SCOPE_REFUSAL_TEXT };
  }
  if (OFF_TOPIC_PATTERNS.some((re) => re.test(text)) && !hasFinanceAnchor(text)) {
    return { allowed: false, code: 'OFF_TOPIC', refusalText: SCOPE_REFUSAL_TEXT };
  }
  return { allowed: true };
}

module.exports = { checkScope, SCOPE_REFUSAL_TEXT };
