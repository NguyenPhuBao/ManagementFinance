const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const config = require("../../config");
const { prisma } = require("../../config/db");
const authRepository = require("./auth.repository");
const emailService = require("../../core/email.service");
const logger = require("../../core/logger");

function hashToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}

function getTokenExpiry(idrole) {
  if (idrole === 1) {
    return {
      accessExpires: config.jwt.admin.accessExpires,
      refreshExpires: config.jwt.admin.refreshExpires,
    };
  }
  return {
    accessExpires: config.jwt.user.accessExpires,
    refreshExpires: config.jwt.user.refreshExpires,
  };
}

function generateTokens(payload, idrole) {
  const { accessExpires, refreshExpires } = getTokenExpiry(idrole);
  // Strip JWT standard claims to avoid conflict with expiresIn
  const cleanPayload = { ...payload };
  delete cleanPayload.exp;
  delete cleanPayload.iat;
  delete cleanPayload.iss;
  delete cleanPayload.sub;
  delete cleanPayload.aud;
  delete cleanPayload.nbf;
  delete cleanPayload.jti;
  // Add unique jti to ensure every token is unique (prevents hash collision)
  cleanPayload.jti = crypto.randomUUID();
  const accessToken = jwt.sign(cleanPayload, config.jwt.accessSecret, { expiresIn: accessExpires });
  const refreshToken = jwt.sign(cleanPayload, config.jwt.refreshSecret, { expiresIn: refreshExpires });
  logger.debug('Tokens generated', { jti: cleanPayload.jti, accessHash: hashToken(accessToken).substring(0,8), refreshHash: hashToken(refreshToken).substring(0,8) });
  return { accessToken, refreshToken };
}

function getDeviceInfo(req) {
  const headers = (req && req.headers) ? req.headers : {};
  const userAgent = headers["user-agent"] || null;
  return {
    ip_address: (req && req.ip) || null,
    user_agent: userAgent,
    device_name: (userAgent || "").substring(0, 100),
  };
}

async function saveRefreshToken(token, payload, req) {
  const decoded = jwt.decode(token);
  const device = getDeviceInfo(req);
  const th = hashToken(token);
  logger.debug('Saving refresh token', { hashPrefix: th.substring(0,8), idaccount: payload.idaccount });
  return prisma.refreshtoken.create({
    data: {
      token_hash: hashToken(token),
      idaccount: payload.idaccount,
      idrole: payload.idrole,
      expiry: new Date(decoded.exp * 1000),
      ip_address: device.ip_address,
      user_agent: device.user_agent,
      device_name: device.device_name,
    },
  });
}

const authService = {
  // ---------- REGISTER OTP: SEND OTP ----------
  async sendRegisterOtp(data) {
    // 1. Kiểm tra username đã tồn tại chưa
    const existingUsername = await authRepository.findAccountByUsername(data.username);
    if (existingUsername) {
      throw Object.assign(new Error("Username đã được sử dụng"), { statusCode: 409 });
    }

    // 2. Kiểm tra email đã tồn tại chưa
    const existingEmail = await authRepository.findAccountByEmail(data.email);
    if (existingEmail) {
      throw Object.assign(new Error("Email đã được sử dụng"), { statusCode: 409 });
    }

    // 3. Sinh mã OTP 6 số ngẫu nhiên
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 phút

    // 4. Lưu vào bảng otp_code với idaccount = null, purpose = 'register'
    await authRepository.createOtp(data.email, null, codeHash, 'register', expiresAt);

    // 5. Gửi email OTP
    await emailService.sendOtp(data.email, otp, 'register');
    logger.info("Register OTP sent", { email: data.email, username: data.username });

    return {
      message: "Mã OTP đã được gửi đến email của bạn. Hiệu lực 10 phút.",
    };
  },

  // ---------- REGISTER OTP: VERIFY OTP & CREATE ACCOUNT ----------
  async verifyRegisterOtp(data, req) {
    if (!req) req = {};

    // 1. Hash OTP đầu vào
    const codeHash = hashOtp(data.otp);

    // 2. Tìm OTP record hợp lệ theo email và purpose = 'register'
    const record = await authRepository.findValidOtpByEmail(data.email, codeHash, 'register');
    if (!record) {
      throw Object.assign(new Error("Mã OTP không hợp lệ hoặc đã hết hạn"), { statusCode: 400 });
    }

    // 3. Đánh dấu OTP đã sử dụng
    await authRepository.markOtpUsed(record.id_otp);

    // 4. Kiểm tra lại race condition (tránh trường hợp username/email bị đăng ký trong lúc chờ nhập OTP)
    const existingUsername = await authRepository.findAccountByUsername(data.username);
    if (existingUsername) {
      throw Object.assign(new Error("Username đã được sử dụng"), { statusCode: 409 });
    }

    const existingEmail = await authRepository.findAccountByEmail(data.email);
    if (existingEmail) {
      throw Object.assign(new Error("Email đã được sử dụng"), { statusCode: 409 });
    }

    // 5. Hash mật khẩu
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(data.password, salt);

    // 6. Tạo account + user trong transaction
    const account = await authRepository.createAccountWithUser({
      username: data.username,
      hashedPassword,
      fullname: data.fullname,
      email: data.email,
      phone: data.phone || null,
    });

    // 7. Tạo JWT payload
    const payload = {
      idaccount: account.idaccount,
      username: account.username,
      idrole: account.idrole,
      rolename: account.role.rolename,
    };

    // 8. Generate tokens & lưu refresh token
    const { accessToken, refreshToken } = generateTokens(payload, 2);
    await saveRefreshToken(refreshToken, payload, req);

    logger.info("User registered via OTP successfully", { username: account.username, idaccount: account.idaccount });

    return {
      accessToken,
      refreshToken,
      user: {
        idaccount: account.idaccount,
        username: account.username,
        rolename: account.role.rolename,
        fullname: account.User.fullname,
        email: account.User.email,
      },
    };
  },

  // ---------- REGISTER (User - Deprecated, giữ tương thích) ----------
  async register(data, req) {
    if (!req) req = {};

    // 1. Kiem tra username da ton tai
    const existingUsername = await authRepository.findAccountByUsername(data.username);
    if (existingUsername) {
      throw Object.assign(new Error("Username da duoc su dung"), { statusCode: 409 });
    }

    // 2. Kiem tra email da ton tai
    const existingEmail = await authRepository.findAccountByEmail(data.email);
    if (existingEmail) {
      throw Object.assign(new Error("Email da duoc su dung"), { statusCode: 409 });
    }

    // 3. Hash mat khau truoc khi luu
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(data.password, salt);

    // 4. Tao account + user trong transaction
    const account = await authRepository.createAccountWithUser({
      username: data.username,
      hashedPassword,
      fullname: data.fullname,
      email: data.email,
      phone: data.phone || null,
    });

    // 5. Tao JWT payload
    const payload = {
      idaccount: account.idaccount,
      username: account.username,
      idrole: account.idrole,
      rolename: account.role.rolename,
    };

    // 6. Generate tokens (user role = 2)
    const { accessToken, refreshToken } = generateTokens(payload, 2);
    await saveRefreshToken(refreshToken, payload, req);

    logger.info("User registered", { username: account.username, idaccount: account.idaccount });

    return {
      accessToken,
      refreshToken,
      user: {
        idaccount: account.idaccount,
        username: account.username,
        rolename: account.role.rolename,
        fullname: account.User.fullname,
        email: account.User.email,
      },
    };
  },
  async login(username, password, req) {
    if (!req) req = {};
    const account = await authRepository.findAccountByUsername(username);
    if (!account) throw Object.assign(new Error("Sai tai khoan hoac mat khau"), { statusCode: 401 });

    let pendingDeleteCancelled = false;

    if (account.status === 'PendingDelete') {
      if (account.delete_at && account.delete_at > new Date()) {
        // Còn trong 30 ngày → cho đăng nhập, tự động hủy yêu cầu xóa
        const isMatch = await bcrypt.compare(password, account.password);
        if (!isMatch) throw Object.assign(new Error("Sai tai khoan hoac mat khau"), { statusCode: 401 });

        await authRepository.cancelDeletion(account.idaccount);
        pendingDeleteCancelled = true;
        logger.info("PendingDelete account recovered on login", { username: account.username });
      } else {
        // Hết 30 ngày → từ chối đăng nhập
        throw Object.assign(
          new Error("Tài khoản đã hết thời gian khôi phục (30 ngày). Vui lòng liên hệ hỗ trợ."),
          { statusCode: 403 }
        );
      }
    } else if (account.status === 'Deleted') {
      throw Object.assign(new Error("Tài khoản đã bị xóa vĩnh viễn"), { statusCode: 403 });
    } else if (account.status !== 'Active') {
      throw Object.assign(new Error("Tai khoan da bi vo hieu hoa"), { statusCode: 403 });
    }

    if (!pendingDeleteCancelled) {
      const isMatch = await bcrypt.compare(password, account.password);
      if (!isMatch) throw Object.assign(new Error("Sai tai khoan hoac mat khau"), { statusCode: 401 });
    }

    const payload = {
      idaccount: account.idaccount,
      username: account.username,
      idrole: account.idrole,
      rolename: account.role.rolename,
    };

    const { accessToken, refreshToken } = generateTokens(payload, account.idrole);
    await saveRefreshToken(refreshToken, payload, req);

    logger.info("User logged in", { username: account.username, idrole: account.idrole });

    return {
      accessToken,
      refreshToken,
      pendingDeleteCancelled,
      user: {
        idaccount: account.idaccount,
        username: account.username,
        rolename: account.role.rolename,
        fullname: account.User ? account.User.fullname : "",
        email: account.User ? account.User.email : "",
      },
    };
  },

  async refresh(oldRefreshToken, req) {
    if (!req) req = {};
    if (!oldRefreshToken) throw Object.assign(new Error("Thieu refresh token"), { statusCode: 400 });

    const tokenHash = hashToken(oldRefreshToken);
    const storedToken = await prisma.refreshtoken.findUnique({ where: { token_hash: tokenHash } });

    if (!storedToken || storedToken.revoked) {
      if (storedToken && storedToken.revoked) {
        await prisma.refreshtoken.updateMany({
          where: { idaccount: storedToken.idaccount, revoked: false },
          data: { revoked: true },
        });
        logger.warn("Reused revoked refresh token - all tokens revoked", { idaccount: storedToken.idaccount });
      }
      throw Object.assign(new Error("Refresh token khong hop le"), { statusCode: 401 });
    }

    if (new Date() > new Date(storedToken.expiry)) {
      await prisma.refreshtoken.update({ where: { idtoken: storedToken.idtoken }, data: { revoked: true } });
      throw Object.assign(new Error("Refresh token da het han, vui long dang nhap lai"), { statusCode: 401 });
    }

    let payload;
    try {
      payload = jwt.verify(oldRefreshToken, config.jwt.refreshSecret);
    } catch (err) {
      await prisma.refreshtoken.update({ where: { idtoken: storedToken.idtoken }, data: { revoked: true } });
      throw Object.assign(new Error("Refresh token khong hop le"), { statusCode: 401 });
    }

    await prisma.refreshtoken.update({ where: { idtoken: storedToken.idtoken }, data: { revoked: true } });

    const { accessToken, refreshToken } = generateTokens(payload, payload.idrole);
    await saveRefreshToken(refreshToken, payload, req);

    logger.info("Token refreshed", { idaccount: payload.idaccount });
    return { accessToken, refreshToken };
  },

  async revokeAllTokens(idaccount) {
    const result = await prisma.refreshtoken.updateMany({
      where: { idaccount, revoked: false },
      data: { revoked: true },
    });
    logger.info("All tokens revoked", { idaccount, count: result.count });
    return result.count;
  },

  // ---------- CHANGE PASSWORD ----------
  async changePassword(idaccount, currentPassword, newPassword) {
    const account = await authRepository.findAccountById(idaccount);
    if (!account) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

    const isMatch = await bcrypt.compare(currentPassword, account.password);
    if (!isMatch) throw Object.assign(new Error("Mật khẩu hiện tại không đúng"), { statusCode: 400 });

    const salt = await bcrypt.genSalt(10);
    const hashedNew = await bcrypt.hash(newPassword, salt);
    await authRepository.updatePassword(idaccount, hashedNew);

    await this.revokeAllTokens(idaccount);
    logger.info("Password changed, all tokens revoked", { idaccount });
  },

  // ---------- FORGOT PASSWORD ----------
  async forgotPassword(email) {
    const accountRecord = await authRepository.findAccountByEmail(email);
    if (!accountRecord) return; // Không tiết lộ email có tồn tại hay không

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // CSDL mới: OTP cần idaccount (FK)
    await authRepository.createOtp(email, accountRecord.idaccount, codeHash, 'reset_password', expiresAt);
    await emailService.sendOtp(email, otp, 'reset_password');
    logger.info("OTP sent for forgot password", { email, idaccount: accountRecord.idaccount });
  },

  // ---------- VERIFY OTP ----------
  async verifyOtp(email, otp) {
    const codeHash = hashOtp(otp);
    // CSDL mới: tra OTP theo idaccount → tìm account từ email trước
    const accountRecord = await authRepository.findAccountByEmail(email);
    if (!accountRecord) throw Object.assign(new Error("Email không tồn tại"), { statusCode: 400 });

    const record = await authRepository.findValidOtp(accountRecord.idaccount, codeHash, 'reset_password');
    if (!record) throw Object.assign(new Error("Mã OTP không hợp lệ hoặc đã hết hạn"), { statusCode: 400 });

    await authRepository.markOtpUsed(record.id_otp);

    const resetToken = jwt.sign({ email, idaccount: accountRecord.idaccount, purpose: 'reset_password' }, config.jwt.accessSecret, { expiresIn: '15m' });
    logger.info("OTP verified, reset token issued", { email });
    return resetToken;
  },

  // ---------- RESET PASSWORD ----------
  async resetPassword(resetToken, newPassword) {
    let payload;
    try {
      payload = jwt.verify(resetToken, config.jwt.accessSecret);
    } catch {
      throw Object.assign(new Error("Token không hợp lệ hoặc đã hết hạn"), { statusCode: 401 });
    }
    if (payload.purpose !== 'reset_password') throw Object.assign(new Error("Token không hợp lệ"), { statusCode: 401 });

    const accountRecord = await authRepository.findAccountByEmail(payload.email);
    if (!accountRecord) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

    const idaccount = accountRecord.idaccount;
    const salt = await bcrypt.genSalt(10);
    const hashedNew = await bcrypt.hash(newPassword, salt);

    await authRepository.updatePassword(idaccount, hashedNew);
    await this.revokeAllTokens(idaccount);
    logger.info("Password reset successfully", { email: payload.email });
  },

  // ---------- DELETE ACCOUNT ----------
  async deleteAccount(idaccount, password) {
    const account = await authRepository.findAccountById(idaccount);
    if (!account) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

    const isMatch = await bcrypt.compare(password, account.password);
    if (!isMatch) throw Object.assign(new Error("Mật khẩu không đúng"), { statusCode: 400 });

    await authRepository.scheduleDeletion(idaccount);
    await this.revokeAllTokens(idaccount);
    logger.info("Account scheduled for deletion (30 days grace period)", { idaccount });
  },

  // ---------- CANCEL DELETION ----------
  async cancelDeletion(idaccount) {
    const account = await authRepository.findAccountById(idaccount);
    if (!account) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

    if (account.status !== 'PendingDelete') {
      throw Object.assign(new Error("Tài khoản không ở trạng thái chờ xóa"), { statusCode: 400 });
    }
    if (account.delete_at && account.delete_at <= new Date()) {
      throw Object.assign(new Error("Đã hết thời gian khôi phục (30 ngày)"), { statusCode: 403 });
    }

    await authRepository.cancelDeletion(idaccount);
    logger.info("Account deletion cancelled by user", { idaccount });
  },

  // ---------- GET PROFILE ----------
  async getProfile(idaccount) {
    const user = await authRepository.getProfile(idaccount);
    if (!user) throw Object.assign(new Error("Không tìm thấy thông tin người dùng"), { statusCode: 404 });
    return {
      fullname: user.fullname,
      email: user.email,
      phone: user.phone,
      address: user.address,
      country_code: user.country_code,
    };
  },

  // ---------- UPDATE PROFILE ----------
  async updateProfile(idaccount, data) {
    const allowed = {};
    if (data.fullname !== undefined) allowed.fullname = data.fullname;
    if (data.phone !== undefined) allowed.phone = data.phone;
    if (data.address !== undefined) allowed.address = data.address;
    if (data.country_code !== undefined) allowed.country_code = data.country_code;

    const updated = await authRepository.updateProfile(idaccount, allowed);
    return {
      fullname: updated.fullname,
      email: updated.email,
      phone: updated.phone,
      address: updated.address,
      country_code: updated.country_code,
    };
  },

  // ---------- REQUEST EMAIL CHANGE ----------
  async requestEmailChange(idaccount, newEmail) {
    const existing = await authRepository.findAccountByEmail(newEmail);
    if (existing) throw Object.assign(new Error("Email này đã được sử dụng bởi tài khoản khác"), { statusCode: 409 });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // CSDL mới: OTP cần idaccount
    await authRepository.createOtp(newEmail, idaccount, codeHash, 'change_email', expiresAt);
    await emailService.sendOtp(newEmail, otp, 'change_email');
    logger.info("OTP sent for email change", { newEmail, idaccount });
  },

  // ---------- CONFIRM EMAIL CHANGE ----------
  async confirmEmailChange(idaccount, newEmail, otp) {
    const codeHash = hashOtp(otp);
    const record = await authRepository.findValidOtp(idaccount, codeHash, 'change_email');
    if (!record) throw Object.assign(new Error("Mã OTP không hợp lệ hoặc đã hết hạn"), { statusCode: 400 });

    await authRepository.markOtpUsed(record.id_otp);
    // CSDL mới: updateEmail đồng bộ cả 2 bảng (Account.Email + User.Email)
    await authRepository.updateEmail(idaccount, newEmail);

    // Thu hồi token để user phải đăng nhập lại với email mới (optional, nhưng an toàn hơn)
    await this.revokeAllTokens(idaccount);

    logger.info("Email changed successfully", { newEmail, idaccount });
  },

  // ---------- AUDIT LOG HELPERS ----------
  determineReqStatus(res, req) {
    if (req.auditStatus) {
      return req.auditStatus;
    }
    const statusCode = res.statusCode || 200;
    if (statusCode >= 200 && statusCode < 300) {
      return 'Pass';
    }
    if (statusCode === 400 || statusCode === 401 || statusCode === 403 || statusCode === 429) {
      return 'Rejected';
    }
    if (statusCode >= 500) {
      return 'Fail';
    }
    return 'Pass';
  },

  formatActionName(method, path) {
    const p = (path || '').toLowerCase();
    const m = (method || 'GET').toUpperCase();

    if (p.includes('/auth/login')) return 'Đăng nhập hệ thống';
    if (p.includes('/auth/register')) return 'Đăng ký tài khoản';
    if (p.includes('/auth/logout')) return 'Đăng xuất';
    if (p.includes('/auth/refresh')) return 'Làm mới phiên đăng nhập';
    if (p.includes('/auth/forgot-password')) return 'Yêu cầu đặt lại mật khẩu';
    if (p.includes('/auth/verify-otp')) return 'Xác thực mã OTP';
    if (p.includes('/auth/reset-password')) return 'Đặt lại mật khẩu';
    if (p.includes('/auth/change-password')) return 'Đổi mật khẩu';
    if (p.includes('/auth/profile') && m === 'PUT') return 'Cập nhật hồ sơ';
    if (p.includes('/auth/profile') && m === 'GET') return 'Xem thông tin cá nhân';

    if (p.includes('/sync/push')) return 'Đồng bộ dữ liệu (Push)';
    if (p.includes('/sync/pull')) return 'Tải dữ liệu đồng bộ (Pull)';
    if (p.includes('/sync/full')) return 'Đồng bộ toàn bộ dữ liệu';

    if (p.includes('/bank/sync')) return 'Đồng bộ giao dịch ngân hàng';
    if (p.includes('/bank/webhook')) return 'Webhook biến động số dư';
    if (p.includes('/bank/connect') || p.includes('/bank/link')) return 'Liên kết tài khoản ngân hàng';

    if (p.includes('/ai/chat')) return 'Hỏi đáp trợ lý tài chính AI';
    if (p.includes('/ai/classify')) return 'Phân loại giao dịch AI';

    if (p.includes('/admin/updatestatus')) return 'Khóa/mở khóa tài khoản';
    if (p.includes('/admin/addcategory')) return 'Tạo danh mục hệ thống';
    if (p.includes('/admin/updatecategory')) return 'Cập nhật danh mục hệ thống';
    if (p.includes('/admin/deletecategory')) return 'Xóa danh mục hệ thống';

    return `${m} ${path}`;
  },

  async recordAuditLog(data) {
    try {
      const reqStatus = data.req_status || 'Pass';
      const log = await authRepository.createAuditLog({
        idaccount: data.idaccount,
        request: data.request,
        req_status: reqStatus,
        time_req: data.time_req,
        time_res: data.time_res,
      });

      // Format time string
      const date = new Date(data.time_req || Date.now());
      const hours = date.getHours().toString().padStart(2, '0');
      const minutes = date.getMinutes().toString().padStart(2, '0');
      const timeFormatted = `${hours}:${minutes}`;

      // Emit real-time event to Admin-web
      const { emitAuditActivity } = require('../../core/socket');
      emitAuditActivity({
        id: log.idlog,
        idaccount: data.idaccount,
        user: data.userDetails?.fullname || data.userDetails?.username || `User #${data.idaccount}`,
        action: data.request,
        status: reqStatus,
        time: timeFormatted,
        time_req: log.time_req,
        time_res: log.time_res,
      });

      return log;
    } catch (err) {
      logger.error('Failed to record audit log', { error: err.message, idaccount: data.idaccount });
    }
  },

  async getRecentActivities(limit = 10) {
    const logs = await authRepository.getRecentAuditLogs(limit);
    return logs.map((log) => {
      const date = new Date(log.time_req);
      const hours = date.getHours().toString().padStart(2, '0');
      const minutes = date.getMinutes().toString().padStart(2, '0');
      const timeFormatted = `${hours}:${minutes}`;

      return {
        id: log.idlog,
        idaccount: log.idaccount,
        user: log.account?.User?.fullname || log.account?.username || `User #${log.idaccount}`,
        action: log.request,
        status: log.req_status || 'Pass',
        time: timeFormatted,
        time_req: log.time_req,
        time_res: log.time_res,
      };
    });
  },
};

module.exports = authService;