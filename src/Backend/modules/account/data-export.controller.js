const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');
const service = require('./data-export.service');

const fail = (res, error) => {
  const status = error.statusCode || 500;
  if (status >= 500) logger.error('[DataExport] Lỗi', { error: error.message });
  return res.status(status).json({ success: false, code: error.code || 'DATA_EXPORT_ERROR', message: error.message });
};

const dataExportController = {
  async request(req, res) {
    try {
      const idaccount = req.user.idaccount;
      req.auditActionName = 'Yêu cầu bản sao dữ liệu cá nhân';
      const { request, email } = await service.requestExport(idaccount);
      setImmediate(() => {
        service.processRequest(request.id).catch((err) => logger.error('[DataExport] processRequest', { error: err.message }));
      });
      return res.status(202).json({
        success: true,
        message: 'Đang tạo bản sao dữ liệu. Bạn sẽ nhận email khi tệp sẵn sàng.',
        data: { id: request.id, status: request.status, requestedAt: request.requested_at, email },
      });
    } catch (error) {
      if (error.statusCode === 429) res.set('Retry-After', String(error.retryAfterSec));
      return fail(res, error);
    }
  },

  async latest(req, res) {
    try {
      const data = await service.getLatest(req.user.idaccount);
      return ResponseHandler.success(res, data, 'Trạng thái bản sao dữ liệu');
    } catch (error) {
      return fail(res, error);
    }
  },

  async download(req, res) {
    try {
      req.auditActionName = 'Tải bản sao dữ liệu cá nhân';
      const file = await service.getFile(req.user.idaccount, req.params.id, req.query?.format);
      res.set({
        'Content-Type': file.contentType,
        'Content-Disposition': `attachment; filename="${file.filename}"`,
        'Cache-Control': 'no-store',
      });
      return res.status(200).send(file.buffer);
    } catch (error) {
      return fail(res, error);
    }
  },
};

module.exports = dataExportController;
