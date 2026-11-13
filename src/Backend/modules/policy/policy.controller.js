const policyService = require('./policy.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const fail = (res, error) => {
  if (!error.statusCode || error.statusCode >= 500) logger.error('policy controller failed', { error: error.message });
  return ResponseHandler.error(res, error.message, error.statusCode || 500, null, error.code || null);
};

const policyController = {
  async current(req, res) {
    try {
      const status = await policyService.getStatus(req.user.idaccount);
      return ResponseHandler.success(res, status, 'Chính sách bảo mật hiện hành');
    } catch (error) {
      return fail(res, error);
    }
  },

  async accept(req, res) {
    try {
      const { created } = await policyService.accept(req.user.idaccount, req.body?.version, req);
      req.auditActionName = `Đồng ý chính sách bảo mật v${req.body?.version}`;
      const status = await policyService.getStatus(req.user.idaccount);
      return ResponseHandler.success(res, status, created ? 'Đã ghi nhận đồng ý chính sách' : 'Đã đồng ý phiên bản này trước đó', created ? 201 : 200);
    } catch (error) {
      return fail(res, error);
    }
  },
};

module.exports = policyController;
