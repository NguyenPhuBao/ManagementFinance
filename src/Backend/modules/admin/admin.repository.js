const { randomUUID } = require('crypto');
const { prisma } = require('../../config/db');
const { encrypt, isEncrypted } = require('../../utils/crypto.util');

const adminRepository = {
  async countUsers() {
    return prisma.user.count({
      where: {
        delete_at: null,
        account: { idrole: 2, delete_at: null },
      },
    });
  },

  async countCategories() {
    return prisma.category.count({
      where: { delete_at: null },
    });
  },

  async countUsersByRange(start, end) {
    return prisma.user.count({
      where: {
        delete_at: null,
        account: { idrole: 2, delete_at: null },
        create_at: {
          gte: start,
          lte: end,
        },
      },
    });
  },

  async getAllUsers() {
    return prisma.user.findMany({
      where: {
        account: { idrole: 2 },
      },
      select: {
        iduser: true,
        fullname: true,
        email: true,
        phone: true,
        address: true,
        country_code: true,
        create_at: true,
        update_at: true,
        delete_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            status: true,
            type: true,
            reason_inactive: true,
            countdown: true,
            delete_at: true,
            update_at: true,
          },
        },
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async getUserById(iduser) {
    return prisma.user.findUnique({
      where: { iduser, account: { idrole: 2 } },
      select: {
        iduser: true,
        fullname: true,
        email: true,
        phone: true,
        address: true,
        country_code: true,
        create_at: true,
        update_at: true,
        delete_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            status: true,
            type: true,
            idrole: true,
            reason_inactive: true,
            countdown: true,
            delete_at: true,
            update_at: true,
            role: { select: { rolename: true } },
          },
        },
      },
    });
  },

  async updateAccountStatus(iduser, newStatus, reasonInactive = null) {
    return prisma.user.update({
      where: { iduser, account: { idrole: 2 } },
      data: {
        account: {
          update: {
            status: newStatus,
            reason_inactive: reasonInactive,
            update_at: new Date(),
          },
        },
        update_at: new Date(),
      },
      select: {
        iduser: true,
        fullname: true,
        account: {
          select: {
            username: true,
            status: true,
            type: true,
            reason_inactive: true,
          },
        },
      },
    });
  },

  async softDeleteUser(iduser) {
    const user = await prisma.user.findUnique({
      where: { iduser },
      select: {
        iduser: true,
        idaccount: true,
        account: { select: { idaccount: true, idrole: true, status: true, username: true } },
      },
    });
    if (!user) return null;

    const idaccount = user.idaccount;
    const now = new Date();

    return prisma.$transaction(async (tx) => {
      // 1. Soft delete account
      const updatedAccount = await tx.account.update({
        where: { idaccount },
        data: {
          status: 'Deleted',
          countdown: 0,
          delete_at: now,
          update_at: now,
        },
      });

      // 2. Soft delete user
      const updatedUser = await tx.user.update({
        where: { iduser },
        data: {
          delete_at: now,
          update_at: now,
        },
      });

      // 3. Toàn bộ ví liên quan ngừng hoạt động (status = 'Inactive')
      await tx.wallet.updateMany({
        where: { idaccount, delete_at: null },
        data: {
          status: 'Inactive',
          update_at: now,
        },
      });

      // 4. Dữ liệu ngân hàng không bị xóa, ngắt kết nối (connect_status = 'Disconnected')
      await tx.bank_account.updateMany({
        where: { idaccount },
        data: {
          connect_status: 'Disconnected',
        },
      });

      // 5. Thu hồi toàn bộ token ngay lập tức (status = true)
      await tx.refreshtoken.updateMany({
        where: { idaccount },
        data: {
          status: true,
          update_at: now,
        },
      });

      return {
        user: updatedUser,
        account: updatedAccount,
      };
    });
  },

  async getAllCategories(filters = {}) {
    // Nguyên tắc bảo mật: Admin chỉ quản lý danh mục mặc định của hệ thống (is_default = true)
    // Tuyệt đối không query hoặc trả về danh mục riêng tư của người dùng
    const where = {
      is_default: true,
    };

    if (filters.status === 'active') {
      where.delete_at = null;
    } else if (filters.status === 'deleted') {
      where.delete_at = { not: null };
    }

    if (filters.keyword && typeof filters.keyword === 'string' && filters.keyword.trim()) {
      where.OR = [
        { name_category: { contains: filters.keyword.trim(), mode: 'insensitive' } },
        { keyword: { contains: filters.keyword.trim(), mode: 'insensitive' } },
      ];
    }

    if (filters.classify && filters.classify !== 'all' && filters.classify !== '') {
      where.classify = filters.classify;
    }

    return prisma.category.findMany({
      where,
      select: {
        idcategory: true,
        create_by: true,
        name_category: true,
        classify: true,
        is_default: true,
        is_group: true,
        idgroup: true,
        keyword: true,
        icon: true,
        create_at: true,
        update_at: true,
        delete_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            User: { select: { fullname: true } },
          },
        },
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async createCategory(data) {
    return prisma.category.create({
      data: {
        idcategory: randomUUID(),
        create_by: data.created_by,
        name_category: data.name,
        classify: data.classify,
        is_default: data.is_default || false,
        keyword: data.keyword || null,
        icon: data.icon || null,
        update_at: new Date(),
      },
    });
  },

  async updateCategory(idcategory, data) {
    return prisma.category.update({
      where: { idcategory },
      data: {
        name_category: data.name,
        classify: data.classify,
        is_default: data.is_default,
        keyword: data.keyword,
        icon: data.icon,
        update_at: new Date(),
      },
    });
  },

  async deleteCategory(idcategory) {
    // Xóa mềm danh mục hệ thống: bảo toàn 100% dữ liệu và cấu trúc liên kết (không unlink idgroup của category con)
    return prisma.category.update({
      where: { idcategory },
      data: {
        delete_at: new Date(),
        update_at: new Date(),
        server_update_at: new Date(),
      },
    });
  },

  async restoreCategory(idcategory) {
    // Khôi phục danh mục hệ thống: bỏ cờ xóa mềm và giữ nguyên 100% mọi dữ liệu hiện có
    return prisma.category.update({
      where: { idcategory },
      data: {
        delete_at: null,
        update_at: new Date(),
        server_update_at: new Date(),
      },
    });
  },

  async getLoginLogsByRange(startDate, endDate) {
    return prisma.auditlog.findMany({
      where: {
        request: { contains: 'Đăng nhập' },
        time_req: {
          gte: startDate,
          lte: endDate,
        },
      },
      select: {
        idlog: true,
        time_req: true,
        req_status: true,
      },
      orderBy: { time_req: 'asc' },
    });
  },

  async getRequestLogsByRange(startDate, endDate) {
    return prisma.auditlog.findMany({
      where: {
        time_req: {
          gte: startDate,
          lte: endDate,
        },
      },
      select: {
        idlog: true,
        time_req: true,
        req_status: true,
      },
      orderBy: { time_req: 'asc' },
    });
  },

  async queryAuditLogs({ page = 1, limit = 50, status, search, startDate, endDate } = {}) {
    const safeLimit = Math.min(parseInt(limit, 10) || 50, 200);
    const safePage = Math.max(parseInt(page, 10) || 1, 1);
    const skip = (safePage - 1) * safeLimit;
    const where = {};
    if (status) where.req_status = status;
    if (search) {
      where.OR = [
        { request: { contains: search, mode: 'insensitive' } },
        { action: { contains: search, mode: 'insensitive' } },
        { account: { username: { contains: search, mode: 'insensitive' } } },
      ];
    }
    if (startDate || endDate) {
      where.time_req = {};
      if (startDate) where.time_req.gte = new Date(startDate);
      if (endDate) where.time_req.lte = new Date(endDate);
    }
    const [rows, total] = await Promise.all([
      prisma.auditlog.findMany({
        where,
        orderBy: { time_req: 'desc' },
        skip,
        take: safeLimit,
        select: {
          idlog: true,
          idaccount: true,
          request: true,
          action: true,
          req_status: true,
          reason: true,
          time_req: true,
          time_res: true,
          account: {
            select: {
              username: true,
              refreshtoken: {
                select: { ip_address: true },
                orderBy: { create_at: 'desc' },
                take: 1,
              },
            },
          },
        },
      }),
      prisma.auditlog.count({ where }),
    ]);
    return {
      items: rows.map((l) => ({
        id: l.idlog,
        idlog: l.idlog,
        idaccount: l.idaccount,
        username: l.account?.username || null,
        account: {
          username: l.account?.username || null,
        },
        ip: l.account?.refreshtoken?.[0]?.ip_address || '127.0.0.1',
        request: l.request,
        action: l.action || l.request,
        req_status: l.req_status,
        status: l.req_status,
        reason: l.reason,
        timeReq: l.time_req,
        timeRes: l.time_res,
        time_req: l.time_req,
        time_res: l.time_res,
      })),
      total,
    };
  },

  async getAccountById(idaccount) {
    return prisma.account.findUnique({
      where: { idaccount: Number(idaccount) },
      select: {
        idaccount: true,
        password: true,
        pin_hash: true,
        username: true,
        email: true,
        idrole: true,
        is_first_login: true,
      },
    });
  },

  async updateAccountPin(idaccount, pinHash) {
    return prisma.account.update({
      where: { idaccount: Number(idaccount) },
      data: {
        pin_hash: pinHash,
        update_at: new Date(),
      },
    });
  },

  async updateFirstLoginSetup(idaccount, passwordHash, pinHash) {
    return prisma.account.update({
      where: { idaccount: Number(idaccount) },
      data: {
        password: passwordHash,
        pin_hash: pinHash,
        is_first_login: false,
        update_at: new Date(),
      },
      include: {
        role: { select: { idrole: true, rolename: true } },
        User: { select: { fullname: true, email: true, phone: true } },
      },
    });
  },

  async updateAccountPassword(idaccount, passwordHash) {
    return prisma.account.update({
      where: { idaccount: Number(idaccount) },
      data: {
        password: passwordHash,
        update_at: new Date(),
      },
    });
  },

  async findAccountByUsernameOrEmail(username, email) {
    return prisma.account.findFirst({
      where: {
        OR: [
          { username: { equals: username, mode: 'insensitive' } },
          { email: { equals: email, mode: 'insensitive' } },
        ],
      },
    });
  },

  async createAdminAccount({
    username,
    email,
    passwordHash,
    pinHash,
    createdByAdminId,
    fullName,
    phone,
    address,
    countryCode,
  }) {
    const rawPhone = phone ? String(phone).trim() : null;
    const rawAddress = address ? String(address).trim() : null;
    const rawCountryCode = countryCode ? String(countryCode).trim().slice(0, 4) : '+84';
    const rawFullName = fullName && String(fullName).trim() ? String(fullName).trim() : `Quản trị viên ${username.trim()}`;

    // Mã hóa số điện thoại & địa chỉ AES-256-GCM để tuân thủ trigger CSDL trg_check_phone_encrypted & Nghị định 13
    const encPhone = rawPhone ? encrypt(rawPhone) : null;
    const encAddress = rawAddress ? encrypt(rawAddress) : null;

    return prisma.$transaction(async (tx) => {
      const newAccount = await tx.account.create({
        data: {
          username: username.trim(),
          email: email.trim(),
          password: passwordHash,
          pin_hash: pinHash,
          idrole: 1, // Admin role
          status: 'Active',
          type: 'Basic',
          is_first_login: true,
          created_by_admin_id: createdByAdminId ? Number(createdByAdminId) : null,
          create_at: new Date(),
          update_at: new Date(),
        },
      });

      const newUser = await tx.User.create({
        data: {
          idaccount: newAccount.idaccount,
          fullname: rawFullName,
          email: email.trim(),
          phone: encPhone,
          address: encAddress,
          country_code: rawCountryCode,
          create_at: new Date(),
          update_at: new Date(),
        },
      });

      return {
        idaccount: newAccount.idaccount,
        username: newAccount.username,
        email: newAccount.email,
        fullname: newUser.fullname,
        phone: rawPhone,
        address: rawAddress,
        country_code: newUser.country_code,
        idrole: newAccount.idrole,
        status: newAccount.status,
        is_first_login: newAccount.is_first_login,
        created_by_admin_id: newAccount.created_by_admin_id,
        create_at: newAccount.create_at,
      };
    });
  },
};

module.exports = adminRepository;
