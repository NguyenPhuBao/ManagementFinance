const ResponseHandler = require('../../core/response-handler');
const paymentService = require('./payment.service');
const logger = require('../../core/logger');

/**
 * Tạo đơn hàng mua gói Premium và lấy link thanh toán PayOS
 */
async function createOrder(req, res, next) {
  try {
    const idaccount = req.user && req.user.idaccount;
    if (!idaccount) {
      return ResponseHandler.unauthorized(res, 'Yêu cầu đăng nhập để thực hiện');
    }

    const { packageType } = req.body || {};
    const orderData = await paymentService.createPremiumOrder(idaccount, { packageType });

    return ResponseHandler.success(
      res,
      orderData,
      'Tạo đơn hàng thanh toán thành công',
      201
    );
  } catch (error) {
    logger.error('[PAYMENT_CONTROLLER] Lỗi khi tạo đơn hàng', { error: error.message });
    return next(error);
  }
}

/**
 * Xử lý Webhook gửi từ cổng thanh toán PayOS
 */
async function handleWebhook(req, res, next) {
  try {
    const result = await paymentService.handlePayOSWebhook(req.body);
    return res.status(200).json(result);
  } catch (error) {
    logger.warn('[PAYMENT_CONTROLLER] Lỗi xử lý Webhook PayOS', { error: error.message });
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
    }
    return next(error);
  }
}

/**
 * Lấy trạng thái đơn hàng theo mã orderCode
 */
async function getOrderStatus(req, res, next) {
  try {
    const idaccount = req.user && req.user.idaccount;
    const { orderCode } = req.params;
    const order = await paymentService.getOrderStatus(orderCode, idaccount);

    return ResponseHandler.success(res, order, 'Lấy trạng thái đơn hàng thành công');
  } catch (error) {
    if (error.statusCode === 404) {
      return ResponseHandler.notFound(res, error.message);
    }
    return next(error);
  }
}

/**
 * Lấy thông tin trạng thái gói cước của người dùng hiện tại
 */
async function getSubscriptionInfo(req, res, next) {
  try {
    const idaccount = req.user && req.user.idaccount;
    const info = await paymentService.getSubscriptionInfo(idaccount);

    return ResponseHandler.success(res, info, 'Lấy thông tin gói cước thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy lịch sử đơn hàng của người dùng (có phân trang)
 */
async function getOrderHistory(req, res, next) {
  try {
    const idaccount = req.user && req.user.idaccount;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;

    const history = await paymentService.getOrderHistory(idaccount, { page, limit });
    return ResponseHandler.success(res, history, 'Lấy lịch sử thanh toán thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy danh sách đơn hàng cho Admin kèm bộ lọc và phân trang
 */
async function getOrdersForAdmin(req, res, next) {
  try {
    const { page, limit, search, status, packageType, fromDate, toDate, excludeTemplate, includeHidden } = req.query;
    const result = await paymentService.getOrdersForAdmin({
      page,
      limit,
      search,
      status,
      packageType,
      fromDate,
      toDate,
      excludeTemplate,
      includeHidden,
    });
    return ResponseHandler.success(res, result, 'Lấy danh sách đơn hàng thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy thống kê tổng quan thanh toán cho Admin
 */
async function getPaymentStatsForAdmin(req, res, next) {
  try {
    const { fromDate, toDate, excludeTemplate } = req.query;
    const stats = await paymentService.getPaymentStatsForAdmin({ fromDate, toDate, excludeTemplate });
    return ResponseHandler.success(res, stats, 'Lấy thống kê thanh toán thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy chi tiết đơn hàng cho Admin
 */
async function getOrderDetailForAdmin(req, res, next) {
  try {
    const { id } = req.params;
    const order = await paymentService.getOrderDetailForAdmin(id);
    return ResponseHandler.success(res, order, 'Lấy chi tiết đơn hàng thành công');
  } catch (error) {
    if (error.statusCode === 404) {
      return ResponseHandler.notFound(res, error.message);
    }
    return next(error);
  }
}

/**
 * Tạo đơn thử nghiệm. Body chỉ nhận `{ pin }`: số tiền (2.000 đ), trạng thái, tài khoản đều do Backend quyết định.
 */
async function createSampleOrder(req, res, next) {
  try {
    const { pin } = req.body || {};
    try {
      const adminService = require('../admin/admin.service');
      await adminService.verifySecurityAction({ pin, action: 'CREATE_SAMPLE_ORDER', targetId: 'PAYMENT_SAMPLE' }, req.user);
    } catch (pinErr) {
      return ResponseHandler.error(res, pinErr.message, pinErr.statusCode || 400);
    }
    const order = await paymentService.createSampleOrder(req.user);
    return ResponseHandler.success(res, order, 'Tạo đơn hàng mẫu thử nghiệm thành công', 201);
  } catch (error) {
    if (error.code === 'SAMPLE_DAILY_LIMIT') return ResponseHandler.error(res, error.message, 429, null, error.code);
    return next(error);
  }
}

/** Hạn mức đơn thử nghiệm hôm nay: { used, limit, amount } */
async function getSampleQuota(req, res, next) {
  try {
    return ResponseHandler.success(res, await paymentService.getSampleQuota(), 'Hạn mức đơn thử nghiệm hôm nay');
  } catch (error) {
    return next(error);
  }
}

/**
 * Ẩn đơn thử nghiệm khỏi danh sách (giữ đường dẫn DELETE cũ). Không xoá dòng nào.
 */
async function deleteSampleOrders(req, res, next) {
  try {
    const result = await paymentService.hideSampleOrders(req.user);
    return ResponseHandler.success(res, result, 'Đã ẩn các đơn thử nghiệm khỏi danh sách (đơn vẫn được lưu)');
  } catch (error) {
    return next(error);
  }
}

/**
 * Người dùng xác nhận hoặc từ chối nâng cấp gói khi chuyển thừa tiền
 */
async function confirmUpgrade(req, res, next) {
  try {
    const idaccount = req.user && req.user.idaccount;
    const { orderCode, accept } = req.body;
    if (!orderCode) {
      return ResponseHandler.badRequest(res, 'Mã đơn hàng orderCode là bắt buộc');
    }
    if (typeof accept !== 'boolean') {
      return ResponseHandler.badRequest(res, 'Trường accept bắt buộc là kiểu boolean (true/false)');
    }
    const result = await paymentService.confirmUpgrade(idaccount, { orderCode, accept });
    return ResponseHandler.success(res, result, result.message);
  } catch (error) {
    if (error.statusCode === 400) return ResponseHandler.badRequest(res, error.message);
    if (error.statusCode === 404) return ResponseHandler.notFound(res, error.message);
    return next(error);
  }
}

/**
 * Admin xử lý hộ đơn chuyển thừa của khách. Quyền admin do `authorize('admin')` ở admin.routes.js kiểm,
 * nên không truyền idaccount: service bỏ phép so chủ đơn. Đừng nới phép so ở route của người dùng.
 */
async function confirmUpgradeByAdmin(req, res, next) {
  try {
    const { orderCode } = req.params;
    const { accept } = req.body || {};
    if (!/^\d+$/.test(orderCode)) {
      return ResponseHandler.badRequest(res, 'Mã đơn hàng không hợp lệ');
    }
    if (typeof accept !== 'boolean') {
      return ResponseHandler.badRequest(res, 'Trường accept bắt buộc là kiểu boolean (true/false)');
    }
    req.auditActionName = accept ? 'Admin đồng ý nâng cấp đơn chuyển thừa' : 'Admin từ chối nâng cấp đơn chuyển thừa';
    const result = await paymentService.confirmUpgrade(undefined, {
      orderCode,
      accept,
      lyDoTuChoi: 'Admin từ chối nâng cấp gói',
    });
    return ResponseHandler.success(res, result, result.message);
  } catch (error) {
    if (error.statusCode === 400) return ResponseHandler.badRequest(res, error.message);
    if (error.statusCode === 404) return ResponseHandler.notFound(res, error.message);
    return next(error);
  }
}

/**
 * Admin xử lý hoàn tiền cho khách hàng kèm upload minh chứng
 */
async function processRefund(req, res, next) {
  try {
    const { id } = req.params;
    const body = req.body || {};
    // Tên trường cũ (snake_case) từ Admin-web bản trước vẫn nhận
    let refundProof = body.refundProof || body.refund_proof;
    const refundedAmount = body.refundedAmount ?? body.refunded_amount;
    const refundReason = body.refundReason ?? body.refund_reason;
    const refundedAt = body.refundedAt ?? body.refunded_at;
    const bankReference = body.bankReference ?? body.bank_reference;
    if (!refundedAmount) {
      return ResponseHandler.badRequest(res, 'Số tiền hoàn trả là bắt buộc');
    }
    // Hoàn tiền là thao tác chuyển tiền ra: bắt buộc PIN quản trị ngay trong lời gọi này (không tin bước xác thực riêng ở giao diện)
    try {
      const adminService = require('../admin/admin.service');
      await adminService.verifySecurityAction({ pin: body.pin, action: 'REFUND_ORDER', targetId: id }, req.user);
    } catch (pinErr) {
      return ResponseHandler.error(res, pinErr.message, pinErr.statusCode || 400);
    }

    if (req.file) {
      const storage = require('../../core/storage');
      const type = storage.detectFileType(req.file.buffer);
      if (!type) {
        return ResponseHandler.badRequest(res, 'Minh chứng phải là ảnh JPG, PNG, WEBP hoặc tệp PDF');
      }
      const { randomUUID } = require('crypto');
      const folder = String(id).replace(/[^A-Za-z0-9-]/g, '').slice(0, 64) || 'don';
      refundProof = await storage.getStorage().put({
        bucket: storage.BUCKETS.REFUND_PROOFS,
        key: `${folder}/${randomUUID()}.${type.ext}`,
        buffer: req.file.buffer,
        contentType: type.mime,
      });
    }

    const result = await paymentService.processOrderRefund(id, {
      refundedAmount,
      refundProof,
      refundReason,
      refundedAt,
      bankReference,
    }, req.user);
    return ResponseHandler.success(res, result, 'Cập nhật hoàn tiền thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy danh mục các gói cước từ CSDL
 */
async function getPackageTypes(req, res, next) {
  try {
    const packages = await paymentService.getPackageTypes();
    return ResponseHandler.success(res, packages, 'Lấy danh mục gói cước thành công');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  createOrder,
  handleWebhook,
  confirmUpgrade,
  confirmUpgradeByAdmin,
  processRefund,
  getOrderStatus,
  getSubscriptionInfo,
  getOrderHistory,
  getOrdersForAdmin,
  getPaymentStatsForAdmin,
  getOrderDetailForAdmin,
  getPackageTypes,
  createSampleOrder,
  deleteSampleOrders,
  getSampleQuota,
};


