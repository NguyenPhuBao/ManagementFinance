const { prisma } = require('../../config/db');

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
  return clone;
}

/**
 * Tạo mới đơn hàng thanh toán
 * @param {object} data
 */
async function createOrder(data) {
  const created = await prisma.payment_order.create({
    data: {
      id: data.id,
      idaccount: data.idaccount,
      order_code: BigInt(data.orderCode),
      package_type: data.packageType || 'PREMIUM_1_MONTH',
      amount: data.amount,
      currency: data.currency || 'VND',
      status: data.status || 'PENDING',
      checkout_url: data.checkoutUrl || null,
      payment_link_id: data.paymentLinkId || null,
      expired_at: data.expiredAt || null,
    },
  });
  return sanitizeOrderData(created);
}

/**
 * Tìm đơn hàng theo mã orderCode (PayOS)
 * @param {number|string|bigint} orderCode 
 */
async function findOrderByCode(orderCode) {
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
 * Tìm đơn hàng theo ID (UUID)
 * @param {string} orderId 
 */
async function findOrderById(orderId) {
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
  const skip = (Math.max(1, page) - 1) * limit;
  const [total, items] = await Promise.all([
    prisma.payment_order.count({ where: { idaccount } }),
    prisma.payment_order.findMany({
      where: { idaccount },
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
  const updated = await prisma.payment_order.update({
    where: { id: orderId },
    data: updateData,
  });
  return sanitizeOrderData(updated);
}

/**
 * Ghi nhận nhật ký giao dịch đối soát Webhook
 * @param {object} data 
 */
async function recordTransaction(data) {
  return prisma.payment_transaction.create({
    data: {
      id: data.id,
      order_id: data.orderId,
      idaccount: data.idaccount,
      payos_transaction_id: data.payosTransactionId || null,
      amount: data.amount,
      bank_code: data.bankCode || null,
      transaction_time: data.transactionTime || new Date(),
      signature_verified: data.signatureVerified ?? true,
      raw_webhook_hash: data.rawWebhookHash || null,
    },
  });
}

/**
 * Kích hoạt nâng cấp gói Premium nguyên tử (Atomic Database Transaction)
 * Cập nhật order thành PAID, ghi payment_transaction, và cập nhật account thành Premium kèm premium_expires_at
 * @param {object} param0 
 */
async function activatePremiumSubscription({ idaccount, orderId, paidAt, newExpiresAt, transactionData }) {
  return prisma.$transaction(async (tx) => {
    // 1. Cập nhật trạng thái đơn hàng -> PAID
    const order = await tx.payment_order.update({
      where: { id: orderId },
      data: {
        status: 'PAID',
        paid_at: paidAt || new Date(),
      },
    });

    // 2. Ghi nhật ký giao dịch đối soát
    if (transactionData) {
      await tx.payment_transaction.create({
        data: {
          id: transactionData.id,
          order_id: orderId,
          idaccount,
          payos_transaction_id: transactionData.payosTransactionId || null,
          amount: transactionData.amount,
          bank_code: transactionData.bankCode || null,
          transaction_time: transactionData.transactionTime || new Date(),
          signature_verified: transactionData.signatureVerified ?? true,
          raw_webhook_hash: transactionData.rawWebhookHash || null,
        },
      });
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
      premium_expires_at: {
        lte: now,
      },
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

  return expiredAccounts;
}

module.exports = {
  createOrder,
  findOrderByCode,
  findOrderById,
  findOrdersByAccount,
  updateOrderStatus,
  recordTransaction,
  activatePremiumSubscription,
  findAccountSubscription,
  findExpiringPremiumAccounts,
  downgradeExpiredPremiumAccounts,
};
