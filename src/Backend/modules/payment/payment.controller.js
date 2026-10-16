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
    const { page, limit, search, status, packageType, fromDate, toDate, excludeTemplate } = req.query;
    const result = await paymentService.getOrdersForAdmin({
      page,
      limit,
      search,
      status,
      packageType,
      fromDate,
      toDate,
      excludeTemplate,
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
 * Tạo đơn hàng mẫu thử nghiệm (kèm hoặc không kèm đối soát Webhook)
 */
async function createSampleOrder(req, res, next) {
  try {
    const { packageType, amount, status, simulateWebhook, idaccount } = req.body || {};
    const order = await paymentService.createSampleOrder({
      packageType,
      amount,
      status,
      simulateWebhook,
      idaccount,
    });
    return ResponseHandler.success(res, order, 'Tạo đơn hàng mẫu thử nghiệm thành công', 201);
  } catch (error) {
    return next(error);
  }
}

/**
 * Xóa các đơn hàng mẫu thử nghiệm
 */
async function deleteSampleOrders(req, res, next) {
  try {
    const result = await paymentService.deleteSampleOrders();
    return ResponseHandler.success(res, result, 'Xóa các đơn hàng mẫu thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Lấy hoặc sinh mã QR từ kênh PayOS
 */
async function getPayosQr(req, res, next) {
  try {
    const { amount, packageType, persistOrder } = req.query;
    const qrData = await paymentService.getOrCreatePayosQr({
      amount,
      packageType,
      persistOrder: persistOrder === 'true', // Mặc định FALSE: Không tự ý sinh pending order rác khi mở modal
      idaccount: req.user?.idaccount,
    });
    return ResponseHandler.success(res, qrData, 'Lấy mã QR PayOS thành công');
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
 * Admin xử lý hoàn tiền cho khách hàng kèm upload minh chứng
 */
async function processRefund(req, res, next) {
  try {
    const { id } = req.params;
    let { refundedAmount, refundProof, refundReason, refundedAt } = req.body;
    if (!refundedAmount) {
      return ResponseHandler.badRequest(res, 'Số tiền hoàn trả là bắt buộc');
    }

    // Nếu có file upload từ multer, lưu đường dẫn tương đối phục vụ static
    if (req.file) {
      refundProof = `/assets/Refunds/${req.file.filename}`;
    }

    const result = await paymentService.processOrderRefund(id, {
      refundedAmount,
      refundProof,
      refundReason,
      refundedAt,
    });
    return ResponseHandler.success(res, result, 'Cập nhật hoàn tiền thành công');
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin giả lập Webhook cho chế độ Sandbox Roleplay
 */
async function simulateWebhook(req, res, next) {
  try {
    const { orderCode, simulateType } = req.body;
    if (!orderCode) {
      return ResponseHandler.badRequest(res, 'Mã đơn hàng orderCode là bắt buộc');
    }
    const result = await paymentService.simulateWebhook({ orderCode, simulateType });
    return ResponseHandler.success(res, result, 'Giả lập giao dịch Webhook thành công');
  } catch (error) {
    if (error.statusCode === 404) return ResponseHandler.notFound(res, error.message);
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
  processRefund,
  simulateWebhook,
  getOrderStatus,
  getSubscriptionInfo,
  getOrderHistory,
  getOrdersForAdmin,
  getPaymentStatsForAdmin,
  getOrderDetailForAdmin,
  getPackageTypes,
  createSampleOrder,
  deleteSampleOrders,
  getPayosQr,
};


