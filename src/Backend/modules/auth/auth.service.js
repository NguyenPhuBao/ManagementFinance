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
  return {
    ip_address: req.ip || null,
    user_agent: req.headers["user-agent"] || null,
    device_name: (req.headers["user-agent"] || "").substring(0, 100),
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
  // ---------- REGISTER (User) ----------
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
      if (account.scheduled_delete_at && account.scheduled_delete_at > new Date()) {
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
    const userRecord = await authRepository.findAccountByEmail(email);
    if (!userRecord) return; // Không tiết lộ email có tồn tại hay không

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await authRepository.createOtp(email, codeHash, 'reset_password', expiresAt);
    await emailService.sendOtp(email, otp, 'reset_password');
    logger.info("OTP sent for forgot password", { email });
  },

  // ---------- VERIFY OTP ----------
  async verifyOtp(email, otp) {
    const codeHash = hashOtp(otp);
    const record = await authRepository.findValidOtp(email, codeHash, 'reset_password');
    if (!record) throw Object.assign(new Error("Mã OTP không hợp lệ hoặc đã hết hạn"), { statusCode: 400 });

    await authRepository.markOtpUsed(record.id);

    const resetToken = jwt.sign({ email, purpose: 'reset_password' }, config.jwt.accessSecret, { expiresIn: '15m' });
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

    const userRecord = await authRepository.findAccountByEmail(payload.email);
    if (!userRecord) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

    const idaccount = userRecord.account.idaccount;
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
    if (account.scheduled_delete_at && account.scheduled_delete_at <= new Date()) {
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
      location: user.location,
    };
  },

  // ---------- UPDATE PROFILE ----------
  async updateProfile(idaccount, data) {
    const allowed = {};
    if (data.fullname !== undefined) allowed.fullname = data.fullname;
    if (data.phone !== undefined) allowed.phone = data.phone;
    if (data.address !== undefined) allowed.address = data.address;
    if (data.location !== undefined) allowed.location = data.location;

    const updated = await authRepository.updateProfile(idaccount, allowed);
    return {
      fullname: updated.fullname,
      email: updated.email,
      phone: updated.phone,
      address: updated.address,
      location: updated.location,
    };
  },

  // ---------- REQUEST EMAIL CHANGE ----------
  async requestEmailChange(idaccount, newEmail) {
    const existing = await authRepository.findAccountByEmail(newEmail);
    if (existing) throw Object.assign(new Error("Email này đã được sử dụng bởi tài khoản khác"), { statusCode: 409 });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await authRepository.createOtp(newEmail, codeHash, 'change_email', expiresAt);
    await emailService.sendOtp(newEmail, otp, 'change_email');
    logger.info("OTP sent for email change", { newEmail, idaccount });
  },

  // ---------- CONFIRM EMAIL CHANGE ----------
  async confirmEmailChange(idaccount, newEmail, otp) {
    const codeHash = hashOtp(otp);
    const record = await authRepository.findValidOtp(newEmail, codeHash, 'change_email');
    if (!record) throw Object.assign(new Error("Mã OTP không hợp lệ hoặc đã hết hạn"), { statusCode: 400 });

    await authRepository.markOtpUsed(record.id);
    await authRepository.updateEmail(idaccount, newEmail);
    
    // Thu hồi token để user phải đăng nhập lại với email mới (optional, nhưng an toàn hơn)
    await this.revokeAllTokens(idaccount);
    
    logger.info("Email changed successfully", { newEmail, idaccount });
  },
};

module.exports = authService;