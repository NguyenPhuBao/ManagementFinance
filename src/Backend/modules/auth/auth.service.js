const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const config = require("../../config");
const { prisma } = require("../../config/db");
const authRepository = require("./auth.repository");
const logger = require("../../core/logger");

function hashToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
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
    if (account.status !== "Active") throw Object.assign(new Error("Tai khoan da bi vo hieu hoa"), { statusCode: 403 });
    const isMatch = await bcrypt.compare(password, account.password);
    if (!isMatch) throw Object.assign(new Error("Sai tai khoan hoac mat khau"), { statusCode: 401 });

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
};

module.exports = authService;