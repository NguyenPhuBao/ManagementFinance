/**
 * Content Filter Utility (Nghị định 13/2023/NĐ-CP & An toàn thông tin)
 * 1. Kiểm duyệt lý do khóa tài khoản (Reason_Inactive): Chặn PII và từ ngữ xúc phạm/thô tục.
 * 2. Làm sạch trường ghi chú (Note): Loại bỏ số thẻ tín dụng, CVV và mật khẩu.
 */

// Danh sách từ ngữ xúc phạm, thô tục, lăng mạ (Tiếng Việt & Tiếng Anh)
const PROFANITY_BLACKLIST = [
  // Tiếng Việt
  'địt', 'đụ', 'lồn', 'cặc', 'buồi', 'đĩ', 'mất dạy', 'khốn nạn',
  'thằng chó', 'chó đẻ', 'đồ chó', 'con điếm', 'óc chó', 'ngu ngốc',
  'đồ ngu', 'lừa đảo', 'ăn cắp', 'ăn cướp', 'mạt hạng',
  // Tiếng Anh
  'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'cunt', 'dick',
  'motherfucker', 'scam', 'scammer', 'thief',
];

/**
 * Kiểm tra xem văn bản có chứa PII (Thông tin định danh cá nhân) hay không:
 * - Số điện thoại (9-11 chữ số)
 * - Địa chỉ Email
 * - Số CMND/CCCD (9 hoặc 12 chữ số)
 * - Số thẻ ngân hàng (13-19 chữ số)
 * @param {string} text 
 * @returns {{ hasPII: boolean, piiType?: string }}
 */
function checkPII(text) {
  if (!text || typeof text !== 'string') return { hasPII: false };

  // 1. Email Regex
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/;
  if (emailRegex.test(text)) {
    return { hasPII: true, piiType: 'Địa chỉ Email' };
  }

  // 2. Số điện thoại Regex (Việt Nam: 03x, 05x, 07x, 08x, 09x, +84)
  const phoneRegex = /(?:\+84|0)[1-9][0-9]{8,9}\b/;
  if (phoneRegex.test(text)) {
    return { hasPII: true, piiType: 'Số điện thoại' };
  }

  // 3. Số thẻ ngân hàng (13-19 chữ số liên tục hoặc có dấu cách)
  const cardRegex = /\b(?:\d[ -]*?){13,19}\b/;
  const cardMatch = text.match(cardRegex);
  if (cardMatch) {
    const digitsOnly = cardMatch[0].replace(/[\s-]/g, '');
    if (digitsOnly.length >= 13 && digitsOnly.length <= 19) {
      return { hasPII: true, piiType: 'Số thẻ hoặc số tài khoản ngân hàng' };
    }
  }

  // 4. Số CCCD/CMND (9 hoặc 12 chữ số liên tục)
  const idCardRegex = /\b\d{9}\b|\b\d{12}\b/;
  if (idCardRegex.test(text)) {
    return { hasPII: true, piiType: 'Số CCCD/CMND' };
  }

  return { hasPII: false };
}

/**
 * Kiểm tra xem văn bản có chứa từ ngữ xúc phạm hay không
 * @param {string} text 
 * @returns {boolean}
 */
function checkProfanity(text) {
  if (!text || typeof text !== 'string') return false;
  const lower = text.toLowerCase();

  return PROFANITY_BLACKLIST.some(word => {
    // Regex ranh giới từ hoặc cụm từ
    const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`(^|\\s|[.,!?;])${escaped}($|\\s|[.,!?;])`, 'i');
    return regex.test(lower);
  });
}

/**
 * Xác thực lý do khóa tài khoản (Reason_Inactive)
 * Bắt buộc: Không được rỗng, không chứa PII, không chứa từ ngữ xúc phạm
 * @param {string} reason 
 * @returns {{ valid: boolean, error?: string }}
 */
function validateReasonInactive(reason) {
  if (!reason || typeof reason !== 'string' || !reason.trim()) {
    return { valid: false, error: 'Vui lòng cung cấp lý do vô hiệu hóa tài khoản!' };
  }

  const trimmed = reason.trim();
  if (trimmed.length < 5) {
    return { valid: false, error: 'Lý do vô hiệu hóa quá ngắn (tối thiểu 5 ký tự)!' };
  }
  if (trimmed.length > 500) {
    return { valid: false, error: 'Lý do vô hiệu hóa vượt quá độ dài cho phép (tối đa 500 ký tự)!' };
  }

  // Kiểm tra PII
  const piiResult = checkPII(trimmed);
  if (piiResult.hasPII) {
    return {
      valid: false,
      error: `Lý do khóa tài khoản không được phép chứa thông tin định danh cá nhân (${piiResult.piiType})!`,
    };
  }

  // Kiểm tra từ ngữ xúc phạm
  if (checkProfanity(trimmed)) {
    return {
      valid: false,
      error: 'Lý do khóa tài khoản chứa từ ngữ không phù hợp hoặc mang tính xúc phạm!',
    };
  }

  return { valid: true };
}

/**
 * Thuật toán Luhn kiểm tra số thẻ ngân hàng (Mod 10 check)
 * @param {string} digits 
 * @returns {boolean}
 */
function luhnOk(digits) {
  if (typeof digits !== 'string') return false;
  const clean = digits.replace(/\D/g, '');
  if (clean.length < 13 || clean.length > 19) return false;
  let sum = 0;
  let alternate = false;
  for (let i = clean.length - 1; i >= 0; i--) {
    let n = parseInt(clean.charAt(i), 10);
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 === 0;
}

const CARD_SHAPE = /\b(?:\d{13,19}|\d{4}(?:[ -]\d{4}){3}(?:[ -]\d{3})?|\d{4}[ -]\d{6}[ -]\d{5})\b/g;

/**
 * Lọc và làm sạch nội dung ghi chú (Note) do người dùng tự nhập hoặc OCR/Bank sync
 * Tự động loại bỏ số thẻ ngân hàng (vượt qua Luhn check), CVV hoặc mật khẩu để bảo vệ người dùng.
 * Không lọc nhầm từ 'pin' (vd: thay pin, pin sạc) và các mã giao dịch thông thường.
 * @param {string|null} note 
 * @returns {string|null}
 */
function filterSensitiveNote(note) {
  if (!note || typeof note !== 'string') return note;
  let cleaned = note;

  // 1. Loại bỏ số thẻ tín dụng/ghi nợ (13-19 chữ số thỏa mãn thuật toán Luhn)
  cleaned = cleaned.replace(CARD_SHAPE, (match) => {
    const digitsOnly = match.replace(/[\s-]/g, '');
    if (digitsOnly.length >= 13 && digitsOnly.length <= 19 && luhnOk(digitsOnly)) {
      return '[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]';
    }
    return match;
  });

  // 2. Loại bỏ mã bảo mật CVV/CVC
  cleaned = cleaned.replace(/(?:cvv|cvc)\s*[:=]?\s*(\d{3,4})\b/giu, 'CVV: [ĐÃ LƯỢC BỎ]');

  // 3. Loại bỏ mật khẩu dạng rõ nếu ghi vào note (bắt buộc có dấu phân cách : hoặc =)
  // Tuyệt đối không dùng từ khóa 'pin' đơn lẻ để tránh bắt nhầm "Thay pin: 350000"
  cleaned = cleaned.replace(/(?:mật khẩu|mat khau|password|passcode|pwd)\s*[:=]\s*([^\s,;]+)/giu, 'Mật khẩu: [ĐÃ LƯỢC BỎ]');

  return cleaned;
}

module.exports = {
  checkPII,
  checkProfanity,
  validateReasonInactive,
  filterSensitiveNote,
  luhnOk,
};

