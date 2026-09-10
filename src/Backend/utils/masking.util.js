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

module.exports = {
  maskEmail,
  maskPhone,
  maskAccountNumber,
  maskFullname,
  maskAddress,
};
