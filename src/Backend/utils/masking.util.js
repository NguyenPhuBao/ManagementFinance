/**
 * Masking Utility (Nghị định 13/2023/NĐ-CP & PCI-DSS v4.0)
 * Che bớt thông tin định danh cá nhân (PII) và dữ liệu tài chính khi hiển thị hoặc xuất báo cáo
 */

const { decrypt } = require('./crypto.util');

/**
 * Che địa chỉ Email
 * Giữ 2 ký tự đầu, thay phần còn lại của tên bằng ***, giữ nguyên tên miền
 * Ví dụ: phubao@gmail.com -> ph***@gmail.com
 *        ab@gmail.com -> a*@gmail.com
 * @param {string|null} email 
 * @returns {string|null}
 */
function maskEmail(email) {
  if (!email || typeof email !== 'string') return email;
  const parts = email.trim().split('@');
  if (parts.length !== 2) return email;

  const [name, domain] = parts;
  if (!name) return email;

  if (name.length <= 2) {
    return `${name[0]}*@${domain}`;
  }

  const prefix = name.substring(0, 2);
  return `${prefix}***@${domain}`;
}

/**
 * Che Số điện thoại
 * Giữ 3 số đầu và 3 số cuối, che 4 số giữa bằng ****
 * Ví dụ: 0987654321 -> 098****321
 *        +84987654321 -> +84****321
 * @param {string|null} phone 
 * @returns {string|null}
 */
function maskPhone(phone) {
  if (!phone || typeof phone !== 'string') return phone;
  // Tự động giải mã nếu là ciphertext
  const plain = decrypt(phone).trim();
  if (plain.length < 7) return plain;

  if (plain.startsWith('+84') && plain.length >= 11) {
    const end = plain.slice(-3);
    return `+84****${end}`;
  }

  if (plain.length >= 10) {
    const start = plain.substring(0, 3);
    const end = plain.slice(-3);
    return `${start}****${end}`;
  }

  // Trường hợp ngắn hơn 10 ký tự
  const start = plain.substring(0, 2);
  const end = plain.slice(-2);
  return `${start}****${end}`;
}

/**
 * Che Số tài khoản ngân hàng (Chuẩn PCI-DSS)
 * Chỉ hiển thị 4 số cuối, che các số đầu dạng **** **** **** 1234
 * Ví dụ: 123456789012 -> **** **** **** 9012
 * @param {string|null} accountNumber 
 * @returns {string|null}
 */
function maskAccountNumber(accountNumber) {
  if (!accountNumber || typeof accountNumber !== 'string') return accountNumber;
  const plain = decrypt(accountNumber).trim();
  if (plain.length < 4) return '****';

  const last4 = plain.slice(-4);
  return `**** **** **** ${last4}`;
}

/**
 * Che Họ tên người dùng khi xuất báo cáo công cộng
 * Giữ nguyên họ, viết tắt chữ cái đầu của tên đệm và tên chính
 * Ví dụ: Nguyễn Phú Bảo -> Nguyễn P. B.
 *        Trần Văn An -> Trần V. A.
 *        John Doe -> John D.
 * @param {string|null} fullname 
 * @returns {string|null}
 */
function maskFullname(fullname) {
  if (!fullname || typeof fullname !== 'string') return fullname;
  const parts = fullname.trim().split(/\s+/);
  if (parts.length <= 1) return fullname;

  const lastName = parts[0];
  const initials = parts.slice(1).map(p => `${p[0].toUpperCase()}.`).join(' ');
  return `${lastName} ${initials}`;
}

/**
 * Che Địa chỉ nhà
 * Ẩn số nhà và tên đường chi tiết, chỉ giữ lại đơn vị Phường/Xã, Quận/Huyện, Tỉnh/Thành phố
 * Ví dụ: 123 Đường Lê Lợi, Phường Bến Nghé, Quận 1, TP.HCM -> ***, Phường Bến Nghé, Quận 1, TP.HCM
 * @param {string|null} address 
 * @returns {string|null}
 */
function maskAddress(address) {
  if (!address || typeof address !== 'string') return address;
  const plain = decrypt(address).trim();
  const parts = plain.split(',');
  if (parts.length <= 1) return '***';

  const publicParts = parts.slice(1).map(p => p.trim()).join(', ');
  return `***, ${publicParts}`;
}

const { filterSensitiveNote } = require('./content-filter.util');

/**
 * Thoát các ký tự đặc biệt trong biểu thức chính quy
 */
function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Che bớt PII và dữ liệu nhạy cảm trong mô tả giao dịch trước khi gửi sang Cloud LLM
 * Tuân thủ Data_Security.md & Nghị định 13/2023/NĐ-CP
 * 1. Tự động giải mã nếu là ciphertext AES
 * 2. Lọc thẻ tín dụng (Luhn check), CVV, mật khẩu qua filterSensitiveNote
 * 3. Che OTP / mã xác thực
 * 4. Che email
 * 5. Che số điện thoại (VN format, kể cả có dấu cách, dấu chấm, dấu gạch nối)
 * 6. Che số CCCD/CMND (9 hoặc 12 chữ số) & Số tài khoản ngân hàng (9-19 số)
 * 7. Che họ tên người dùng nếu có cung cấp userName trong ngữ cảnh
 * @param {string} text 
 * @param {object} [options]
 * @param {string} [options.userName]
 * @returns {string}
 */
function maskTransactionDescription(text, options = {}) {
  if (!text || typeof text !== 'string') return '';

  let raw = text;
  // Tự động giải mã nếu text ở dạng chuỗi mã hóa hex AES (chứa dấu hai chấm iv:authTag:content)
  if (raw.includes(':') && raw.length > 32) {
    try {
      const decrypted = decrypt(raw);
      if (decrypted && decrypted !== raw) {
        raw = decrypted;
      }
    } catch (_) {
      // Giữ nguyên chuỗi nếu không phải ciphertext
    }
  }

  // 1. Loại bỏ số thẻ tín dụng (Luhn check), CVV, mật khẩu
  let safe = filterSensitiveNote(raw);

  // 2. Che mã OTP / mã xác thực
  safe = safe.replace(/(?:mã\s+otp|otp|mã\s+xác\s+thực|mã\s+xác\s+minh)(?:\s+(?:xác\s+thực|xác\s+minh))?(?:\s*[:=]\s*|\s+là\s+|\s+)(\d{4,8})\b/gi, 'OTP: [MÃ_BẢO_MẬT]');

  // 3. Che email
  safe = safe.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, '[EMAIL]');

  // 4. Che số điện thoại (kể cả có dấu cách, dấu gạch ngang, dấu chấm)
  safe = safe.replace(/(?:\+84|0)(?:[\s.-]?[1-9])(?:[\s.-]?\d){8,9}\b/g, '[SĐT]');

  // 5. Che số CCCD (12 chữ số) và CMND (9 chữ số)
  safe = safe.replace(/\b\d{12}\b/g, '[CCCD]');

  // 6. Che số tài khoản ngân hàng (dãy số 9-19 chữ số liên tục)
  safe = safe.replace(/\b\d{9,19}\b/g, '[STK]');

  // 7. Che họ tên người dùng nếu được cung cấp
  if (options && options.userName && typeof options.userName === 'string' && options.userName.trim().length >= 2) {
    const escapedName = escapeRegExp(options.userName.trim());
    safe = safe.replace(new RegExp(escapedName, 'gi'), '[TÊN_NGƯỜI_DÙNG]');
  }

  return safe;
}

/**
 * Che địa chỉ IP (Zero Raw IP theo Data_Security.md & Nghị định 13/2023/NĐ-CP)
 * Giữ 2 octet đầu cho IPv4 (xác định subnet/vùng/ISP), che 2 octet sau bằng xx.xx
 * Giữ 2 nhóm đầu cho IPv6, che các nhóm sau
 * Nếu không có IP hợp lệ -> trả về null
 * @param {string|null} rawIp 
 * @returns {string|null}
 */
function maskIp(rawIp) {
  if (!rawIp || typeof rawIp !== 'string') return null;
  const clean = rawIp.replace(/^::ffff:/, '').trim();
  if (!clean) return null;
  const v4Parts = clean.split('.');
  if (v4Parts.length === 4) {
    return `${v4Parts[0]}.${v4Parts[1]}.xx.xx`;
  }
  const v6Parts = clean.split(':');
  if (v6Parts.length > 2) {
    return `${v6Parts[0]}:${v6Parts[1]}:xxxx:xxxx`;
  }
  return 'xx.xx.xx.xx';
}

module.exports = {
  maskEmail,
  maskPhone,
  maskAccountNumber,
  maskFullname,
  maskAddress,
  maskTransactionDescription,
  maskIp,
};

