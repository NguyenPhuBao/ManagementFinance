const crypto = require('crypto');
const { prisma } = require('../../config/db');
const payosClient = require('./payos.client');
const logger = require('../../core/logger');

/**
 * Chuyển đổi các trường BigInt trong object thành Number để an toàn khi serialize JSON
 * @param {object} obj 
 * @returns {object}
 */
function sanitizeOrderData(obj) {
  if (!obj) return null;
  const clone = { ...obj };
  if (typeof clone.order_code === 'bigint') {
    clone.order_code = Number(clone.order_code);
  }
  if (typeof clone.amount === 'object' && clone.amount !== null && typeof clone.amount.toNumber === 'function') {
    clone.amount = clone.amount.toNumber();
  }
  if (typeof clone.amount_received === 'object' && clone.amount_received !== null && typeof clone.amount_received.toNumber === 'function') {
    clone.amount_received = clone.amount_received.toNumber();
  }
  if (typeof clone.fee === 'object' && clone.fee !== null && typeof clone.fee.toNumber === 'function') {
    clone.fee = clone.fee.toNumber();
  }
  if (typeof clone.refunded_amount === 'object' && clone.refunded_amount !== null && typeof clone.refunded_amount.toNumber === 'function') {
    clone.refunded_amount = clone.refunded_amount.toNumber();
  }

  // Đồng bộ trạng thái và loại bỏ QR/checkout URL nếu đơn đã hết hạn hoặc không còn PENDING
  const isPastExpiry = clone.expired_at && new Date(clone.expired_at) <= new Date();
  if (clone.status === 'PENDING' && isPastExpiry) {
    clone.status = 'EXPIRED';
  }
  if (clone.status !== 'PENDING') {
    clone.checkout_url = null;
    clone.qr_url = null;
  }

  return clone;
}

/**
 * Tự động quét và cập nhật trạng thái EXPIRED cho các đơn hàng PENDING đã quá hạn
 * Xóa vĩnh viễn qr_url và checkout_url trong CSDL để tránh người dùng chuyển khoản lại
 */
async function autoExpirePendingOrders() {
  const now = new Date();
  try {
    const result = await prisma.payment_order.updateMany({
      where: {
        status: 'PENDING',
        OR: [
          { expired_at: { lte: now } },
          {
            expired_at: null,
            created_at: { lte: new Date(now.getTime() - 10 * 60 * 1000) },
          },
        ],
      },
      data: {
        status: 'EXPIRED',
        checkout_url: null,
        qr_url: null,
      },
    });
    return result?.count || 0;
  } catch (err) {
    console.warn('[PAYMENT] Lỗi khi autoExpirePendingOrders:', err.message);
    return 0;
  }
}

/**
 * Tạo mới đơn hàng thanh toán
 * @param {object} data
 */
async function createOrder(data) {
  let pkgType = data.packageType || 'Premium';
  if (typeof pkgType === 'string' && pkgType.toUpperCase().startsWith('PREMIUM')) {
    pkgType = 'Premium';
  }
  const created = await prisma.payment_order.create({
    data: {
      id: data.id,
      idaccount: data.idaccount,
      order_code: BigInt(data.orderCode),
      package_type: pkgType,
      amount: data.amount,
      amount_received: data.amountReceived || 0,
      fee: data.fee || 0,
      recognition_code: data.recognitionCode || null,
      transfer_content: data.transferContent || null,
      currency: data.currency || 'VND',
      status: data.status || 'PENDING',
      checkout_url: data.checkoutUrl || null,
      qr_url: data.qrUrl || null,
      payment_link_id: data.paymentLinkId || null,
      expired_at: data.expiredAt || null,
      is_template: data.isTemplate ?? false,
    },
  });
  return sanitizeOrderData(created);
}

/**
 * Tìm đơn hàng theo mã orderCode (PayOS)
 * @param {number|string|bigint} orderCode 
 */
async function findOrderByCode(orderCode) {
  await autoExpirePendingOrders();
  const order = await prisma.payment_order.findUnique({
    where: {
      order_code: BigInt(orderCode),
    },
    include: {
      account: {
        select: {
          idaccount: true,
          username: true,
          email: true,
          type: true,
          premium_expires_at: true,
        },
      },
    },
  });
  return sanitizeOrderData(order);
}

/**
 * Tìm đơn hàng theo orderCode, nếu chưa có thì tự động khởi tạo đơn đối soát từ Webhook PayOS hợp lệ
 * @param {number|string} orderCode 
 * @param {number} amount 
 * @param {string} packageType 
 */
async function findOrCreateOrderByCode(orderCode, amount, packageType = 'Premium') {
  const existingOrder = await findOrderByCode(orderCode);
  if (existingOrder) {
    return existingOrder;
  }

  // Tra cứu tài khoản admin hoặc tài khoản mặc định đang hoạt động
  const targetAccount = await prisma.account.findFirst({
    where: { delete_at: null },
    orderBy: { idaccount: 'asc' },
  });
  const accountId = targetAccount ? targetAccount.idaccount : 1;
  const orderId = crypto.randomUUID();
  const now = new Date();

  const createdOrder = await prisma.payment_order.create({
    data: {
      id: orderId,
      idaccount: accountId,
      order_code: BigInt(orderCode),
      package_type: packageType,
      amount: Number(amount) || 49000,
      currency: 'VND',
      status: 'PENDING',
      created_at: now,
      expired_at: new Date(now.getTime() + 30 * 60 * 1000),
    },
    include: {
      account: {
        select: {
          idaccount: true,
          username: true,
          email: true,
          type: true,
          premium_expires_at: true,
        },
      },
    },
  });

  return sanitizeOrderData(createdOrder);
}

/**
 * Tìm đơn hàng theo ID (UUID)
 * @param {string} orderId 
 */
async function findOrderById(orderId) {
  await autoExpirePendingOrders();
  const order = await prisma.payment_order.findUnique({
    where: { id: orderId },
  });
  return sanitizeOrderData(order);
}

/**
 * Lấy danh sách lịch sử đơn hàng của tài khoản kèm phân trang
 * @param {number} idaccount 
 * @param {object} options 
 */
async function findOrdersByAccount(idaccount, { page = 1, limit = 20 } = {}) {
  await autoExpirePendingOrders();
  const skip = (Math.max(1, page) - 1) * limit;
  const where = { idaccount, is_template: false };
  const [total, items] = await Promise.all([
    prisma.payment_order.count({ where }),
    prisma.payment_order.findMany({
      where,
      orderBy: { created_at: 'desc' },
      skip,
      take: limit,
    }),
  ]);

  return {
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit) || 1,
    items: items.map(sanitizeOrderData),
  };
}

/**
 * Cập nhật trạng thái đơn hàng
 * @param {string} orderId 
 * @param {object} updateData 
 */
async function updateOrderStatus(orderId, updateData) {
  const data = { ...updateData };
  if (data.status && data.status !== 'PENDING') {
    data.checkout_url = null;
    data.qr_url = null;
  }
  const updated = await prisma.payment_order.update({
    where: { id: orderId },
    data,
  });
  return sanitizeOrderData(updated);
}

/**
 * Cập nhật trạng thái đối soát tức thì (JIT Sync) từ PayOS và triệt tiêu QR khi đơn bị hủy/hết hạn
 * @param {string} orderId 
 * @param {object} updateData 
 */
async function updateOrderSyncStatus(orderId, updateData) {
  const data = { ...updateData };
  if (data.status && data.status !== 'PENDING') {
    data.checkout_url = null;
    data.qr_url = null;
  }
  const updated = await prisma.payment_order.update({
    where: { id: orderId },
    data,
  });
  return sanitizeOrderData(updated);
}

/**
 * Cập nhật trạng thái đối soát đơn hàng (WAITING_CONFIRMATION, REFUND_PENDING, PAID...)
 */
async function updateOrderPaymentStatus({ orderId, status, amountReceived, paidAt, transferContent, refundReason, fee }) {
  const data = {};
  if (status !== undefined) {
    data.status = status;
    if (status !== 'PENDING') {
      data.checkout_url = null;
      data.qr_url = null;
    }
  }
  if (amountReceived !== undefined) data.amount_received = amountReceived;
  if (paidAt !== undefined) data.paid_at = paidAt;
  if (transferContent !== undefined) data.transfer_content = transferContent;
  if (refundReason !== undefined) data.refund_reason = refundReason;
  if (fee !== undefined) data.fee = fee;

  const updated = await prisma.payment_order.update({
    where: { id: orderId },
    data,
  });
  return sanitizeOrderData(updated);
}

/**
 * Tìm đơn hàng theo mã nhận diện 6 ký tự
 * @param {string} recognitionCode
 */
/**
 * Tìm đơn hàng theo mã nhận diện 6 ký tự
 * @param {string} recognitionCode
 * @param {object} options
 */
async function findOrderByRecognitionCode(recognitionCode, { status = 'PENDING' } = {}) {
  if (!recognitionCode) return null;
  const where = {
    recognition_code: recognitionCode.trim(),
  };
  if (status) {
    where.status = status;
  }
  const order = await prisma.payment_order.findFirst({
    where,
    orderBy: { created_at: 'desc' },
    include: {
      account: {
        select: {
          idaccount: true,
          username: true,
          email: true,
          type: true,
          premium_expires_at: true,
        },
      },
    },
  });
  return sanitizeOrderData(order);
}

/**
 * Xử lý hoàn tiền đơn hàng (Admin)
 */
async function processRefund({ orderId, idaccount, refundedAmount, refundProof, refundReason, refundedAt, bankReference, adminId }) {
  // Một giao tác: ghi dòng sổ tiền RA (bất biến) + chốt đơn REFUNDED (trigger khoá đơn sau đó).
  const { ledgerRow } = require('./payment.ledger');
  const updated = await prisma.$transaction(async (tx) => {
    await tx.payment_transaction.create({
      data: ledgerRow({
        id: crypto.randomUUID(),
        orderId,
        idaccount,
        payosTransactionId: bankReference,
        amount: refundedAmount,
        transactionTime: refundedAt,
        signatureVerified: false,
        direction: 'OUT',
        source: 'ADMIN_REFUND',
        transferDescription: refundReason ? String(refundReason).slice(0, 255) : null,
        currency: 'VND',
        createdBy: adminId,
        proof: refundProof,
      }),
    });
    return tx.payment_order.update({
      where: { id: orderId },
      data: {
        status: 'REFUNDED',
        refunded_at: refundedAt,
        refunded_amount: refundedAmount,
        refund_proof: refundProof || null,
        refund_reason: refundReason || null,
        checkout_url: null,
        qr_url: null,
      },
    });
  });
  return sanitizeOrderData(updated);
}

/**
 * Ghi nhận nhật ký giao dịch đối soát Webhook
 * @param {object} data 
 */
async function recordTransaction(data) {
  if (data.orderId) {
    const orderExists = await prisma.payment_order.findUnique({
      where: { id: data.orderId },
      select: { id: true },
    });
    if (!orderExists) {
      logger.info('[PAYMENT_REPO] Đơn hàng không tồn tại trong DB, bỏ qua ghi nhật ký đối soát:', data.orderId);
      return null;
    }
  }
  // Sổ giao dịch chỉ nhận dòng có mã giao dịch ngân hàng thật (migration 53: NOT NULL + duy nhất)
  if (!data.payosTransactionId) {
    logger.error('[PAYMENT_REPO] Từ chối ghi sổ: thiếu mã giao dịch ngân hàng', { orderId: data.orderId });
    return null;
  }
  const existingTx = await prisma.payment_transaction.findFirst({
    where: { payos_transaction_id: String(data.payosTransactionId) },
  });
  if (existingTx) {
    logger.info('[PAYMENT_REPO] Đã tồn tại giao dịch đối soát với payosTransactionId:', data.payosTransactionId);
    return existingTx;
  }
  try {
    const { ledgerRow } = require('./payment.ledger');
    return await prisma.payment_transaction.create({ data: ledgerRow(data) });
  } catch (err) {
    if (err.code === 'P2002' || err.message?.includes('23505') || err.message?.includes('unique')) {
      logger.info('[PAYMENT_REPO] Bắt trùng lặp giao dịch đối soát (Idempotency 23505):', data.payosTransactionId);
      return prisma.payment_transaction.findFirst({
        where: { payos_transaction_id: String(data.payosTransactionId) },
      });
    }
    if (err.code === 'P2003' || err.message?.includes('foreign key') || err.message?.includes('Foreign key')) {
      logger.warn('[PAYMENT_REPO] Bỏ qua ghi nhật ký đối soát do đơn hàng mock/không tồn tại khóa ngoại:', { error: err.message });
      return null;
    }
    throw err;
  }
}

/**
 * Kích hoạt nâng cấp gói Premium nguyên tử (Atomic Database Transaction)
 * Cập nhật order thành PAID, ghi payment_transaction, và cập nhật account thành Premium kèm premium_expires_at
 * @param {object} param0 
 */
async function activatePremiumSubscription({ idaccount, orderId, paidAt, newExpiresAt, transactionData }) {
  return prisma.$transaction(async (tx) => {
    // 1. Cập nhật trạng thái đơn hàng -> PAID và xóa mã QR, checkout link
    const order = await tx.payment_order.update({
      where: { id: orderId },
      data: {
        status: 'PAID',
        paid_at: paidAt || new Date(),
        amount_received: transactionData ? transactionData.amount : undefined,
        checkout_url: null,
        qr_url: null,
      },
    });

    // 2. Ghi sổ giao dịch (chỉ khi có mã giao dịch ngân hàng thật)
    if (transactionData && transactionData.payosTransactionId) {
      const existingTx = await tx.payment_transaction.findFirst({
        where: { payos_transaction_id: String(transactionData.payosTransactionId) },
      });
      if (!existingTx) {
        const { ledgerRow } = require('./payment.ledger');
        await tx.payment_transaction.createMany({
          data: [ledgerRow({ ...transactionData, orderId, idaccount })],
          skipDuplicates: true,
        });
      }
    }

    // 3. Nâng cấp loại tài khoản thành Premium và cập nhật ngày hết hạn
    const account = await tx.account.update({
      where: { idaccount },
      data: {
        type: 'Premium',
        premium_expires_at: newExpiresAt,
        update_at: new Date(),
      },
      select: {
        idaccount: true,
        username: true,
        email: true,
        type: true,
        premium_expires_at: true,
      },
    });

    return {
      order: sanitizeOrderData(order),
      account,
    };
  });
}

/**
 * Lấy thông tin subscription hiện tại của tài khoản
 * @param {number} idaccount 
 */
async function findAccountSubscription(idaccount) {
  return prisma.account.findUnique({
    where: { idaccount },
    select: {
      idaccount: true,
      username: true,
      email: true,
      type: true,
      premium_expires_at: true,
    },
  });
}

/**
 * Tìm các tài khoản Premium sắp hết hạn trong khoảng [now, now + withinDays]
 * @param {number} withinDays 
 */
async function findExpiringPremiumAccounts(withinDays = 3) {
  const now = new Date();
  const future = new Date(now.getTime() + withinDays * 24 * 60 * 60 * 1000);

  return prisma.account.findMany({
    where: {
      type: 'Premium',
      premium_expires_at: {
        gt: now,
        lte: future,
      },
    },
    select: {
      idaccount: true,
      username: true,
      email: true,
      premium_expires_at: true,
    },
  });
}

/**
 * Hạ cấp các tài khoản Premium đã quá hạn về Basic
 * @param {Date} now 
 * @returns {Promise<Array<{ idaccount: number, username: string, email: string }>>} Danh sách tài khoản vừa hạ cấp
 */
async function downgradeExpiredPremiumAccounts(now = new Date()) {
  const expiredAccounts = await prisma.account.findMany({
    where: {
      type: 'Premium',
      // Task 55.A3: hàng không có hạn là dữ liệu hỏng, cũng hạ về Basic
      OR: [{ premium_expires_at: { lte: now } }, { premium_expires_at: null }],
    },
    select: {
      idaccount: true,
      username: true,
      email: true,
      premium_expires_at: true,
    },
  });

  if (expiredAccounts.length === 0) {
    return [];
  }

  const ids = expiredAccounts.map((a) => a.idaccount);

  await prisma.account.updateMany({
    where: {
      idaccount: { in: ids },
    },
    data: {
      type: 'Basic',
      premium_expires_at: null,
      update_at: new Date(),
    },
  });

  // Ghi nhận lịch sử hết gói và chuyển về gói cơ bản vào CSDL (bảng payment_order)
  const historyOrders = expiredAccounts.map((acc, index) => ({
    id: crypto.randomUUID(),
    idaccount: acc.idaccount,
    order_code: BigInt(Date.now() * 1000 + Math.floor(Math.random() * 900) + 100 + index),
    package_type: 'Basic',
    amount: 0,
    amount_received: 0,
    fee: 0,
    currency: 'VND',
    status: 'EXPIRED',
    transfer_content: 'Hết hạn gói Premium, chuyển về gói cơ bản',
    recognition_code: 'EXP',
    created_at: now,
    expired_at: now,
    is_template: false,
  }));

  try {
    if (prisma.payment_order && typeof prisma.payment_order.createMany === 'function') {
      await prisma.payment_order.createMany({
        data: historyOrders,
      });
    }
  } catch (histErr) {
    logger.warn('[Payment] Lỗi ghi nhận lịch sử hết hạn gói:', { error: histErr.message });
  }

  return expiredAccounts;
}

/**
 * Lấy danh sách đơn hàng cho Admin kèm bộ lọc tìm kiếm và phân trang
 * @param {object} options
 */
async function findOrdersForAdmin({
  page = 1,
  limit = 20,
  search = '',
  status,
  packageType,
  fromDate,
  toDate,
  excludeTemplate = false,
  includeHidden = false,
} = {}) {
  await autoExpirePendingOrders();
  await downgradeExpiredPremiumAccounts();
  const currentPage = Math.max(1, parseInt(page, 10) || 1);
  const take = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
  const skip = (currentPage - 1) * take;

  const where = {};

  if (status && status !== 'ALL') {
    where.status = status;
  }

  if (packageType && packageType !== 'ALL') {
    if (packageType.toUpperCase() === 'PREMIUM') {
      where.package_type = { in: ['Premium', 'PREMIUM_1_MONTH', 'PREMIUM_6_MONTHS'] };
    } else {
      where.package_type = packageType;
    }
  }

  if (excludeTemplate === 'true' || excludeTemplate === true) {
    where.is_template = false;
  }

  // Đơn mẫu đã ẩn không hiện trong danh sách; xuất CSV (includeHidden) vẫn lấy đủ để tiền thật không biến mất khỏi báo cáo
  if (!(includeHidden === 'true' || includeHidden === true)) {
    where.AND = [{ OR: [{ is_template: false }, { hidden_at: null }] }];
  }

  if (fromDate || toDate) {
    where.created_at = {};
    if (fromDate) {
      where.created_at.gte = new Date(fromDate);
    }
    if (toDate) {
      const endOfDay = new Date(toDate);
      endOfDay.setHours(23, 59, 59, 999);
      where.created_at.lte = endOfDay;
    }
  }

  if (search && search.trim() !== '') {
    const trimmed = search.trim();
    const isNum = /^\d+$/.test(trimmed);

    const orConditions = [
      {
        account: {
          username: {
            contains: trimmed,
            mode: 'insensitive',
          },
        },
      },
      {
        account: {
          email: {
            contains: trimmed,
            mode: 'insensitive',
          },
        },
      },
      {
        account: {
          User: {
            fullname: {
              contains: trimmed,
              mode: 'insensitive',
            },
          },
        },
      },
    ];

    if (isNum) {
      orConditions.unshift({
        order_code: BigInt(trimmed),
      });
    }

    where.OR = orConditions;
  }

  const [total, items] = await Promise.all([
    prisma.payment_order.count({ where }),
    prisma.payment_order.findMany({
      where,
      orderBy: { created_at: 'desc' },
      skip,
      take,
      include: {
        account: {
          select: {
            idaccount: true,
            username: true,
            email: true,
            type: true,
            status: true,
            premium_expires_at: true,
            User: {
              select: {
                fullname: true,
              },
            },
          },
        },
      },
    }),
  ]);

  return {
    total,
    page: currentPage,
    limit: take,
    totalPages: Math.ceil(total / take) || 1,
    items: items.map((item) => {
      const sanitized = sanitizeOrderData(item);
      return sanitized;
    }),
  };
}

/**
 * Lấy thống kê tổng quan doanh thu và đơn hàng cho Admin
 * @param {object} options
 */
/**
 * Thống kê thanh toán cho Admin. Tiền thật nhận qua đơn thử nghiệm VẪN vào báo cáo, nhưng tách riêng:
 * revenue / orders / paid / refundPending / refunded = { total, user, template }; successRate chỉ tính đơn của người dùng.
 * Đơn đã ẩn vẫn được tính. Khoá cũ (totalRevenue, totalOrders, paidOrders…) giữ nghĩa "đơn người dùng" để tương thích.
 */
async function getPaymentSummaryStats({ fromDate, toDate } = {}) {
  await autoExpirePendingOrders();
  const base = {};
  if (fromDate || toDate) {
    base.created_at = {};
    if (fromDate) {
      base.created_at.gte = new Date(fromDate);
    }
    if (toDate) {
      const endOfDay = new Date(toDate);
      endOfDay.setHours(23, 59, 59, 999);
      base.created_at.lte = endOfDay;
    }
  }
  const money = (agg) => {
    const v = agg && agg._sum && agg._sum.amount;
    if (!v) return 0;
    return typeof v.toNumber === 'function' ? v.toNumber() : Number(v);
  };
  const group = async (isTemplate) => {
    const where = { ...base, is_template: isTemplate };
    const [total, paid, pending, cancelled, expired, refundPending, refunded, revenue] = await Promise.all([
      prisma.payment_order.count({ where }),
      prisma.payment_order.count({ where: { ...where, status: 'PAID' } }),
      prisma.payment_order.count({ where: { ...where, status: 'PENDING' } }),
      prisma.payment_order.count({ where: { ...where, status: 'CANCELLED' } }),
      prisma.payment_order.count({ where: { ...where, status: 'EXPIRED' } }),
      prisma.payment_order.count({ where: { ...where, status: 'REFUND_PENDING' } }),
      prisma.payment_order.count({ where: { ...where, status: 'REFUNDED' } }),
      prisma.payment_order.aggregate({ where: { ...where, status: 'PAID' }, _sum: { amount: true } }),
    ]);
    return { total, paid, pending, cancelled, expired, refundPending, refunded, revenue: money(revenue) };
  };
  const split = (key) => ({ total: user[key] + template[key], user: user[key], template: template[key] });
  const [user, template] = await Promise.all([group(false), group(true)]);
  const successRate = user.total > 0 ? Number(((user.paid / user.total) * 100).toFixed(2)) : 0;

  return {
    revenue: { total: user.revenue + template.revenue, user: user.revenue, template: template.revenue },
    orders: { total: user.total + template.total, user: user.total, template: template.total },
    paid: { total: user.paid + template.paid, user: user.paid, template: template.paid },
    refundPending: split('refundPending'),
    refunded: split('refunded'),
    successRate,
    // Khoá cũ: số liệu đơn người dùng
    totalRevenue: user.revenue,
    totalOrders: user.total,
    paidOrders: user.paid,
    pendingOrders: user.pending,
    cancelledOrders: user.cancelled,
    expiredOrders: user.expired,
  };
}

/**
 * Lấy chi tiết đơn hàng cho Admin kèm lịch sử đối soát giao dịch Webhook
 * @param {string} orderId
 */
async function getOrderDetailForAdmin(orderId) {
  await autoExpirePendingOrders();

  const order = await prisma.payment_order.findUnique({
    where: { id: orderId },
    include: {
      account: {
        select: {
          idaccount: true,
          username: true,
          email: true,
          type: true,
          status: true,
          premium_expires_at: true,
          User: {
            select: {
              fullname: true,
            },
          },
        },
      },
      payment_transaction: {
        orderBy: { transaction_time: 'desc' },
      },
    },
  });

  if (!order) return null;

  const sanitized = sanitizeOrderData(order);
  if (Array.isArray(sanitized.payment_transaction)) {
    sanitized.payment_transaction = sanitized.payment_transaction.map((tx) => {
      const txClone = { ...tx };
      if (txClone.amount && typeof txClone.amount.toNumber === 'function') {
        txClone.amount = txClone.amount.toNumber();
      }
      return txClone;
    });
  }

  if (!sanitized.expired_at && sanitized.created_at) {
    sanitized.expired_at = new Date(new Date(sanitized.created_at).getTime() + 10 * 60 * 1000);
  }

  const isPendingAndActive = sanitized.status === 'PENDING' && (!sanitized.expired_at || new Date(sanitized.expired_at) > new Date());

  if (isPendingAndActive) {
    // Đọc từ QR đã lưu của đơn, không ghi cứng tài khoản (đơn 62.1)
    const nhanTien = payosClient.thongTinTuQrUrl(sanitized.qr_url);
    sanitized.bank_info = nhanTien ? { ...nhanTien, bankName: tenNganHang(nhanTien.bin) } : null;
  } else {
    // Đơn hoàn tất hoặc đã hết hạn: Triệt tiêu mã QR và thông tin chuyển khoản tránh thanh toán trùng
    sanitized.qr_url = null;
    sanitized.checkout_url = null;
    sanitized.bank_info = null;
  }

  return sanitized;
}

/**
 * Tên ngân hàng theo mã BIN; chưa biết thì để trống để giao diện không ghi nhầm.
 * @param {string} bin
 */
function tenNganHang(bin) {
  return bin === '970422' ? 'MB Bank (Quân Đội)' : null;
}

/**
 * Lấy hoặc tạo mã QR thanh toán từ kênh PayOS thật
 * @param {object} param0 { amount, packageType }
 */
async function getOrCreatePayosQr({ amount = 49000, packageType = 'Premium', persistOrder = false, idaccount } = {}) {
  const orderCode = payosClient.generateOrderCode();
  const recognitionCode = payosClient.generateRecognitionCode();
  const now = new Date();
  const expiredAt = new Date(now.getTime() + 10 * 60 * 1000); // 10 phút đếm ngược

  // PayOS hỏng thì báo lỗi cho admin, không dựng QR đoán tài khoản (đơn 62.1)
  let payosRes;
  try {
    payosRes = await payosClient.createPaymentLink({
      orderCode,
      amount: Number(amount),
      description: recognitionCode,
      expiredAt: Math.floor(expiredAt.getTime() / 1000),
    });
  } catch (err) {
    const error = new Error(`Không thể tạo liên kết thanh toán PayOS: ${err.message}`);
    error.statusCode = 502;
    throw error;
  }
  const { bin, accountNumber, accountName, description: moTa } = payosClient.thongTinNhanTien(payosRes);
  const description = moTa || recognitionCode;
  const { checkoutUrl, paymentLinkId } = payosRes;
  const qrCode = payosRes.qrCode || null;

  // URL ảnh VietQR chuẩn Napas theo tài khoản PayOS trả về
  const qrUrl = `https://img.vietqr.io/image/${bin}-${accountNumber}-compact2.png?amount=${amount}&addInfo=${encodeURIComponent(description)}&accountName=${encodeURIComponent(accountName)}`;

  let orderId = crypto.randomUUID();

  // Tự động lưu bản ghi đơn hàng PENDING khi được yêu cầu (phục vụ đối soát tự động khi PayOS bắn Webhook về Cloud Backend)
  if (persistOrder) {
    try {
      let accountId = idaccount;
      if (!accountId) {
        const defaultAcc = await prisma.account.findFirst({
          where: { delete_at: null },
          orderBy: { idaccount: 'asc' },
          select: { idaccount: true },
        });
        accountId = defaultAcc ? defaultAcc.idaccount : 1;
      }
      await prisma.payment_order.create({
        data: {
          id: orderId,
          idaccount: accountId,
          order_code: BigInt(orderCode),
          package_type: packageType,
          amount: Number(amount),
          amount_received: 0,
          fee: 0,
          recognition_code: recognitionCode,
          transfer_content: description,
          currency: 'VND',
          status: 'PENDING',
          checkout_url: checkoutUrl,
          qr_url: qrUrl,
          payment_link_id: paymentLinkId,
          created_at: now,
          expired_at: expiredAt,
          is_template: true,
        },
      });
    } catch (dbErr) {
      console.warn('[PAYOS] Không thể lưu pending order cho sample QR:', dbErr.message);
    }
  }

  return {
    orderId,
    orderCode,
    recognitionCode,
    transferContent: description,
    amount: Number(amount),
    packageType,
    bin,
    bankName: tenNganHang(bin),
    accountNumber,
    accountName,
    description,
    checkoutUrl,
    paymentLinkId,
    qrUrl,
    qrCode,
    expiredAt,
  };
}

// Đơn mẫu: một mức cố định, hạn mức chung toàn hệ thống mỗi ngày (giờ Việt Nam). Chặn ở Backend, không tin body.
const SAMPLE_AMOUNT = 2000;
const SAMPLE_DAILY_LIMIT = 10;
const SAMPLE_LOCK_KEY = 530053; // khoá tư vấn PostgreSQL riêng cho việc đếm + tạo đơn mẫu

function vnDayRange(now = new Date()) {
  const p = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit' })
    .formatToParts(now)
    .reduce((acc, x) => ({ ...acc, [x.type]: x.value }), {});
  const start = new Date(`${p.year}-${p.month}-${p.day}T00:00:00+07:00`);
  return { start, end: new Date(start.getTime() + 24 * 3600 * 1000) };
}

async function countSampleOrdersOfDay(client, now = new Date()) {
  const { start, end } = vnDayRange(now);
  // Đếm cả đơn đã ẩn: ẩn chỉ là hiển thị, không trả lại lượt
  return client.payment_order.count({ where: { is_template: true, created_at: { gte: start, lt: end } } });
}

/**
 * Tạo đơn mẫu 2.000 đ gắn với admin tạo. Đếm hạn mức và tạo đơn trong cùng một giao tác có khoá,
 * nên nhiều yêu cầu đồng thời cũng không vượt hạn mức.
 * @param {{idaccount: number}} admin
 */
async function createSampleOrderLocked(admin) {
  const created = await prisma.$transaction(async (tx) => {
    // $executeRaw: pg_advisory_xact_lock trả kiểu void, $queryRaw không đọc được
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(${SAMPLE_LOCK_KEY})`;
    const used = await countSampleOrdersOfDay(tx);
    if (used >= SAMPLE_DAILY_LIMIT) {
      throw Object.assign(new Error(`Đã dùng hết ${SAMPLE_DAILY_LIMIT} đơn thử nghiệm hôm nay. Vui lòng thử lại vào ngày mai.`), {
        statusCode: 429,
        code: 'SAMPLE_DAILY_LIMIT',
      });
    }
    const payosInfo = await getOrCreatePayosQr({ amount: SAMPLE_AMOUNT, packageType: 'Premium' });
    const now = new Date();
    const order = await tx.payment_order.create({
      data: {
        id: crypto.randomUUID(),
        idaccount: Number(admin.idaccount),
        order_code: BigInt(payosInfo.orderCode),
        package_type: 'Premium',
        amount: SAMPLE_AMOUNT,
        currency: 'VND',
        status: 'PENDING',
        checkout_url: payosInfo.checkoutUrl,
        qr_url: payosInfo.qrUrl,
        payment_link_id: payosInfo.paymentLinkId,
        recognition_code: payosInfo.recognitionCode || null,
        transfer_content: payosInfo.transferContent || null,
        created_at: now,
        expired_at: new Date(now.getTime() + 10 * 60 * 1000),
        is_template: true,
      },
      include: {
        account: { select: { idaccount: true, username: true, email: true, type: true, User: { select: { fullname: true } } } },
      },
    });
    return { order, payosInfo };
  }, { maxWait: 30000, timeout: 30000 });

  const sanitized = sanitizeOrderData(created.order);
  const p = created.payosInfo;
  sanitized.qr_url = p.qrUrl;
  sanitized.qr_code = p.qrCode;
  sanitized.bank_info = {
    bin: p.bin,
    bankName: p.bankName,
    accountNumber: p.accountNumber,
    accountName: p.accountName,
    amount: p.amount,
    description: p.description,
    checkoutUrl: p.checkoutUrl,
  };
  return sanitized;
}

async function getSampleQuota(now = new Date()) {
  return { used: await countSampleOrdersOfDay(prisma, now), limit: SAMPLE_DAILY_LIMIT, amount: SAMPLE_AMOUNT };
}

/**
 * Lấy danh sách các gói cước từ CSDL (account_type_permission)
 */
async function getPackageTypes() {
  const permissions = await prisma.account_type_permission.findMany({
    select: { account_type: true },
    distinct: ['account_type'],
    orderBy: { account_type: 'asc' },
  });
  let types = permissions.map((p) => p.account_type).filter(Boolean);
  if (types.length === 0) {
    types = ['Basic', 'Premium'];
  }
  if (!types.includes('Basic')) types.unshift('Basic');
  if (!types.includes('Premium')) types.push('Premium');

  return types.map((type) => ({
    id: type,
    name: type === 'Basic' ? 'Gói Basic' : 'Gói Premium',
    isDefault: type === 'Basic',
  }));
}

module.exports = {
  createOrder,
  findOrderByCode,
  findOrderById,
  findOrdersByAccount,
  updateOrderStatus,
  updateOrderPaymentStatus,
  findOrderByRecognitionCode,
  processRefund,
  recordTransaction,
  activatePremiumSubscription,
  findAccountSubscription,
  findExpiringPremiumAccounts,
  downgradeExpiredPremiumAccounts,
  findOrdersForAdmin,
  getPaymentSummaryStats,
  getOrderDetailForAdmin,
  getPackageTypes,
  createSampleOrderLocked,
  getSampleQuota,
  SAMPLE_AMOUNT,
  SAMPLE_DAILY_LIMIT,
  getOrCreatePayosQr,
  findOrCreateOrderByCode,
  autoExpirePendingOrders,
  sanitizeOrderData,
  updateOrderSyncStatus,
};


